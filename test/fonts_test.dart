@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/arabic_fonts.dart';
import 'package:raqi_companion/main.dart' show arabicStyle;
import 'package:raqi_companion/screens/settings_screen.dart';
import 'package:raqi_companion/theme_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the bundled font', () {
    test('is declared in pubspec and its file exists', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- family: $arabicFontFamily'));
      expect(File('assets/fonts/$arabicFontFamily.ttf').existsSync(), isTrue);
    });

    test('is the only one bundled', () {
      // One face, not a choice — anything else here is dead weight in the
      // APK, or a font someone half-added.
      final files = Directory('assets/fonts')
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .toList();
      expect(files, ['$arabicFontFamily.ttf']);
    });

    test('draws every combining mark the app renders', () {
      // tool/check_font_coverage.py writes this report. Combining marks are
      // the ones that matter: a missing standalone glyph (the ﴿ ﴾ markers,
      // the ﷺ ligature) falls back to another face and still looks right,
      // but a missing combining mark is positioned by the fallback's metrics
      // and lands wrong.
      const combiningMarks = {
        'U+064B', 'U+064C', 'U+064D', 'U+064E', 'U+064F', 'U+0650', 'U+0651',
        'U+0652', 'U+0653', 'U+0656', 'U+0657', 'U+065E', 'U+0670', 'U+06E1',
        'U+06E2', 'U+06E5', 'U+06E6',
      };
      final report = jsonDecode(
        File('tool/font_coverage.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final entry =
          (report['fonts'] as Map<String, dynamic>)['$arabicFontFamily.ttf']
              as Map<String, dynamic>?;

      expect(entry, isNotNull, reason: 'no coverage entry — rerun the tool');
      final missing = (entry!['missing'] as List).cast<String>();
      final marks = missing.where(combiningMarks.contains).toList();
      expect(marks, isEmpty,
          reason: 'the font cannot draw combining marks the app renders, '
              'which the fallback face would misposition: $marks');
    });
  });

  group('ArabicFontStore', () {
    test('size defaults to 100% and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ArabicFontStore();
      await store.load();
      expect(store.scale, ArabicFontStore.defaultScale);

      await store.setScale(1.4);

      final reloaded = ArabicFontStore();
      await reloaded.load();
      expect(reloaded.scale, closeTo(1.4, 1e-9));
    });

    test('size is clamped to the offered range', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ArabicFontStore();
      await store.load();

      await store.setScale(99);
      expect(store.scale, ArabicFontStore.maxScale);
      await store.setScale(0.01);
      expect(store.scale, ArabicFontStore.minScale);
    });

    test('a corrupt stored size does not make the app unreadable', () async {
      SharedPreferences.setMockInitialValues({'arabicFontScale': 40.0});
      final store = ArabicFontStore();
      await store.load();
      expect(store.scale, ArabicFontStore.maxScale);

      SharedPreferences.setMockInitialValues({'arabicFontScale': double.nan});
      final nan = ArabicFontStore();
      await nan.load();
      expect(nan.scale, ArabicFontStore.defaultScale);
    });
  });

  testWidgets('the scope drives the size in arabicStyle', (tester) async {
    late TextStyle scaled;
    late TextStyle unscaled;

    await tester.pumpWidget(ArabicFontScope(
      scale: 1.5,
      child: MaterialApp(
        home: Builder(builder: (context) {
          scaled = arabicStyle(context, size: 20);
          unscaled = arabicStyle(context, size: 20, scaled: false);
          return const SizedBox();
        }),
      ),
    ));

    expect(scaled.fontFamily, arabicFontFamily);
    expect(scaled.fontSize, 30, reason: '20 at 1.5x');
    expect(unscaled.fontSize, 20);
  });

  testWidgets('outside a scope the defaults apply', (tester) async {
    late TextStyle style;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        style = arabicStyle(context, size: 20);
        return const SizedBox();
      }),
    ));
    expect(style.fontFamily, arabicFontFamily);
    expect(style.fontSize, 20);
  });

  testWidgets('Settings has the size slider and no font picker',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeStore = ThemeStore();
    final fontStore = ArabicFontStore();
    await themeStore.load();
    await fontStore.load();

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(themeStore: themeStore, arabicFonts: fontStore),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Arabic size'), findsOneWidget);
    expect(find.text('Arabic font'), findsNothing,
        reason: 'the typeface is fixed; there is nothing to choose');
    expect(find.text('100%'), findsOneWidget);

    final reset = find.widgetWithText(TextButton, 'Reset to 100%');
    expect(tester.widget<TextButton>(reset).onPressed, isNull);

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(fontStore.scale, greaterThan(ArabicFontStore.defaultScale));
    expect(tester.widget<TextButton>(reset).onPressed, isNotNull);

    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(fontStore.scale, ArabicFontStore.defaultScale);
  });
}
