import 'package:flutter/material.dart';

import '../recorder.dart';
import '../theme.dart';
import 'course_info.dart';
import 'library.dart';
import 'notes.dart';
import 'record_tab.dart';
import 'recording_overlay.dart';
import 'settings_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _tab = 0;
  final recorder = Recorder.instance;

  @override
  void initState() {
    super.initState();
    recorder.addListener(_onRecorder);
  }

  @override
  void dispose() {
    recorder.removeListener(_onRecorder);
    super.dispose();
  }

  void _onRecorder() {
    if (!mounted) return;
    setState(() {});
    final msg = recorder.errorMessage;
    if (msg != null) {
      recorder.errorMessage = null;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('錄影提醒'),
          content: Text(msg),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('好'))],
        ),
      );
    }
  }

  void _open(Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    if (recorder.isRecording) {
      return const RecordingOverlay();
    }
    return Scaffold(
      key: _scaffoldKey,
      drawer: _SideMenu(onOpen: _open),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              tab: _tab,
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onTab: (t) => setState(() => _tab = t),
            ),
            Expanded(child: _tab == 0 ? const RecordTab() : const NotesSection()),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.tab, required this.onMenu, required this.onTab});
  final int tab;
  final VoidCallback onMenu;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    Widget tabButton(int index, IconData icon) {
      final selected = tab == index;
      return Expanded(
        child: InkWell(
          onTap: () => onTab(index),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: selected ? AppColors.chalkYellow : Colors.transparent, width: 2),
              ),
            ),
            child: Icon(icon, size: 26, color: selected ? AppColors.chalkWhite : AppColors.muted),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
      child: Row(
        children: [
          IconButton(onPressed: onMenu, icon: const Icon(Icons.menu, color: AppColors.chalkWhite)),
          tabButton(0, Icons.videocam),
          tabButton(1, Icons.edit),
        ],
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.onOpen});
  final void Function(Widget page) onOpen;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    Widget row(IconData icon, String title, Widget page) => _MenuRow(icon: icon, title: title, onTap: () => onOpen(page));
    return Drawer(
      width: (width * 0.66).clamp(0, 300),
      backgroundColor: AppColors.chalkboard,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: const Color(0xFF0E8C8C),
                    child: const Icon(Icons.bolt, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('es省電王', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 16),
            row(Icons.photo_library_outlined, '課程相簿', const LibraryPage()),
            row(Icons.table_chart_outlined, '課程資訊表', const CourseInfoPage()),
            row(Icons.edit_note, '課程筆記', const NotesPage()),
            const Divider(indent: 20, endIndent: 20),
            row(Icons.settings_outlined, '設定', const SettingsPage()),
          ],
        ),
      ),
    );
  }
}

/// 選單項目：點下去文字變黃、左側亮黃條、輕微縮小
class _MenuRow extends StatefulWidget {
  const _MenuRow({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = _pressed ? AppColors.chalkYellowBright : AppColors.chalkWhite;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        alignment: Alignment.centerLeft,
        duration: const Duration(milliseconds: 150),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _pressed ? AppColors.chalkYellowBright.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Container(width: 4, height: 50, color: _pressed ? AppColors.chalkYellowBright : Colors.transparent),
            const SizedBox(width: 12),
            Icon(widget.icon, color: color),
            const SizedBox(width: 18),
            Text(widget.title, style: TextStyle(fontSize: 17, color: color)),
          ]),
        ),
      ),
    );
  }
}
