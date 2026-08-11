import 'package:flutter/material.dart';

import '../bookmarks.dart';
import '../models.dart';

class BookmarksScreen extends StatelessWidget {
  final List<Category> categories;
  final BookmarkStore bookmarks;

  const BookmarksScreen({
    super.key,
    required this.categories,
    required this.bookmarks,
  });

  @override
  Widget build(BuildContext context) {
    final saved = <RuqyahItem>[];
    for (final c in categories) {
      saved.addAll(c.items.where((i) => bookmarks.isBookmarked(i.id)));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: saved.isEmpty
          ? const Center(child: Text('No bookmarks yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: saved.length,
              itemBuilder: (context, i) {
                final item = saved[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(item.reference),
                    subtitle: Text(item.translation,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.bookmark_remove_outlined),
                      onPressed: () => bookmarks.toggle(item.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
