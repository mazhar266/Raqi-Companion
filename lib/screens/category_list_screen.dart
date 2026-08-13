import 'package:flutter/material.dart';

import '../bookmarks.dart';
import '../models.dart';
import '../theme_store.dart';
import 'app_menu.dart';
import 'bookmarks_screen.dart';
import 'category_group_screen.dart';
import 'item_list_screen.dart';
import 'session_screen.dart';

/// Grouped categories, keyed by group name, in first-appearance order.
Map<String, List<Category>> _groups(List<Category> categories) {
  final groups = <String, List<Category>>{};
  for (final c in categories) {
    if (c.group.isNotEmpty) {
      groups.putIfAbsent(c.group, () => []).add(c);
    }
  }
  return groups;
}

IconData categoryIcon(String name) {
  switch (name) {
    case 'menu_book':
      return Icons.menu_book;
    case 'auto_stories':
      return Icons.auto_stories;
    case 'shield':
      return Icons.shield_outlined;
    case 'visibility_off':
      return Icons.visibility_off_outlined;
    case 'wb_sunny':
      return Icons.wb_sunny_outlined;
    case 'favorite':
      return Icons.favorite_outline;
    case 'sword':
      return Icons.security_outlined;
    case 'fire':
      return Icons.local_fire_department_outlined;
    case 'bolt':
      return Icons.bolt_outlined;
    case 'spa':
      return Icons.spa_outlined;
    case 'nights_stay':
      return Icons.nights_stay_outlined;
    default:
      return Icons.bookmark_outline;
  }
}

class CategoryListScreen extends StatelessWidget {
  final List<Category> categories;
  final BookmarkStore bookmarks;
  final ThemeStore themeStore;

  const CategoryListScreen({
    super.key,
    required this.categories,
    required this.bookmarks,
    required this.themeStore,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raqi Companion'),
        actions: [AppMenuButton(themeStore: themeStore)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ActionCard(
            icon: Icons.play_circle_outline,
            title: 'Start Session',
            subtitle: 'Guided recitation checklist across all categories',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SessionScreen(categories: categories),
            )),
          ),
          _ActionCard(
            icon: Icons.bookmark_outline,
            title: 'Bookmarks',
            subtitle: '${bookmarks.ids.length} saved',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  BookmarksScreen(categories: categories, bookmarks: bookmarks),
            )),
          ),
          const SizedBox(height: 12),
          ...categories.where((c) => c.group.isEmpty).map((c) => _ActionCard(
                icon: categoryIcon(c.icon),
                title: c.title,
                subtitle: c.subtitle,
                trailing: Text('${c.items.length}'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ItemListScreen(
                      category: c, bookmarks: bookmarks),
                )),
              )),
          // Grouped categories collapse into one card per group, in the order
          // the groups first appear in the data.
          ..._groups(categories).entries.map((entry) => _ActionCard(
                icon: Icons.diversity_3_outlined,
                title: entry.key,
                subtitle: entry.value.map((c) => c.title).join(' · '),
                trailing: Text('${entry.value.length}'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CategoryGroupScreen(
                    group: entry.key,
                    categories: entry.value,
                    bookmarks: bookmarks,
                  ),
                )),
              )),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
