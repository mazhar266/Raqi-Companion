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

  test('the original ruqyah categories stay ungrouped', () {
    final top = categories.where((c) => c.group.isEmpty).map((c) => c.id);
    expect(top, ['common', 'sihr', 'hasad', 'unseen', 'adhkar', 'sword']);
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

  test('ruqyah items keep the default script and their tajweed colouring', () {
    final items = [
      for (final c in categories.where((c) => c.group.isEmpty)) ...c.items
    ];
    expect(items.every((i) => i.script.isEmpty), isTrue);
    expect(items.every((i) => i.supportsTajweed), isTrue);
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
