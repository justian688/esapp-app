import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const defaultCategory = '一般分類';
const defaultCourseName = '一般課程';

class Course {
  Course({
    String? id,
    required this.name,
    this.schedule = '',
    this.room = '',
    this.teacher = '',
    this.category = defaultCategory,
  }) : id = id ?? _uuid.v4();

  final String id;
  String name;
  String schedule;
  String room;
  String teacher;
  String category;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'schedule': schedule,
        'room': room,
        'teacher': teacher,
        'category': category,
      };

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String?,
        name: j['name'] as String? ?? defaultCourseName,
        schedule: j['schedule'] as String? ?? '',
        room: j['room'] as String? ?? '',
        teacher: j['teacher'] as String? ?? '',
        category: j['category'] as String? ?? defaultCategory,
      );

  String get subtitle {
    final parts = [schedule, room].where((e) => e.isNotEmpty).toList();
    return parts.join('・');
  }
}

class CourseNote {
  CourseNote({String? id, required this.title, required this.body, this.courseId, DateTime? updatedAt})
      : id = id ?? _uuid.v4(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String body;
  String? courseId;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'courseId': courseId,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CourseNote.fromJson(Map<String, dynamic> j) => CourseNote(
        id: j['id'] as String?,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        courseId: j['courseId'] as String?,
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
      );
}

enum MediaKind { video, photo }

class MediaItem {
  MediaItem({required this.path, required this.kind, required this.recordedAt, this.courseId, this.thumbPath});

  final String path;
  final MediaKind kind;
  final DateTime recordedAt;
  String? courseId;
  String? thumbPath;

  String get fileName => path.split('/').last;

  Map<String, dynamic> toJson() => {
        'path': path,
        'kind': kind.name,
        'recordedAt': recordedAt.toIso8601String(),
        'courseId': courseId,
        'thumbPath': thumbPath,
      };

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        path: j['path'] as String,
        kind: j['kind'] == 'photo' ? MediaKind.photo : MediaKind.video,
        recordedAt: DateTime.tryParse(j['recordedAt'] as String? ?? '') ?? DateTime.now(),
        courseId: j['courseId'] as String?,
        thumbPath: j['thumbPath'] as String?,
      );
}

/// 課程、筆記、影片照片的資料中心（存在手機本機）
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  late SharedPreferences _prefs;
  late Directory mediaDir;

  final List<Course> courses = [];
  final List<String> customCategories = [];
  final List<CourseNote> notes = [];
  final List<MediaItem> media = [];
  String? currentCourseId;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final docs = await getApplicationDocumentsDirectory();
    mediaDir = Directory('${docs.path}/media');
    await mediaDir.create(recursive: true);

    courses
      ..clear()
      ..addAll(_readList('courses').map(Course.fromJson));
    customCategories
      ..clear()
      ..addAll(_prefs.getStringList('categories') ?? []);
    notes
      ..clear()
      ..addAll(_readList('notes').map(CourseNote.fromJson));
    media
      ..clear()
      ..addAll(_readList('media').map(MediaItem.fromJson).where((m) => File(m.path).existsSync()));
    currentCourseId = _prefs.getString('currentCourseId');
    _ensureDefaultCourse();
    notifyListeners();
  }

  List<Map<String, dynamic>> _readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  void _save() {
    _prefs.setString('courses', jsonEncode(courses.map((c) => c.toJson()).toList()));
    _prefs.setStringList('categories', customCategories);
    _prefs.setString('notes', jsonEncode(notes.map((n) => n.toJson()).toList()));
    _prefs.setString('media', jsonEncode(media.map((m) => m.toJson()).toList()));
    if (currentCourseId != null) _prefs.setString('currentCourseId', currentCourseId!);
    notifyListeners();
  }

  void _ensureDefaultCourse() {
    if (courses.isEmpty) {
      courses.add(Course(name: defaultCourseName));
    }
    if (currentCourseId == null || courseById(currentCourseId) == null) {
      currentCourseId = courses.first.id;
    }
    _save();
  }

  Course? courseById(String? id) {
    if (id == null) return null;
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  Course get currentCourse => courseById(currentCourseId) ?? courses.first;

  List<String> get categories => [defaultCategory, ...customCategories];

  void selectCourse(String id) {
    currentCourseId = id;
    _save();
  }

  void saveCourse(Course course) {
    final i = courses.indexWhere((c) => c.id == course.id);
    if (i >= 0) {
      courses[i] = course;
    } else {
      courses.add(course);
    }
    _save();
  }

  void deleteCourse(String id) {
    courses.removeWhere((c) => c.id == id);
    for (final m in media) {
      if (m.courseId == id) m.courseId = null;
    }
    if (currentCourseId == id) currentCourseId = null;
    _ensureDefaultCourse();
  }

  void addCategory(String name) {
    final n = name.trim();
    if (n.isEmpty || categories.contains(n)) return;
    customCategories.add(n);
    _save();
  }

  void saveNote(CourseNote note) {
    note.updatedAt = DateTime.now();
    final i = notes.indexWhere((n) => n.id == note.id);
    if (i >= 0) {
      notes[i] = note;
    } else {
      notes.insert(0, note);
    }
    _save();
  }

  void deleteNote(String id) {
    notes.removeWhere((n) => n.id == id);
    _save();
  }

  void addMedia(MediaItem item) {
    media.insert(0, item);
    _save();
  }

  void moveMedia(MediaItem item, String? courseId) {
    item.courseId = courseId;
    _save();
  }

  void deleteMedia(MediaItem item) {
    media.remove(item);
    try {
      File(item.path).deleteSync();
      if (item.thumbPath != null) File(item.thumbPath!).deleteSync();
    } catch (_) {}
    _save();
  }

  int mediaCount(String courseId) => media.where((m) => m.courseId == courseId).length;
}
