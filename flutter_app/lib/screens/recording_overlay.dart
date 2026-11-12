import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../recorder.dart';
import '../theme.dart';

/// 錄影中畫面：預設全黑＋最低亮度；點一下拍照、點兩下結束、左右滑動切換鏡頭畫面
class RecordingOverlay extends StatefulWidget {
  const RecordingOverlay({super.key});

  @override
  State<RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<RecordingOverlay> {
  bool _showPreview = false;
  bool _showGuide = true;
  String? _toast;
  Timer? _guideTimer;
  Timer? _toastTimer;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _guideTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _showGuide = false);
      if (!_showPreview) Recorder.instance.dimScreen();
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _showPreview) setState(() {});
    });
  }

  @override
  void dispose() {
    _guideTimer?.cancel();
    _toastTimer?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  void _flash(String text) {
    setState(() => _toast = text);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _togglePreview() async {
    setState(() => _showPreview = !_showPreview);
    if (_showPreview) {
      await Recorder.instance.restoreBrightness();
    } else if (!_showGuide) {
      await Recorder.instance.dimScreen();
    }
  }

  String _elapsed() {
    final start = Recorder.instance.segmentStartedAt;
    if (start == null) return '00:00';
    final d = DateTime.now().difference(start);
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}' : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = Recorder.instance.controller;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final ok = await Recorder.instance.takePhoto();
            if (mounted) _flash(ok ? '已拍照' : '拍照失敗');
          },
          onDoubleTap: () => Recorder.instance.stop(),
          onHorizontalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0).abs() > 200) _togglePreview();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_showPreview && controller != null && controller.value.isInitialized)
                Center(child: CameraPreview(controller)),
              if (_showPreview)
                Positioned(
                  top: 48,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(color: AppColors.recordRed, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(_elapsed(), style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ]),
                    ),
                  ),
                ),
              if (_showGuide) const Center(child: _GestureGuide()),
              if (_toast != null)
                Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
                      child: Text(_toast!, style: const TextStyle(color: Colors.white70)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GestureGuide extends StatelessWidget {
  const _GestureGuide();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF292929),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: const IntrinsicWidth(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _GuideRow(icon: Icons.photo_camera, color: Color(0xFFF2BF40), title: '點一下', detail: '拍照（不中斷錄影）'),
          SizedBox(height: 14),
          _GuideRow(icon: Icons.stop, color: Color(0xFFE6524D), badge: '2', title: '點兩下', detail: '結束錄影'),
          SizedBox(height: 14),
          _GuideRow(icon: Icons.swap_horiz, color: Color(0xFF59A6F2), title: '左右滑動', detail: '切換黑屏／鏡頭畫面'),
        ]),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.icon, required this.color, required this.title, required this.detail, this.badge});
  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        if (badge != null)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(badge!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
            ),
          ),
      ]),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(detail, style: const TextStyle(fontSize: 13, color: Color(0xFFCCCCCC))),
      ]),
    ]);
  }
}
