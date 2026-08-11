import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/tajweed.dart';

/// Only the segments that carry a rule, as (text, rule) pairs.
List<(String, TajweedRule)> coloured(String arabic) => parseTajweed(arabic)
    .where((s) => s.rule != null)
    .map((s) => (s.text, s.rule!))
    .toList();

void main() {
  group('noon sakin and tanwin', () {
    test('ikhfa before one of the fifteen letters', () {
      expect(coloured('مِنْ شَرِّ'), [('نْ', TajweedRule.ikhfa)]);
    });

    test('idgham with ghunnah into a following word', () {
      expect(coloured('وَمَنْ يَكْفُرْ'), [('نْ', TajweedRule.idghamGhunnah)]);
    });

    test('idgham without ghunnah into ر', () {
      expect(coloured('مِنْ رَبِّهِمْ'), [('نْ', TajweedRule.idghamNoGhunnah)]);
    });

    test('iqlab before ب', () {
      expect(coloured('مِنْ بَعْدِ'), [('نْ', TajweedRule.iqlab)]);
    });

    test('izhar before a throat letter is left uncoloured', () {
      expect(coloured('أَنْعَمْتَ'), isEmpty);
    });

    test('noon sakin before ي in the same word is izhar, not idgham', () {
      expect(coloured('الدُّنْيَا'), isEmpty);
    });

    test('tanwin applies across the silent alef that follows it', () {
      expect(coloured('عَبَثًا وَأَنَّكُمْ'), [
        ('ثً', TajweedRule.idghamGhunnah),
        ('نَّ', TajweedRule.ghunnah),
      ]);
    });
  });

  group('meem sakin', () {
    test('idgham shafawi into a following م', () {
      expect(coloured('أَنْتُمْ مُلْقُونَ'), [
        ('نْ', TajweedRule.ikhfa),
        ('مْ', TajweedRule.idghamShafawi),
      ]);
    });

    test('ikhfa shafawi before ب', () {
      expect(coloured('هُمْ بِضَارِّينَ'), [
        ('مْ', TajweedRule.ikhfaShafawi),
        ('ا', TajweedRule.madd),
      ]);
    });

    test('izhar shafawi is left uncoloured', () {
      expect(coloured('لَمْ يَكُنْ'), isEmpty);
    });
  });

  test('ghunnah on a doubled noon or meem', () {
    expect(coloured('إِنَّ'), [('نَّ', TajweedRule.ghunnah)]);
    expect(coloured('مِمَّا'), [('مَّ', TajweedRule.ghunnah)]);
  });

  test('qalqalah on a sakin ق ط ب ج د', () {
    expect(coloured('أَبْصَارِهِمْ'), [('بْ', TajweedRule.qalqalah)]);
    expect(coloured('الْحَمْدُ'), isEmpty);
  });

  group('madd', () {
    test('six counts before a shadda', () {
      expect(coloured('الضَّالِّينَ'), [('ا', TajweedRule.madd)]);
    });

    test('four to five counts before a hamza in the next word', () {
      expect(coloured('بِمَا أُنْزِلَ'), [
        ('ا', TajweedRule.madd),
        ('نْ', TajweedRule.ikhfa),
      ]);
    });

    test('natural two-count madd is left uncoloured', () {
      expect(coloured('قَالُوا'), isEmpty);
    });

    test('hamzat al-wasl after a fatha is not a madd letter', () {
      // The bare alef of الَّذِينَ is elided, not prolonged, even though a
      // fatha precedes it and a shadda follows it.
      expect(coloured('صِرَاطَ الَّذِينَ'), isEmpty);
      expect(coloured('وَلَا الضَّالِّينَ'), [('ا', TajweedRule.madd)]);
    });
  });

  group('segmentation', () {
    test('segments concatenate back to the input', () {
      const text = 'وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ ﴿٣﴾';
      expect(parseTajweed(text).map((s) => s.text).join(), text);
    });

    test('every ayat in the bundled asset round-trips losslessly', () {
      final data = jsonDecode(
        File('assets/data/ruqyah.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      var checked = 0;
      for (final category in data['categories'] as List<dynamic>) {
        for (final item in (category as Map)['items'] as List<dynamic>) {
          final arabic = (item as Map)['arabic'] as String;
          expect(parseTajweed(arabic).map((s) => s.text).join(), arabic,
              reason: 'round-trip failed for ${item['id']}');
          checked++;
        }
      }
      expect(checked, greaterThan(40));
    });

    test('waqf marks and ayah numbers stay uncoloured', () {
      final segments = parseTajweed('لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِلْمُتَّقِينَ ﴿٢﴾');
      for (final s in segments.where((s) => s.rule != null)) {
        expect(s.text, isNot(contains('﴿')));
        expect(s.text, isNot(contains('ۛ')));
      }
    });
  });
}
