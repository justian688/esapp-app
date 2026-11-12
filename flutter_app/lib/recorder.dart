import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'models.dart';
import 'settings.dart';

/// 錄影控制：只在「開始上課」時打開相機，結束就關掉（省電、相機燈不會一直亮）
class Recorder extends ChangeNotifier {
  Recorder._();
  static final Recorder instance = Recorder._();

  CameraController? controller;
  bool isRecording = false;
  bool isStarting = false;
  DateTime? segmentStartedAt;
  String? errorMessage;
  Timer? _segmentTimer;
  bool _userStopped = false;

  Future<void> start() async {
    if (isRecording || isStarting) return;
    isStarting = true;
    errorMessage = null;
    _userStopped = false;
    notifyListeners();
    try {
      await _openCamera();
      await _beginSegment();
      WakelockPlus.enable();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } on CameraException catch (e) {
      errorMessage = e.code == 'CameraAccessDenied' || e.code == 'AudioAccessDenied'
          ? '需要相機和麥克風權限才能錄影，請到手機「設定 > 應用程式 > es省電王 > 權限」打開。'
          : '無法開始錄影：${e.description ?? e.code}';
      await _closeCamera();
    } catch (e) {
      errorMessage = '無法開始錄影：$e';
      await _closeCamera();
    } finally {
      isStarting = false;
      notifyListeners();
    }
  }

  Future<void> _openCamera() async {
    if (controller != null) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('找不到相機');
    final wantFront = RecordingSettings.instance.frontCamera;
    final desc = cameras.firstWhere(
      (c) => c.lensDirection == (wantFront ? CameraLensDirection.front : CameraLensDirection.back),
      orElse: () => cameras.first,
    );
    final c = CameraController(desc, RecordingSettings.instance.quality.preset, enableAudio: true);
    await c.initialize();
    controller = c;
  }

  Future<void> _beginSegment() async {
    final c = controller;
    if (c == null) return;
    await c.startVideoRecording();
    isRecording = true;
    segmentStartedAt = DateTime.now();
    _segmentTimer?.cancel();
    final minutes = RecordingSettings.instance.segmentMinutes;
    if (minutes > 0) {
      _segmentTimer = Timer(Duration(minutes: minutes), _onSegmentLimit);
    }
    notifyListeners();
  }

  Future<void> _onSegmentLimit() async {
    if (!isRecording) return;
    await _finishSegment();
    if (RecordingSettings.instance.repeat && !_userStopped) {
      try {
        await _beginSegment();
        return;
      } catch (e) {
        errorMessage = '自動接續錄影失敗：$e';
      }
    }
    await _stopAll();
  }

  /// 使用者按結束（點兩下）
  Future<void> stop() async {
    if (!isRecording) return;
    _userStopped = true;
    _segmentTimer?.cancel();
    await _finishSegment();
    await _stopAll();
  }

  Future<void> _finishSegment() async {
    final c = controller;
    if (c == null || !c.value.isRecordingVideo) return;
    final startedAt = segmentStartedAt ?? DateTime.now();
    try {
      final file = await c.stopVideoRecording();
      await _store(file, MediaKind.video, startedAt);
    } catch (e) {
      errorMessage = '影片儲存失敗：$e';
    }
  }

  Future<void> _stopAll() async {
    isRecording = false;
    segmentStartedAt = null;
    _segmentTimer?.cancel();
    await _closeCamera();
    WakelockPlus.disable();
    await restoreBrightness();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    notifyListeners();
  }

  Future<void> _closeCamera() async {
    final c = controller;
    controller = null;
    notifyListeners();
    await c?.dispose();
  }

  /// 點一下：錄影中拍照（不中斷錄影）
  Future<bool> takePhoto() async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return false;
    try {
      final file = await c.takePicture();
      await _store(file, MediaKind.photo, DateTime.now());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _store(XFile file, MediaKind kind, DateTime at) async {
    final store = AppStore.instance;
    final stamp = at.millisecondsSinceEpoch;
    final ext = kind == MediaKind.video ? 'mp4' : 'jpg';
    final dest = '${store.mediaDir.path}/${kind.name}_$stamp.$ext';
    await File(file.path).copy(dest);
    try {
      await File(file.path).delete();
    } catch (_) {}
    String? thumb;
    if (kind == MediaKind.video) {
      final t = '${store.mediaDir.path}/thumb_$stamp.jpg';
      try {
        final ok = await FcNativeVideoThumbnail().getVideoThumbnail(
          srcFile: dest,
          destFile: t,
          width: 480,
          height: 480,
          format: 'jpeg',
          quality: 80,
        );
        if (ok) thumb = t;
      } catch (_) {}
    } else {
      thumb = dest;
    }
    store.addMedia(MediaItem(
      path: dest,
      kind: kind,
      recordedAt: at,
      courseId: store.currentCourseId,
      thumbPath: thumb,
    ));
  }

  Future<void> dimScreen() async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(0.0);
    } catch (_) {}
  }

  Future<void> restoreBrightness() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
  }
}
