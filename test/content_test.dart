@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/models.dart';

/// Verses in the Dawah sections are copied from the vendored Quran data rather
/// than retyped, so they can be checked back against their source.
const _quran = 'sources/quran/chapters';

/// `(surah, first, last)` from a reference like `Al-A'raf 7:117-122`, or a
/// whole surah where only its number is named (`Surah Al-Ikhlas 112`).
///
/// Mirrors the parsing in `tool/resync_quran_text.py`.
(int, int, int)? _parseReference(String reference) {
  final range = RegExp(r'(\d+)\s*:\s*(\d+)\s*-\s*(\d+)').firstMatch(reference);
  if (range != null) {
    return (
      int.parse(range.group(1)!),
      int.parse(range.group(2)!),
      int.parse(range.group(3)!),
    );
  }
  final single = RegExp(r'(\d+)\s*:\s*(\d+)').firstMatch(reference);
  if (single != null) {
    final ayah = int.parse(single.group(2)!);
    return (int.parse(single.group(1)!), ayah, ayah);
  }
  final whole = RegExp(r'(\d+)\s*$').firstMatch(reference);
  if (whole == null) return null;
  final surah = int.parse(whole.group(1)!);
  return (surah, 1, _chapter(surah)['total_verses'] as int);
}

final _chapters = <int, Map<String, dynamic>>{};

Map<String, dynamic> _chapter(int surah) => _chapters.putIfAbsent(
      surah,
      () => jsonDecode(File('$_quran/$surah.json').readAsStringSync())
          as Map<String, dynamic>,
    );

String _arabicNumber(int n) =>
    n.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();

/// The passage as the app stores it: one verse plain, several joined with an
/// `﴿n﴾` marker after each.
String _fetch((int, int, int) range) {
  final (surah, first, last) = range;
  final verses = (_chapter(surah)['verses'] as List)
      .cast<Map<String, dynamic>>()
      .where((v) => (v['id'] as int) >= first && (v['id'] as int) <= last)
      .toList();
  expect(verses, hasLength(last - first + 1),
      reason: '$surah:$first-$last is not in the data');

  if (verses.length == 1) return verses.single['text'] as String;
  return verses
      .map((v) => '${v['text']} ﴿${_arabicNumber(v['id'] as int)}﴾')
      .join(' ');
}

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

  test('the passages that were once imlaei are now Uthmani too', () {
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
      expect(byId[id]!.script, 'uthmani', reason: '$id is not Uthmani');
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

  test('Dawah items record that they came from the Quran data', () {
    final items = [
      for (final c in categories.where((c) => c.group == 'Dawah')) ...c.items
    ];
    expect(items.every((i) => i.script == 'uthmani'), isTrue);
  });

  test('the Sword section is Uthmani like the rest', () {
    final sword = categories.firstWhere((c) => c.id == 'sword');
    expect(sword.items, hasLength(20));
    expect(sword.items.every((i) => i.script == 'uthmani'), isTrue);
  });

  test('only the sunnah duas are not Quranic text', () {
    // Everything else must be resolvable against the Quran data, which is
    // what the test below relies on.
    final notQuran = [
      for (final c in categories)
        for (final i in c.items)
          if (i.script != 'uthmani') i.id
    ];
    expect(notQuran, [
      'm8-tahlil',
      'm8-earth-sky',
      'm8-kalimat',
      'm8-hasbiyallah',
      'm9-sleep-wudu',
      'm9-sleep-recite',
      'm9-sleep-quls',
      'm9-pain',
      'm9-home-entry',
    ]);
  });

  test('every Quranic ayah matches the source data byte for byte', () {
    // The whole file is generated by tool/resync_quran_text.py from
    // sources/quran, so any hand-edit to the Arabic — or a
    // reference that no longer names the passage it holds — fails here.
    var checked = 0;
    for (final category in categories) {
      for (final item in category.items) {
        if (item.script != 'uthmani') continue;

        final range = _parseReference(item.reference);
        expect(range, isNotNull,
            reason: '${item.id}: no surah:ayah in "${item.reference}"');

        expect(item.arabic, _fetch(range!),
            reason: '${item.id} (${item.reference}) does not match the '
                'Quran data; re-run tool/resync_quran_text.py');
        checked++;
      }
    }
    expect(checked, 128);
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
