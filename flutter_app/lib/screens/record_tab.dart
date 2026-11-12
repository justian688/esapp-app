import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../recorder.dart';
import '../theme.dart';
import 'course_picker.dart';

/// 首頁：日期、目前課程、計時圈、「開始上課」按鈕
class RecordTab extends StatelessWidget {
  const RecordTab({super.key});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('M月d日 EEEE', 'zh_TW').format(DateTime.now());
    return ListenableBuilder(
      listenable: Listenable.merge([AppStore.instance, Recorder.instance]),
      builder: (context, _) {
        final recorder = Recorder.instance;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(date, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ),
              const SizedBox(height: 10),
              const CurrentCourseCard(),
              const Spacer(),
              const _ChalkRing(),
              const Spacer(),
              _StartButton(
                busy: recorder.isStarting,
                onTap: recorder.start,
              ),
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }
}

class CurrentCourseCard extends StatelessWidget {
  const CurrentCourseCard({super.key});

  @override
  Widget build(BuildContext context) {
    final course = AppStore.instance.currentCourse;
    final text = course.subtitle.isEmpty ? course.name : '${course.name}・${course.subtitle}';
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showCoursePicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            const SizedBox(width: 24),
            Expanded(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.school, size: 18, color: AppColors.chalkYellow),
                const SizedBox(width: 6),
                const Text('目前課程', style: TextStyle(color: AppColors.chalkYellow, fontSize: 13)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(text,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ]),
            ),
            const Icon(Icons.edit_square, size: 20, color: AppColors.chalkWhite),
          ]),
        ),
      ),
    );
  }
}

class _ChalkRing extends StatelessWidget {
  const _ChalkRing();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 230,
      child: CustomPaint(
        painter: _DashedRingPainter(),
        child: const Center(
          child: Text('00:00', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w300, color: Colors.white)),
        ),
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = Paint()
      ..color = const Color(0xFF151A17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawCircle(center, size.width / 2 - 7, outer);
    final dash = Paint()
      ..color = AppColors.chalkYellow.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = size.width / 2 - 22;
    const count = 60;
    for (var i = 0; i < count; i++) {
      final start = 2 * math.pi * i / count;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start, math.pi / count, false, dash);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 粉筆框線風格的「開始上課」按鈕
class _StartButton extends StatelessWidget {
  const _StartButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 48),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(48),
          border: Border.all(color: AppColors.chalkYellow.withValues(alpha: 0.8), width: 2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(color: AppColors.recordRed, shape: BoxShape.circle),
                ),
          const SizedBox(width: 16),
          const Text('開始上課',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: 4, color: Color(0xFFD9CFB5))),
        ]),
      ),
    );
  }
}
