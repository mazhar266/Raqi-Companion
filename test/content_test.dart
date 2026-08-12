@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/models.dart';

/// Verses in the Dawah sections are copied from the vendored Quran data rather
/// than retyped, so they can be checked back against their source.
const _quran = 'sources/quran-json-arabic/dist/chapters/en';

List<Category> loadCategories() {
  final raw = jsonDecode(File('assets/data/ruqyah.json').readAsStringSync())
      as Map<String, dynamic>;
  return (raw['categories'] as List)
      .map((e) => Category.fromJson(e as Map<String, dynamic>))
      .toList();
}

void main() {
  late List<Category> categories;

  setUp(() => categories = loadCategories());

  test('the Dawah group has exactly the three expected sections', () {
    final dawah = categories.where((c) => c.group == 'Dawah').toList();

    expect(dawah.map((c) => c.id), [
      'dawah-jews',
      'dawah-christians',
      'dawah-shaitan',
    ]);
    expect(dawah.every((c) => c.items.isNotEmpty), isTrue);
  });

  test('the baseline modules and Sword stay ungrouped, in order', () {
    final top = categories.where((c) => c.group.isEmpty).map((c) => c.id);
    expect(top, [
      'module-general',
      'module-sihr',
      'module-ayn',
      'module-jinn',
      'sword',
    ]);
  });

  test('intensive and daily-practice modules are grouped out of Session', () {
    Iterable<String> group(String name) =>
        categories.where((c) => c.group == name).map((c) => c.id);

    expect(group('Intensive'),
        ['module-harq', 'module-qital', 'module-sakinah']);
    expect(group('Daily Practice'), ['module-shield', 'module-situational']);
  });

  test('reused imlaei passages keep their tajweed colouring', () {
    // These came with the repository as imlaei text and are carried over
    // verbatim, so the parser still applies to them.
    final byId = {
      for (final c in categories)
        for (final i in c.items) i.id: i,
    };
    for (final id in [
      'm1-fatihah',
      'm1-ayat-kursi',
      'm1-ikhlas',
      'm1-falaq',
      'm1-nas',
      'm2-baqarah-102',
      'm2-araf-117-122',
      'm3-nisa-54',
      'm3-qalam-51-52',
    ]) {
      expect(byId[id], isNotNull, reason: '$id is missing');
      expect(byId[id]!.supportsTajweed, isTrue, reason: '$id lost tajweed');
    }
  });

  test('module 9 procedural steps carry a note instead of Arabic', () {
    final situational =
        categories.firstWhere((c) => c.id == 'module-situational');
    final stepsWithoutArabic =
        situational.items.where((i) => i.arabic.isEmpty).toList();

    expect(stepsWithoutArabic, isNotEmpty);
    expect(stepsWithoutArabic.every((i) => i.note.isNotEmpty), isTrue);
  });

  test('every item id is unique across the whole file', () {
    final ids = [for (final c in categories) ...c.items.map((i) => i.id)];
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('Dawah items are marked uthmani and opt out of tajweed', () {
    final items = [
      for (final c in categories.where((c) => c.group == 'Dawah')) ...c.items
    ];
    expect(items.every((i) => i.script == 'uthmani'), isTrue);
    expect(items.every((i) => !i.supportsTajweed), isTrue);
  });

  test('the Sword section is untouched imlaei with tajweed', () {
    final sword = categories.firstWhere((c) => c.id == 'sword');
    expect(sword.items, hasLength(20));
    expect(sword.items.every((i) => i.script.isEmpty), isTrue);
    expect(sword.items.every((i) => i.supportsTajweed), isTrue);
  });

  test('every Dawah item carries a note, translation and transliteration', () {
    for (final c in categories.where((c) => c.group == 'Dawah')) {
      for (final i in c.items) {
        expect(i.note, isNotEmpty, reason: '${i.id} has no note');
        expect(i.translation, isNotEmpty, reason: '${i.id} has no translation');
        expect(i.transliteration, isNotEmpty, reason: '${i.id} no translit');
      }
    }
  });

  test('single-ayah Dawah passages match the source data byte for byte', () {
    // Guards against the Arabic being edited by hand after generation.
    final checks = {
      'dawah-jews-16-125': (16, 125),
      'dawah-jews-5-32': (5, 32),
      'dawah-christians-4-171': (4, 171),
      'dawah-shaitan-7-27': (7, 27),
    };
    final byId = {
      for (final c in categories)
        for (final i in c.items) i.id: i,
    };

    checks.forEach((id, ref) {
      final item = byId[id];
      expect(item, isNotNull, reason: '$id is missing');

      final chapter = jsonDecode(
        File('$_quran/${ref.$1}.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final verse = (chapter['verses'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((v) => v['id'] == ref.$2);

      expect(item!.arabic, verse['text']);
      expect(item.translation, verse['translation']);
    });
  });

  test('multi-ayah passages carry an ayah marker per verse', () {
    final byId = {
      for (final c in categories)
        for (final i in c.items) i.id: i,
    };
    // 2:168-169 — two verses, so two markers.
    final item = byId['dawah-shaitan-2-168-169']!;
    expect('﴿'.allMatches(item.arabic), hasLength(2));
    expect(item.arabic, contains('﴿١٦٨﴾'));
    expect(item.arabic, contains('﴿١٦٩﴾'));
  });
}
