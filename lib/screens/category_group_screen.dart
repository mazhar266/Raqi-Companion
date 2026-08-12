import 'package:flutter/material.dart';

import '../bookmarks.dart';
import '../models.dart';
import 'category_list_screen.dart' show categoryIcon;
import 'item_list_screen.dart';

/// The categories nested under one group, e.g. the sections of Dawah.
///
/// Reached from the group's card on the home screen; each entry opens the
/// ordinary [ItemListScreen].
class CategoryGroupScreen extends StatelessWidget {
  const CategoryGroupScreen({
    super.key,
    required this.group,
    required this.categories,
    required this.bookmarks,
  });

  final String group;
  final List<Category> categories;
  final BookmarkStore bookmarks;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(group)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: categories
            .map((c) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Icon(categoryIcon(c.icon), size: 30),
                    title: Text(c.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(c.subtitle),
                    trailing: Text('${c.items.length}'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          ItemListScreen(category: c, bookmarks: bookmarks),
                    )),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
