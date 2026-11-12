import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../theme.dart';

/// 課程相簿：像 Google 相簿一樣，依日期列出所有影片和照片
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String? _category; // null = 全部

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('建立分類'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: '例如：學校課程')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('建立')),
        ],
      ),
    );
    if (name != null) AppStore.instance.addCategory(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('課程相簿'),
        actions: [IconButton(icon: const Icon(Icons.create_new_folder_outlined), onPressed: _createCategory)],
      ),
      body: ListenableBuilder(
        listenable: AppStore.instance,
        builder: (context, _) {
          final store = AppStore.instance;
          var items = store.media;
          if (_category != null) {
            items = items.where((m) => store.courseById(m.courseId)?.category == _category).toList();
          }
          final groups = <String, List<MediaItem>>{};
          for (final m in items) {
            groups.putIfAbsent(_dayLabel(m.recordedAt), () => []).add(m);
          }
          return CustomScrollView(slivers: [
            if (store.customCategories.isNotEmpty)
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(children: [
                    _chip('全部', null),
                    for (final c in store.categories) _chip(c, c),
                  ]),
                ),
              ),
            if (items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: Text('還沒有影片，按「開始上課」錄第一堂課吧。', style: TextStyle(color: AppColors.muted))),
              ),
            for (final entry in groups.entries) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              SliverGrid.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
                itemCount: entry.value.length,
                itemBuilder: (context, i) => _Tile(item: entry.value[i]),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ]);
        },
      ),
    );
  }

  Widget _chip(String label, String? value) {
    final selected = _category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.chalkYellow,
        onSelected: (_) => setState(() => _category = value),
      ),
    );
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return '今天';
    if (day == today.subtract(const Duration(days: 1))) return '昨天';
    return DateFormat('M月d日 EEEE', 'zh_TW').format(d);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});
  final MediaItem item;

  Future<void> _menu(BuildContext context) async {
    final store = AppStore.instance;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.chalkboard,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(12), child: Text('歸到課程')),
          for (final c in store.courses)
            ListTile(
              leading: Icon(item.courseId == c.id ? Icons.check : Icons.school_outlined),
              title: Text(c.name),
              onTap: () => Navigator.pop(context, 'course:${c.id}'),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('刪除', style: TextStyle(color: Colors.redAccent)),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ]),
      ),
    );
    if (action == null) return;
    if (action == 'delete') {
      store.deleteMedia(item);
    } else if (action.startsWith('course:')) {
      store.moveMedia(item, action.substring(7));
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = AppStore.instance.courseById(item.courseId);
    final thumb = item.thumbPath;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaViewer(item: item))),
      onLongPress: () => _menu(context),
      child: Stack(fit: StackFit.expand, children: [
        Container(
          color: AppColors.card,
          child: thumb != null && File(thumb).existsSync()
              ? Image.file(File(thumb), fit: BoxFit.cover, cacheWidth: 360)
              : const Icon(Icons.movie_outlined, color: AppColors.muted),
        ),
        if (item.kind == MediaKind.video)
          const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30)),
        if (course != null)
          Positioned(
            left: 4,
            bottom: 4,
            right: 4,
            child: Text(course.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.white, shadows: [Shadow(blurRadius: 3)])),
          ),
      ]),
    );
  }
}

class MediaViewer extends StatefulWidget {
  const MediaViewer({super.key, required this.item});
  final MediaItem item;

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    if (widget.item.kind == MediaKind.video) {
      _video = VideoPlayerController.file(File(widget.item.path))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _video!.play();
          }
        });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: widget.item.kind == MediaKind.photo
            ? InteractiveViewer(child: Image.file(File(widget.item.path)))
            : v != null && v.value.isInitialized
                ? GestureDetector(
                    onTap: () => setState(() => v.value.isPlaying ? v.pause() : v.play()),
                    child: AspectRatio(
                      aspectRatio: v.value.aspectRatio,
                      child: Stack(alignment: Alignment.bottomCenter, children: [
                        VideoPlayer(v),
                        VideoProgressIndicator(v, allowScrubbing: true),
                      ]),
                    ),
                  )
                : const CircularProgressIndicator(),
      ),
    );
  }
}
