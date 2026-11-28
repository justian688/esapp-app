import 'dart:convert';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'models.dart';

const _uploadTaskName = 'uploadCourseVideos';
const _uploadUniqueName = 'esapp-course-video-uploads';
const _autoUploadKey = 'upload.autoEnabled';
const _serverUrlKey = 'upload.serverUrl';
const _tokenKey = 'upload.serverToken';
const _uploadStateKey = 'uploadState';

@pragma('vm:entry-point')
void uploadCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    if (taskName != _uploadTaskName) return true;
    try {
      return await _uploadPendingVideos();
    } catch (_) {
      return false;
    }
  });
}

class VideoUploadService {
  VideoUploadService._();

  static const _secureStorage = FlutterSecureStorage();

  static Future<void> initialize() async {
    await Workmanager().initialize(uploadCallbackDispatcher);
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoUploadKey) ?? true;
  }

  static Future<String?> readToken() => _secureStorage.read(key: _tokenKey);

  static Future<void> saveConfig({required String serverUrl, String? token, required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedUrl = serverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    await prefs.setString(_serverUrlKey, normalizedUrl);
    await prefs.setBool(_autoUploadKey, enabled);
    if (token != null) {
      if (token.trim().isEmpty) {
        await _secureStorage.delete(key: _tokenKey);
      } else {
        await _secureStorage.write(key: _tokenKey, value: token.trim());
      }
    }
    if (!enabled || token?.trim().isEmpty == true) {
      await Workmanager().cancelByUniqueName(_uploadUniqueName);
    }
  }

  static Future<void> retryFailedVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('media');
    if (raw == null) return;
    final items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    var changed = false;
    for (final item in items) {
      if (item['kind'] == MediaKind.video.name && item[_uploadStateKey] == 'failed') {
        item[_uploadStateKey] = 'pending';
        item.remove('uploadError');
        changed = true;
      }
    }
    if (changed) await prefs.setString('media', jsonEncode(items));
  }

  static Future<String> readServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey) ?? '';
  }

  static Future<void> enqueue() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = (prefs.getString(_serverUrlKey) ?? '').trim();
    final token = await _secureStorage.read(key: _tokenKey);
    if (!(prefs.getBool(_autoUploadKey) ?? true) || serverUrl.isEmpty || (token ?? '').isEmpty) return;

    await Workmanager().registerOneOffTask(
      _uploadUniqueName,
      _uploadTaskName,
      constraints: Constraints(networkType: NetworkType.unmetered),
      existingWorkPolicy: ExistingWorkPolicy.update,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 2),
      foregroundServiceConfig: ForegroundServiceConfig(
        notificationTitle: 'es省電王正在上傳課程影片',
        notificationText: '只透過 Wi-Fi 等非計量網路上傳，影片仍保留在手機。',
        notificationChannelId: 'course_video_uploads',
        notificationChannelName: '課程影片上傳',
        foregroundServiceType: ForegroundServiceType.dataSync,
      ),
    );
  }
}

Future<bool> _uploadPendingVideos() async {
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool(_autoUploadKey) ?? true)) return true;

  final baseUrl = (prefs.getString(_serverUrlKey) ?? '').trim().replaceFirst(RegExp(r'/+$'), '');
  final token = await const FlutterSecureStorage().read(key: _tokenKey);
  if (baseUrl.isEmpty || (token ?? '').isEmpty) return true;

  final endpoint = Uri.tryParse('$baseUrl/api/v1/uploads');
  if (endpoint == null || endpoint.scheme != 'https' || endpoint.host.isEmpty) return true;

  final rawMedia = prefs.getString('media');
  final rawCourses = prefs.getString('courses');
  if (rawMedia == null) return true;

  final mediaList = (jsonDecode(rawMedia) as List).cast<Map<String, dynamic>>();
  final courses = rawCourses == null
      ? <Map<String, dynamic>>[]
      : (jsonDecode(rawCourses) as List).cast<Map<String, dynamic>>();
  final client = http.Client();
  var retry = false;

  try {
    for (final item in mediaList) {
      await prefs.reload();
      if (!(prefs.getBool(_autoUploadKey) ?? true)) return true;
      if (item['kind'] != MediaKind.video.name) continue;
      final status = item[_uploadStateKey] as String? ?? 'local';
      if (status != 'pending' && status != 'uploading') continue;

      final filePath = item['path'] as String? ?? '';
      final file = File(filePath);
      if (!await file.exists()) {
        await _writeUploadState(prefs, filePath, 'failed', '手機上的影片檔案不存在');
        continue;
      }

      final fileName = file.uri.pathSegments.isEmpty ? 'course.mp4' : file.uri.pathSegments.last;
      final courseId = item['courseId'] as String? ?? '';
      Map<String, dynamic>? course;
      for (final candidate in courses) {
        if (candidate['id'] == courseId) {
          course = candidate;
          break;
        }
      }
      await _writeUploadState(prefs, filePath, 'uploading');

      final request = http.MultipartRequest('POST', endpoint)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Idempotency-Key'] = fileName
        ..fields['media_id'] = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '')
        ..fields['course_id'] = courseId
        ..fields['course_name'] = course?['name']?.toString() ?? '未分類課程'
        ..fields['category'] = course?['category']?.toString() ?? ''
        ..fields['teacher'] = course?['teacher']?.toString() ?? ''
        ..fields['recorded_at'] = item['recordedAt']?.toString() ?? ''
        ..files.add(await http.MultipartFile.fromPath('file', file.path, filename: fileName));

      http.StreamedResponse response;
      try {
        response = await client.send(request).timeout(const Duration(hours: 4));
      } catch (_) {
        await _writeUploadState(prefs, filePath, 'pending', '連線中斷，稍後會在非計量網路下重試');
        retry = true;
        continue;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _writeUploadState(prefs, filePath, 'uploaded');
      } else if (response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 400 || response.statusCode == 413) {
        await _writeUploadState(prefs, filePath, 'failed', '伺服器拒絕上傳（HTTP ${response.statusCode}），請檢查設定');
        await response.stream.drain<void>();
      } else {
        await _writeUploadState(prefs, filePath, 'pending', '伺服器暫時無法接收（HTTP ${response.statusCode}），稍後重試');
        await response.stream.drain<void>();
        retry = true;
      }
    }
  } finally {
    client.close();
  }
  return !retry;
}

Future<void> _writeUploadState(SharedPreferences prefs, String path, String state, [String? error]) async {
  await prefs.reload();
  final raw = prefs.getString('media');
  if (raw == null) return;
  final items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  final index = items.indexWhere((item) => item['path'] == path);
  if (index < 0) return;
  items[index][_uploadStateKey] = state;
  if (error == null) {
    items[index].remove('uploadError');
  } else {
    items[index]['uploadError'] = error;
  }
  await prefs.setString('media', jsonEncode(items));
}
