@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/bookmarks.dart';
import 'package:raqi_companion/models.dart';
import 'package:raqi_companion/screens/home_shell.dart';
import 'package:raqi_companion/theme_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const category = Category(
    id: 'common',
    title: 'Common Ayats',
    subtitle: 'A subtitle',
    icon: 'menu_book',
    items: [],
  );

  const grouped = Category(
    id: 'dawah-jews',
    title: 'Dawah to Jewish Friends',
    subtitle: 'Common ground',
    icon: 'auto_stories',
    group: 'Dawah',
    items: [],
  );

  Future<void> pumpShell(
    WidgetTester tester, {
    List<Category> categories = const [category],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final bookmarks = BookmarkStore();
    final themeStore = ThemeStore();
    await bookmarks.load();
    await themeStore.load();

    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        categories: categories,
        bookmarks: bookmarks,
        themeStore: themeStore,
      ),
    ));
    // Not pumpAndSettle: the query tab shows a progress spinner while it
    // prepares, which never settles.
    await tester.pump();
  }

  testWidgets('shows both destinations and starts on Browse', (tester) async {
    await pumpShell(tester);

    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Query'), findsWidgets);
    expect(find.text('Raqi Companion'), findsOneWidget);
    expect(find.text('Common Ayats'), findsOneWidget);
  });

  testWidgets('switching to the query tab shows its app bar', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byIcon(Icons.search_outlined));
    await tester.pump(const Duration(milliseconds: 500));

    // The Query app bar title, on top of the destination label.
    expect(find.text('Query'), findsNWidgets(2));
  });

  testWidgets('grouped categories collapse into one card', (tester) async {
    await pumpShell(tester, categories: const [category, grouped]);

    // One card for the whole group, alongside the ungrouped category.
    expect(find.text('Dawah'), findsOneWidget);
    expect(find.text('Common Ayats'), findsOneWidget);

    // The section appears only as the group card's subtitle — never as a card
    // of its own, so it is not a ListTile title at this level.
    final subtitle = find.text('Dawah to Jewish Friends');
    expect(subtitle, findsOneWidget);
    expect(
      tester.widget<ListTile>(find.ancestor(of: subtitle, matching: find.byType(ListTile))).title,
      isA<Text>().having((t) => t.data, 'title', 'Dawah'),
    );
  });

  testWidgets('tapping the group card opens its sections', (tester) async {
    await pumpShell(tester, categories: const [category, grouped]);

    await tester.tap(find.text('Dawah'));
    await tester.pumpAndSettle();

    expect(find.text('Dawah to Jewish Friends'), findsOneWidget);
  });

  testWidgets('browse tab keeps its state across a switch', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byIcon(Icons.search_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Raqi Companion'), findsOneWidget);
    expect(find.text('Common Ayats'), findsOneWidget);
  });
}
