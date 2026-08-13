import 'package:flutter/material.dart';

import '../bookmarks.dart';
import '../models.dart';
import '../tajweed.dart';

class AyatDetailScreen extends StatefulWidget {
  final List<RuqyahItem> items;
  final int index;
  final BookmarkStore bookmarks;

  const AyatDetailScreen({
    super.key,
    required this.items,
    required this.index,
    required this.bookmarks,
  });

  @override
  State<AyatDetailScreen> createState() => _AyatDetailScreenState();
}

class _AyatDetailScreenState extends State<AyatDetailScreen> {
  late int _index;
  late int _count;

  RuqyahItem get item => widget.items[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.index;
    _count = 0;
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.items.length - 1);
    if (next != _index) {
      setState(() {
        _index = next;
        _count = 0;
      });
    }
  }

  void _increment() {
    if (_count < item.repeat) setState(() => _count++);
  }

  @override
  Widget build(BuildContext context) {
    final done = _count >= item.repeat;
    final saved = widget.bookmarks.isBookmarked(item.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(item.reference),
        actions: [
          IconButton(
            tooltip: 'Tajweed colours',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => showTajweedLegend(context),
          ),
          IconButton(
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_outline),
            onPressed: () => widget.bookmarks.toggle(item.id),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Module 9's procedural steps carry no Arabic of their own.
                if (item.arabic.isNotEmpty)
                  arabicText(context, item.arabic),
                if (item.transliteration.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(item.transliteration,
                      style: const TextStyle(
                          fontStyle: FontStyle.italic, fontSize: 15)),
                ],
                if (item.translation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(item.translation, style: const TextStyle(fontSize: 15)),
                ],
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(item.note,
                                  style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.repeat > 1) ...[
                    LinearProgressIndicator(value: _count / item.repeat),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      IconButton(
                        onPressed: _index > 0 ? () => _go(-1) : null,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: item.repeat > 1 && !done
                              ? _increment
                              : (item.repeat > 1
                                  ? () => setState(() => _count = 0)
                                  : null),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              item.repeat <= 1
                                  ? 'Recite once'
                                  : done
                                      ? 'Done — tap to reset'
                                      : 'Recited  $_count / ${item.repeat}',
                              style: const TextStyle(fontSize: 17),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed:
                            _index < widget.items.length - 1 ? () => _go(1) : null,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
