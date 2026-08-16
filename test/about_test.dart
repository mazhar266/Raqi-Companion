@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/screens/about_screen.dart';
import 'package:raqi_companion/screens/app_menu.dart';
import 'package:raqi_companion/arabic_fonts.dart';
import 'package:raqi_companion/theme_store.dart';
import 'package:raqi_companion/user_lists.dart';
import 'package:raqi_companion/version.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// About is a long scrolling page and a ListView only builds what fits, so
  /// the default 800x600 surface would hide the lower half from the finders.
  Future<void> pumpAbout(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('About shows the contributor details and the version',
      (tester) async {
    await pumpAbout(tester);

    expect(find.text('Raqi Companion'), findsOneWidget);
    expect(find.text('An open sourced helper application'), findsOneWidget);
    expect(find.text('Initially contributed by'), findsOneWidget);
    expect(find.text('Mazhar Ahmed'), findsOneWidget);

    for (final line in const [
      'CTO of atB Jobs',
      'Lead Software Architect of Pounce Technology Oy',
      'CIO of Executive Insights Ltd',
      'CIO of Meghdoot Tourism',
      'BA in Islamic Studies in IOU',
      'Dawra-e-Hadith on Qawmi Madrasa',
      'MSc in Computer Science',
    ]) {
      expect(find.text(line), findsOneWidget, reason: 'missing: $line');
    }

    expect(find.text('Version $appVersionLabel'), findsOneWidget);
  });

  testWidgets('About credits the GPL-3 component it bundles', (tester) async {
    await pumpAbout(tester);

    // The app links against QQL, so the licence has to be stated somewhere.
    expect(find.textContaining('QQL'), findsOneWidget);
    expect(find.text('GPL-3.0-or-later'), findsOneWidget);
  });

  testWidgets('the overflow menu opens Settings and About', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeStore = ThemeStore();
    final arabicFonts = ArabicFontStore();
    final userLists = UserListStore();
    await themeStore.load();
    await arabicFonts.load();
    await userLists.load();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Home'),
          actions: [
            AppMenuButton(
                themeStore: themeStore,
                userLists: userLists,
                arabicFonts: arabicFonts)
          ],
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    // Back, then through to About.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('Mazhar Ahmed'), findsOneWidget);
  });
}
