import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// 點「目前課程」：選擇課程、編輯、新增
Future<void> showCoursePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.chalkboard,
    isScrollControlled: true,
    builder: (context) => ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) {
        final store = AppStore.instance;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('選擇課程', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final c in store.courses)
                    ListTile(
                      leading: Icon(
                        c.id == store.currentCourseId ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: AppColors.chalkYellowBright,
                      ),
                      title: Text(c.name),
                      subtitle: c.subtitle.isEmpty ? null : Text(c.subtitle),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => openCourseEditor(context, c),
                      ),
                      onTap: () {
                        store.selectCourse(c.id);
                        Navigator.pop(context);
                      },
                    ),
                ]),
              ),
              ListTile(
                leading: const Icon(Icons.add, color: AppColors.chalkYellowBright),
                title: const Text('新增課程', style: TextStyle(color: AppColors.chalkYellowBright)),
                onTap: () => openCourseEditor(context, null),
              ),
            ]),
          ),
        );
      },
    ),
  );
}

Future<void> openCourseEditor(BuildContext context, Course? course) {
  return Navigator.push(context, MaterialPageRoute(builder: (_) => CourseEditor(course: course)));
}

class CourseEditor extends StatefulWidget {
  const CourseEditor({super.key, this.course});
  final Course? course;

  @override
  State<CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends State<CourseEditor> {
  late final _name = TextEditingController(text: widget.course?.name ?? '');
  late final _teacher = TextEditingController(text: widget.course?.teacher ?? '');
  late final _schedule = TextEditingController(text: widget.course?.schedule ?? '');
  late final _room = TextEditingController(text: widget.course?.room ?? '');
  late String _category = widget.course?.category ?? defaultCategory;

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入課程名稱')));
      return;
    }
    final c = widget.course ?? Course(name: name);
    c
      ..name = name
      ..teacher = _teacher.text.trim()
      ..schedule = _schedule.text.trim()
      ..room = _room.text.trim()
      ..category = _category;
    AppStore.instance.saveCourse(c);
    if (widget.course == null) AppStore.instance.selectCourse(c.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    Widget field(String label, TextEditingController c, String hint) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextField(
            controller: c,
            decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course == null ? '新增課程' : '編輯課程'),
        actions: [TextButton(onPressed: _save, child: const Text('儲存'))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        field('課程名稱', _name, '微積分'),
        field('老師／講者', _teacher, '陳老師'),
        field('時間', _schedule, '週一 09:10'),
        field('地點', _room, 'B203'),
        DropdownButtonFormField<String>(
          value: store.categories.contains(_category) ? _category : defaultCategory,
          decoration: const InputDecoration(labelText: '分類', border: OutlineInputBorder()),
          items: [for (final c in store.categories) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _category = v ?? defaultCategory),
        ),
        if (widget.course != null && store.courses.length > 1) ...[
          const SizedBox(height: 32),
          TextButton(
            onPressed: () {
              store.deleteCourse(widget.course!.id);
              Navigator.pop(context);
            },
            child: const Text('刪除這個課程', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ]),
    );
  }
}
