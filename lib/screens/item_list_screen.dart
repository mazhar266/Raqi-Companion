import 'package:flutter/material.dart';

import '../bookmarks.dart';
import '../models.dart';
import '../tajweed.dart';
import 'ayat_detail_screen.dart';

class ItemListScreen extends StatelessWidget {
  final Category category;
  final BookmarkStore bookmarks;

  const ItemListScreen({
    super.key,
    required this.category,
    required this.bookmarks,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bookmarks,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(category.title)),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: category.items.length,
            itemBuilder: (context, i) {
              final item = category.items[i];
              final saved = bookmarks.isBookmarked(item.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AyatDetailScreen(
                      items: category.items,
                      index: i,
                      bookmarks: bookmarks,
                    ),
                  )),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.reference,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                            ),
                            if (item.repeat > 1)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Chip(
                                  label: Text('×${item.repeat}'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            IconButton(
                              icon: Icon(saved
                                  ? Icons.bookmark
                                  : Icons.bookmark_outline),
                              onPressed: () => bookmarks.toggle(item.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        arabicText(context, item.arabic,
                            size: 20,
                            maxLines: 2,
                            tajweed: item.supportsTajweed),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
