import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../theme.dart';

/// 鉛筆分頁、側邊選單共用的課程筆記清單
class NotesSection extends StatelessWidget {
  const NotesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) {
        final store = AppStore.instance;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            const Icon(Icons.edit_note, color: AppColors.chalkYellow),
            const SizedBox(width: 6),
            const Text('課程筆記', style: TextStyle(color: AppColors.chalkYellow, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => openNoteEditor(context, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增筆記'),
            ),
          ]),
          if (store.notes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('還沒有筆記，按「新增筆記」寫下上課重點。', style: TextStyle(color: AppColors.muted))),
            ),
          for (final n in store.notes)
            Card(
              color: AppColors.card,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.edit, color: AppColors.chalkYellow),
                title: Text(n.title.isEmpty ? '（無標題）' : n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (n.body.isNotEmpty) Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(
                    [
                      store.courseById(n.courseId)?.name,
                      DateFormat('yyyy/M/d HH:mm').format(n.updatedAt),
                    ].whereType<String>().join('・'),
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ]),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openNoteEditor(context, n),
              ),
            ),
        ]);
      },
    );
  }
}

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('課程筆記')), body: const NotesSection());
  }
}

Future<void> openNoteEditor(BuildContext context, CourseNote? note) {
  return Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditor(note: note)));
}

class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, this.note});
  final CourseNote? note;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _body = TextEditingController(text: widget.note?.body ?? '');
  late String? _courseId = widget.note?.courseId ?? AppStore.instance.currentCourseId;

  void _save() {
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    final n = widget.note ?? CourseNote(title: '', body: '');
    n
      ..title = _title.text.trim()
      ..body = _body.text.trim()
      ..courseId = _courseId;
    AppStore.instance.saveNote(n);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? '新增筆記' : '編輯筆記'),
        actions: [
          if (widget.note != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                store.deleteNote(widget.note!.id);
                Navigator.pop(context);
              },
            ),
          TextButton(onPressed: _save, child: const Text('儲存')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String?>(
          value: store.courseById(_courseId)?.id,
          decoration: const InputDecoration(labelText: '課程', border: OutlineInputBorder()),
          items: [for (final c in store.courses) DropdownMenuItem(value: c.id, child: Text(c.name))],
          onChanged: (v) => setState(() => _courseId = v),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: '標題', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _body,
          minLines: 8,
          maxLines: null,
          decoration: const InputDecoration(labelText: '內容', alignLabelWithHint: true, border: OutlineInputBorder()),
        ),
      ]),
    );
  }
}
