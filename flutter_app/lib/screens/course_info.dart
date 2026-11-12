import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'course_picker.dart';

/// 課程資訊表：名稱／分類／老師講者／時間／地點／錄影數
class CourseInfoPage extends StatelessWidget {
  const CourseInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('課程資訊表'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => openCourseEditor(context, null))],
      ),
      body: ListenableBuilder(
        listenable: AppStore.instance,
        builder: (context, _) {
          final store = AppStore.instance;
          const header = TextStyle(color: AppColors.chalkYellow, fontSize: 12, fontWeight: FontWeight.w600);
          return ListView(padding: const EdgeInsets.all(12), children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.card),
                columnSpacing: 22,
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('名稱', style: header)),
                  DataColumn(label: Text('分類', style: header)),
                  DataColumn(label: Text('老師／講者', style: header)),
                  DataColumn(label: Text('時間', style: header)),
                  DataColumn(label: Text('地點', style: header)),
                  DataColumn(label: Text('錄影', style: header), numeric: true),
                ],
                rows: [
                  for (final c in store.courses)
                    DataRow(
                      onSelectChanged: (_) => openCourseEditor(context, c),
                      cells: [
                        DataCell(Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(c.category)),
                        DataCell(Text(c.teacher.isEmpty ? '—' : c.teacher)),
                        DataCell(Text(c.schedule.isEmpty ? '—' : c.schedule)),
                        DataCell(Text(c.room.isEmpty ? '—' : c.room)),
                        DataCell(Text('${store.mediaCount(c.id)} 段')),
                      ],
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('點一列可以編輯。分類可在「課程相簿」右上角建立。',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
          ]);
        },
      ),
    );
  }
}
