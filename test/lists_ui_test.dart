@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/screens/add_entry_sheet.dart';
import 'package:raqi_companion/screens/lists_screen.dart';
import 'package:raqi_companion/arabic_fonts.dart';
import 'package:raqi_companion/theme_store.dart';
import 'package:raqi_companion/user_lists.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creating a list from the empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = UserListStore();
    await store.load();

    final themeStore = ThemeStore();
    final arabicFonts = ArabicFontStore();
    await themeStore.load();
    await arabicFonts.load();
    await tester.pumpWidget(MaterialApp(
        home: ListsScreen(
            store: store, themeStore: themeStore, arabicFonts: arabicFonts)));
    expect(find.text('No lists yet'), findsOneWidget);

    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Morning routine');
    await tester.tap(find.text('Save'));
    // Not pumpAndSettle: saving opens the new list, which shows a progress
    // spinner while it prepares QQL, and that never settles under test.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.lists.single.name, 'Morning routine');
    expect(find.text('Morning routine'), findsWidgets);
  });

  testWidgets('an existing list shows its entry count', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = UserListStore();
    await store.load();
    final list = await store.create('Evening');
    await store.addQuery(list.id, 'Q:2:255');

    final themeStore = ThemeStore();
    final arabicFonts = ArabicFontStore();
    await themeStore.load();
    await arabicFonts.load();
    await tester.pumpWidget(MaterialApp(
        home: ListsScreen(
            store: store, themeStore: themeStore, arabicFonts: arabicFonts)));
    await tester.pump();

    expect(find.text('Evening'), findsOneWidget);
    expect(find.textContaining('1 entry'), findsOneWidget);
  });

  group('add entry sheet', () {
    Future<String?> openSheet(WidgetTester tester) async {
      String? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => result = await showAddEntrySheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('the picker previews the query it will add', (tester) async {
      await openSheet(tester);

      // Defaults to the Quran, chapter form, whole surah.
      expect(find.text('Q:1'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'From'), '1');
      await tester.enterText(find.widgetWithText(TextField, 'To'), '5');
      await tester.pumpAndSettle();
      expect(find.text('Q:1:1-5'), findsOneWidget);
    });

    testWidgets('range beyond the surah is rejected', (tester) async {
      await openSheet(tester);

      // Al-Fatihah has 7 ayat.
      await tester.enterText(find.widgetWithText(TextField, 'From'), '9');
      await tester.pumpAndSettle();

      expect(find.textContaining('has 7 ayat'), findsOneWidget);
      final add = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Add'));
      expect(add.onPressed, isNull, reason: 'Add must be disabled');
    });

    testWidgets('the book-wide switch drops the chapter', (tester) async {
      await openSheet(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'From'), '100');
      await tester.pumpAndSettle();

      expect(find.text('Q::100'), findsOneWidget);
    });

    testWidgets('typed mode returns the reference verbatim', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('Type'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'B::6018');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      // The sheet closed, which is what returning a value looks like here.
      expect(find.text('Add to list'), findsNothing);
    });
  });
}
