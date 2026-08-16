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

  group('bundled fonts', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('every offered font is declared and its file exists', () {
      for (final font in ArabicFont.all) {
        expect(pubspec, contains('- family: ${font.family}'),
            reason: '${font.label} is offered but not declared in pubspec');
        final file = File('assets/fonts/${font.family}.ttf');
        expect(file.existsSync(), isTrue,
            reason: '${file.path} is missing');
      }
    });

    test('font ids are unique and stable', () {
      final ids = ArabicFont.all.map((f) => f.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      // Stored in preferences, so a rename silently resets people's choice.
      expect(ids, contains(ArabicFont.fallback.id));
    });

    test('an unknown stored id falls back rather than crashing', () {
      expect(ArabicFont.byId('deleted-font').id, ArabicFont.fallback.id);
      expect(ArabicFont.byId(null).id, ArabicFont.fallback.id);
    });

    // Combining marks are the ones that matter. A missing standalone glyph
    // (the ﴿ ﴾ markers, the ﷺ ligature) falls back to another face and still
    // looks right; a missing combining mark falls back too, but the fallback
    // face positions it without the primary's metrics, so it lands wrong.
    const combiningMarks = {
      'U+064B', 'U+064C', 'U+064D', 'U+064E', 'U+064F', 'U+0650', 'U+0651',
      'U+0652', 'U+0653', 'U+0656', 'U+0657', 'U+065E', 'U+0670', 'U+06E1',
      'U+06E2', 'U+06E5', 'U+06E6',
    };

    test('the default font covers every combining mark the app renders', () {
      // tool/check_font_coverage.py writes this; regenerate after adding a
      // font.
      final report = jsonDecode(
        File('tool/font_coverage.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final fonts = report['fonts'] as Map<String, dynamic>;

      final entry = fonts['${ArabicFont.fallback.family}.ttf']
          as Map<String, dynamic>?;
      expect(entry, isNotNull,
          reason: 'no coverage entry for the default font');
      final missing = (entry!['missing'] as List).cast<String>();
      final marks = missing.where(combiningMarks.contains).toList();
      expect(marks, isEmpty,
          reason: 'the default font cannot draw combining marks the app '
              'renders, which the fallback face would misposition: $marks');
    });

    test('fonts with known gaps say so in their note', () {
      final report = jsonDecode(
        File('tool/font_coverage.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final fonts = report['fonts'] as Map<String, dynamic>;

      for (final font in ArabicFont.all) {
        final entry = fonts['${font.family}.ttf'] as Map<String, dynamic>?;
        if (entry == null) continue;
        final missing = (entry['missing'] as List).cast<String>();
        // U+065C is a combining mark but occurs exactly once in the whole
        // corpus, so it is not worth warning anyone about.
        final notable = missing
            .where(combiningMarks.contains)
            .where((m) => m != 'U+065C')
            .toList();
        if (notable.isNotEmpty) {
          expect(font.note, contains('Missing'),
              reason: '${font.label} is missing $notable but its note in '
                  'Settings does not say so');
        }
      }
    });
  });

  group('ArabicFontStore', () {
    test('defaults to the fallback and persists a choice', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ArabicFontStore();
      await store.load();
      expect(store.font.id, ArabicFont.fallback.id);

      final other = ArabicFont.all.firstWhere((f) => f.id != store.font.id);
      await store.setFont(other);

      final reloaded = ArabicFontStore();
      await reloaded.load();
      expect(reloaded.font.id, other.id);
    });

    test('a stored id that no longer exists falls back', () async {
      SharedPreferences.setMockInitialValues({'arabicFont': 'gone'});
      final store = ArabicFontStore();
      await store.load();
      expect(store.font.id, ArabicFont.fallback.id);
    });

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

    test('size is clamped to the offered range on the way in and out',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = ArabicFontStore();
      await store.load();

      await store.setScale(99);
      expect(store.scale, ArabicFontStore.maxScale);
      await store.setScale(0.01);
      expect(store.scale, ArabicFontStore.minScale);
    });

    test('a corrupt stored size does not make the app unreadable', () async {
      // Hand-edited preferences, or a value from a future build.
      SharedPreferences.setMockInitialValues({'arabicFontScale': 40.0});
      final store = ArabicFontStore();
      await store.load();
      expect(store.scale, ArabicFontStore.maxScale);

      SharedPreferences.setMockInitialValues({'arabicFontScale': double.nan});
      final nan = ArabicFontStore();
      await nan.load();
      expect(nan.scale, ArabicFontStore.defaultScale);
    });

    test('font and size are independent', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ArabicFontStore();
      await store.load();

      await store.setScale(1.3);
      final other = ArabicFont.all.firstWhere((f) => f.id != store.font.id);
      await store.setFont(other);

      expect(store.scale, closeTo(1.3, 1e-9));
      expect(store.font.id, other.id);
    });
  });

  testWidgets('the scope drives both family and size in arabicStyle',
      (tester) async {
    const chosen = ArabicFont(id: 'x', family: 'Nabi', label: 'X');
    late TextStyle scaled;
    late TextStyle unscaled;

    await tester.pumpWidget(ArabicFontScope(
      font: chosen,
      scale: 1.5,
      child: MaterialApp(
        home: Builder(builder: (context) {
          scaled = arabicStyle(context, size: 20);
          unscaled = arabicStyle(context, size: 20, scaled: false);
          return const SizedBox();
        }),
      ),
    ));

    expect(scaled.fontFamily, 'Nabi');
    expect(scaled.fontSize, 30, reason: '20 at 1.5x');
    // The font previews opt out so the list stays scannable at any scale.
    expect(unscaled.fontSize, 20);
    expect(unscaled.fontFamily, 'Nabi');
  });

  testWidgets('outside a scope the defaults apply', (tester) async {
    late TextStyle style;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        style = arabicStyle(context, size: 20);
        return const SizedBox();
      }),
    ));
    expect(style.fontFamily, ArabicFont.fallback.family);
    expect(style.fontSize, 20);
  });

  testWidgets('Settings lists every font and applies a choice', (tester) async {
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

    expect(find.text('Arabic font'), findsOneWidget);
    for (final font in ArabicFont.all) {
      expect(find.text(font.label), findsOneWidget,
          reason: '${font.label} is not offered');
    }

    final target = ArabicFont.all.firstWhere((f) => f.id != fontStore.font.id);
    await tester.tap(find.text(target.label));
    await tester.pumpAndSettle();

    expect(fontStore.font.id, target.id);
  });

  testWidgets('Settings exposes the size slider and a reset', (tester) async {
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
    expect(find.text('100%'), findsOneWidget);

    // Reset is disabled while already at the default.
    final reset = find.widgetWithText(TextButton, 'Reset to 100%');
    expect(tester.widget<TextButton>(reset).onPressed, isNull);

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(fontStore.scale, greaterThan(ArabicFontStore.defaultScale));
    expect(find.text('100%'), findsNothing);
    expect(tester.widget<TextButton>(reset).onPressed, isNotNull);

    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(fontStore.scale, ArabicFontStore.defaultScale);
  });
}
