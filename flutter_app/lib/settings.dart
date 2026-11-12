import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VideoQuality { hd720, hd1080, uhd4k }

extension VideoQualityX on VideoQuality {
  String get title => switch (this) {
        VideoQuality.hd720 => '720p（最省電）',
        VideoQuality.hd1080 => '1080p（清晰）',
        VideoQuality.uhd4k => '4K（最清晰、較耗電佔空間）',
      };

  ResolutionPreset get preset => switch (this) {
        VideoQuality.hd720 => ResolutionPreset.high,
        VideoQuality.hd1080 => ResolutionPreset.veryHigh,
        VideoQuality.uhd4k => ResolutionPreset.ultraHigh,
      };
}

/// 錄影設定（預設：1080p、60 分鐘一段、前鏡頭、自動重複）
class RecordingSettings extends ChangeNotifier {
  RecordingSettings._();
  static final RecordingSettings instance = RecordingSettings._();

  static const durationOptions = [3, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 0];

  late SharedPreferences _prefs;
  VideoQuality quality = VideoQuality.hd1080;
  int segmentMinutes = 60;
  bool frontCamera = true;
  bool repeat = true;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    quality = VideoQuality.values[_prefs.getInt('quality') ?? VideoQuality.hd1080.index];
    segmentMinutes = _prefs.getInt('segmentMinutes') ?? 60;
    frontCamera = _prefs.getBool('frontCamera') ?? true;
    repeat = _prefs.getBool('repeat') ?? true;
  }

  void update({VideoQuality? quality, int? segmentMinutes, bool? frontCamera, bool? repeat}) {
    if (quality != null) this.quality = quality;
    if (segmentMinutes != null) this.segmentMinutes = segmentMinutes;
    if (frontCamera != null) this.frontCamera = frontCamera;
    if (repeat != null) this.repeat = repeat;
    _prefs.setInt('quality', this.quality.index);
    _prefs.setInt('segmentMinutes', this.segmentMinutes);
    _prefs.setBool('frontCamera', this.frontCamera);
    _prefs.setBool('repeat', this.repeat);
    notifyListeners();
  }

  static String durationLabel(int minutes) {
    if (minutes == 0) return '不限時長';
    if (minutes < 60) return '$minutes 分鐘';
    if (minutes % 60 == 0) return '${minutes ~/ 60} 小時';
    return '${minutes ~/ 60} 小時 ${minutes % 60} 分鐘';
  }
}
