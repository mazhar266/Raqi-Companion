import 'package:flutter/material.dart';

import '../bookmarks.dart';
import '../models.dart';
import '../theme_store.dart';
import '../user_lists.dart';
import 'category_list_screen.dart';
import 'lists_screen.dart';
import 'qql_query_screen.dart';

/// Root screen: a bottom navigation bar over the browse and query tabs.
///
/// Each tab keeps its own `Scaffold` and app bar, and an [IndexedStack]
/// preserves their state — a query and its results survive switching away and
/// back.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.categories,
    required this.bookmarks,
    required this.themeStore,
    required this.userLists,
  });

  final List<Category> categories;
  final BookmarkStore bookmarks;
  final ThemeStore themeStore;
  final UserListStore userLists;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          CategoryListScreen(
            categories: widget.categories,
            bookmarks: widget.bookmarks,
            themeStore: widget.themeStore,
          ),
          ListsScreen(store: widget.userLists),
          const QqlQueryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Browse',
          ),
          NavigationDestination(
            icon: Icon(Icons.playlist_play_outlined),
            selectedIcon: Icon(Icons.playlist_play),
            label: 'Lists',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Query',
          ),
        ],
      ),
    );
  }
}
