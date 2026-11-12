import 'package:flutter/material.dart';

import '../settings.dart';
import '../theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = RecordingSettings.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(children: [
          _section('錄影'),
          ListTile(
            title: const Text('錄影畫質'),
            subtitle: Text(s.quality.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pick<VideoQuality>(context, '錄影畫質', VideoQuality.values, (q) => q.title, s.quality,
                (v) => s.update(quality: v), note: '畫質越高越清楚，但越耗電、檔案越大。'),
          ),
          ListTile(
            title: const Text('每段錄影時長'),
            subtitle: Text(RecordingSettings.durationLabel(s.segmentMinutes)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pick<int>(context, '每段錄影時長', RecordingSettings.durationOptions,
                RecordingSettings.durationLabel, s.segmentMinutes, (v) => s.update(segmentMinutes: v)),
          ),
          SwitchListTile(
            title: const Text('時間到自動接續錄下一段'),
            value: s.repeat,
            activeColor: AppColors.chalkYellowBright,
            onChanged: (v) => s.update(repeat: v),
          ),
          ListTile(
            title: const Text('相機鏡頭'),
            subtitle: Text(s.frontCamera ? '前鏡頭' : '後鏡頭'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pick<bool>(context, '相機鏡頭', const [true, false], (f) => f ? '前鏡頭' : '後鏡頭',
                s.frontCamera, (v) => s.update(frontCamera: v)),
          ),
          _section('關於'),
          const ListTile(title: Text('es省電王'), subtitle: Text('Android 版 2.0.0')),
        ]),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(title, style: const TextStyle(color: AppColors.chalkYellow, fontSize: 13)),
      );

  Future<void> _pick<T>(BuildContext context, String title, List<T> options, String Function(T) label, T current,
      void Function(T) onPicked,
      {String? note}) async {
    final v = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.chalkboard,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(shrinkWrap: true, children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(note, style: const TextStyle(color: AppColors.muted)),
              ),
            for (final o in options)
              ListTile(
                title: Text(label(o)),
                trailing: o == current ? const Icon(Icons.check, color: AppColors.chalkYellowBright) : null,
                onTap: () => Navigator.pop(context, o),
              ),
          ]),
        ),
      ),
    );
    if (v != null) onPicked(v);
  }
}
