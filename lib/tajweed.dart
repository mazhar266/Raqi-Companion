import 'package:flutter/material.dart';

import 'main.dart';

/// A tajweed rule that [parseTajweed] can recognise in vocalised Arabic text.
///
/// Each rule carries its own colour for light and dark themes; use
/// [color] rather than the raw fields.
enum TajweedRule {
  ghunnah(
    'Ghunnah',
    'Nasalisation held for two counts on a doubled ن or م.',
    Color(0xFF17803D),
    Color(0xFF63D68C),
  ),
  idghamGhunnah(
    'Idgham with ghunnah',
    'Noon sakin or tanwin merging into a following ي ن م و, with nasalisation.',
    Color(0xFF0E7490),
    Color(0xFF4DD0E1),
  ),
  idghamNoGhunnah(
    'Idgham without ghunnah',
    'Noon sakin or tanwin merging into a following ل ر, with no nasalisation.',
    Color(0xFF4338CA),
    Color(0xFF9FA8FF),
  ),
  iqlab(
    'Iqlab',
    'Noon sakin or tanwin pronounced as a hidden م before ب.',
    Color(0xFF7E22CE),
    Color(0xFFD09BF5),
  ),
  ikhfa(
    'Ikhfa',
    'Noon sakin or tanwin hidden with ghunnah before the fifteen ikhfa letters.',
    Color(0xFFB45309),
    Color(0xFFF0A85A),
  ),
  idghamShafawi(
    'Idgham shafawi',
    'Meem sakin merging into a following م, with ghunnah.',
    Color(0xFF4D7C0F),
    Color(0xFFB2DB63),
  ),
  ikhfaShafawi(
    'Ikhfa shafawi',
    'Meem sakin hidden with ghunnah before ب.',
    Color(0xFFBE185D),
    Color(0xFFF582B0),
  ),
  qalqalah(
    'Qalqalah',
    'Echoing bounce on a sakin ق ط ب ج د.',
    Color(0xFF1D4ED8),
    Color(0xFF87ADFF),
  ),
  madd(
    'Madd (4–6 counts)',
    'Prolongation of a madd letter before a hamza or a shadda.',
    Color(0xFFB91C1C),
    Color(0xFFFF8F85),
  );

  const TajweedRule(this.label, this.description, this._light, this._dark);

  /// Short name shown in the legend.
  final String label;

  /// One-line explanation shown in the legend.
  final String description;

  final Color _light;
  final Color _dark;

  Color color(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;
}

/// A run of text sharing one rule. [rule] is null for uncoloured text
/// (letters with no applicable rule, spaces, waqf marks, ayah numbers).
class TajweedSegment {
  final String text;
  final TajweedRule? rule;

  const TajweedSegment(this.text, this.rule);

  @override
  String toString() => 'TajweedSegment($text, ${rule?.name})';
}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------

const int _hamza = 0x0621;
const int _alefMadda = 0x0622;
const int _alef = 0x0627;
const int _ba = 0x0628;
const int _alefMaqsura = 0x0649;
const int _ya = 0x064A;
const int _waw = 0x0648;
const int _noon = 0x0646;
const int _meem = 0x0645;
const int _alefWasla = 0x0671;

const int _fathatan = 0x064B;
const int _dammatan = 0x064C;
const int _kasratan = 0x064D;
const int _fatha = 0x064E;
const int _damma = 0x064F;
const int _kasra = 0x0650;
const int _shadda = 0x0651;
const int _sukun = 0x0652;
const int _superscriptAlef = 0x0670;

/// ي ن م و — merge into, keeping the nasal sound.
const Set<int> _idghamGhunnahLetters = {_ya, _noon, _meem, _waw};

/// ل ر — merge into with no nasal sound.
const Set<int> _idghamPlainLetters = {0x0644, 0x0631};

/// The fifteen letters that hide a preceding noon sakin or tanwin.
const Set<int> _ikhfaLetters = {
  0x062A, // ت
  0x062B, // ث
  0x062C, // ج
  0x062F, // د
  0x0630, // ذ
  0x0632, // ز
  0x0633, // س
  0x0634, // ش
  0x0635, // ص
  0x0636, // ض
  0x0637, // ط
  0x0638, // ظ
  0x0641, // ف
  0x0642, // ق
  0x0643, // ك
};

/// ق ط ب ج د.
const Set<int> _qalqalahLetters = {0x0642, 0x0637, _ba, 0x062C, 0x062F};

/// Every written form of the hamza.
const Set<int> _hamzaForms = {
  _hamza,
  _alefMadda,
  0x0623, // أ
  0x0624, // ؤ
  0x0625, // إ
  0x0626, // ئ
};

bool _isLetter(int c) =>
    (c >= 0x0621 && c <= 0x063A) ||
    (c >= 0x0641 && c <= 0x064A) ||
    c == _alefWasla;

/// Harakat, tanwin, shadda, sukun and the superscript alef. Deliberately
/// excludes the Quranic annotation signs at 0x06D6-0x06ED (waqf marks),
/// which are treated as separators.
bool _isMark(int c) => (c >= 0x064B && c <= 0x065F) || c == _superscriptAlef;

/// One base letter plus the diacritics attached to it, or a single
/// non-letter character (space, waqf mark, ayah number, punctuation).
class _Unit {
  final int base;
  final String marks;
  final int start;
  final int end;
  final int word;
  final bool isLetter;

  const _Unit({
    required this.base,
    required this.marks,
    required this.start,
    required this.end,
    required this.word,
    required this.isLetter,
  });

  bool has(int mark) => marks.codeUnits.contains(mark);

  bool get hasShadda => has(_shadda);

  bool get hasTanwin => has(_fathatan) || has(_dammatan) || has(_kasratan);

  /// True for an explicit sukun and for a bare consonant: in fully vocalised
  /// text an unmarked letter carries no vowel.
  bool get isSakin => has(_sukun) || marks.isEmpty;

  bool get isVowelled =>
      has(_fatha) || has(_damma) || has(_kasra) || hasTanwin || hasShadda;
}

List<_Unit> _tokenize(String text) {
  final units = <_Unit>[];
  var word = 0;
  var i = 0;
  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (_isLetter(c)) {
      var j = i + 1;
      final marks = StringBuffer();
      while (j < text.length && _isMark(text.codeUnitAt(j))) {
        marks.writeCharCode(text.codeUnitAt(j));
        j++;
      }
      units.add(_Unit(
        base: c,
        marks: marks.toString(),
        start: i,
        end: j,
        word: word,
        isLetter: true,
      ));
      i = j;
    } else {
      if (c == 0x20 || c == 0x0A || c == 0x09) word++;
      units.add(_Unit(
        base: c,
        marks: '',
        start: i,
        end: i + 1,
        word: word,
        isLetter: false,
      ));
      i++;
    }
  }
  return units;
}

/// Index of the next *pronounced* consonant at or after [from].
///
/// Skips separators as well as silent alefs: the alef written after a
/// fathatan, the alef of a madd, and the alef of hamzat al-wasl all carry no
/// vowel and never trigger a rule.
int _nextLetterIndex(List<_Unit> units, int from) {
  for (var k = from; k < units.length; k++) {
    final u = units[k];
    if (!u.isLetter) continue;
    final silentAlef =
        u.base == _alef || u.base == _alefWasla || u.base == _alefMaqsura;
    if (silentAlef && !u.isVowelled) continue;
    return k;
  }
  return -1;
}

int _prevLetterIndex(List<_Unit> units, int from) {
  for (var k = from; k >= 0; k--) {
    if (units[k].isLetter) return k;
  }
  return -1;
}

/// True when `units[i]` is a letter of prolongation: a bare alef after a
/// fatha, a sakin waw after a damma, a sakin ya after a kasra, or any cluster
/// carrying the superscript alef.
bool _isMaddLetter(List<_Unit> units, int i) {
  final u = units[i];
  if (u.has(_superscriptAlef)) return true;
  final p = _prevLetterIndex(units, i - 1);
  if (p == -1) return false;
  final prev = units[p];
  // The vowel must belong to the same word. A word-initial bare alef is
  // hamzat al-wasl (صِرَاطَ الَّذِينَ), which is elided, not prolonged.
  if (prev.word != u.word) return false;
  if (u.base == _alef && u.marks.isEmpty) return prev.has(_fatha);
  if (u.base == _waw && u.isSakin) return prev.has(_damma);
  if ((u.base == _ya || u.base == _alefMaqsura) && u.isSakin) {
    return prev.has(_kasra);
  }
  return false;
}

/// Splits vocalised Arabic into runs tagged with the tajweed rule that applies
/// to them. Every character of [text] appears in exactly one segment, so
/// concatenating the segments reproduces the input.
///
/// The parser reads the diacritics that are actually written, so it expects
/// fully vocalised text such as `assets/data/ruqyah.json`. It covers the noon
/// sakin, tanwin and meem sakin rules, ghunnah, qalqalah sughra, and madd of
/// four counts or more; natural (two-count) madd is left uncoloured.
List<TajweedSegment> parseTajweed(String text) {
  final units = _tokenize(text);
  final rules = List<TajweedRule?>.filled(units.length, null);

  for (var i = 0; i < units.length; i++) {
    final u = units[i];
    if (!u.isLetter) continue;

    // Ghunnah — a doubled noon or meem, regardless of what follows.
    if ((u.base == _noon || u.base == _meem) && u.hasShadda) {
      rules[i] = TajweedRule.ghunnah;
      continue;
    }

    // Qalqalah sughra — needs no lookahead, so it is safe at end of text.
    if (_qalqalahLetters.contains(u.base) && u.isSakin) {
      rules[i] = TajweedRule.qalqalah;
      continue;
    }

    final nextIndex = _nextLetterIndex(units, i + 1);
    if (nextIndex == -1) continue;
    final next = units[nextIndex];

    // Noon sakin and tanwin.
    if ((u.base == _noon && u.isSakin) || u.hasTanwin) {
      // Idgham never happens inside a single word: a noon sakin followed by
      // و or ي in the same word (دُنْيَا, صِنْوَان) stays clear. Tanwin is
      // always word-final, so it is always across a boundary.
      final sameWord = !u.hasTanwin && next.word == u.word;
      if (next.base == _ba) {
        rules[i] = TajweedRule.iqlab;
      } else if (_idghamGhunnahLetters.contains(next.base)) {
        if (!sameWord) rules[i] = TajweedRule.idghamGhunnah;
      } else if (_idghamPlainLetters.contains(next.base)) {
        if (!sameWord) rules[i] = TajweedRule.idghamNoGhunnah;
      } else if (_ikhfaLetters.contains(next.base)) {
        rules[i] = TajweedRule.ikhfa;
      }
      // Anything else is izhar halqi and stays uncoloured.
      if (rules[i] != null) continue;
    }

    // Meem sakin. Followed by anything other than م or ب it is izhar shafawi.
    if (u.base == _meem && u.isSakin) {
      if (next.base == _meem) {
        rules[i] = TajweedRule.idghamShafawi;
        continue;
      }
      if (next.base == _ba) {
        rules[i] = TajweedRule.ikhfaShafawi;
        continue;
      }
    }

    // Madd of four counts or more: before a shadda (lazim) or a hamza
    // (wajib within a word, jaiz across words).
    if ((next.hasShadda || _hamzaForms.contains(next.base)) &&
        _isMaddLetter(units, i)) {
      rules[i] = TajweedRule.madd;
    }
  }

  final segments = <TajweedSegment>[];
  final buffer = StringBuffer();
  TajweedRule? current;
  for (var i = 0; i < units.length; i++) {
    final rule = units[i].isLetter ? rules[i] : null;
    if (buffer.isNotEmpty && rule != current) {
      segments.add(TajweedSegment(buffer.toString(), current));
      buffer.clear();
    }
    current = rule;
    buffer.write(text.substring(units[i].start, units[i].end));
  }
  if (buffer.isNotEmpty) {
    segments.add(TajweedSegment(buffer.toString(), current));
  }
  return segments;
}

// ---------------------------------------------------------------------------
// Presentation helpers
// ---------------------------------------------------------------------------

/// [parseTajweed] output as spans coloured for the current theme.
List<TextSpan> tajweedSpans(BuildContext context, String arabic) {
  final brightness = Theme.of(context).brightness;
  return parseTajweed(arabic)
      .map((s) => TextSpan(
            text: s.text,
            style: s.rule == null
                ? null
                : TextStyle(color: s.rule!.color(brightness)),
          ))
      .toList();
}

/// Right-to-left Arabic text in the shared [arabicStyle], tajweed-coloured
/// unless [tajweed] is false.
Widget arabicText(
  BuildContext context,
  String arabic, {
  double size = 26,
  int? maxLines,
  bool tajweed = true,
}) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: Text.rich(
      TextSpan(
        children: tajweed ? tajweedSpans(context, arabic) : null,
        text: tajweed ? null : arabic,
      ),
      textAlign: TextAlign.right,
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
      style: arabicStyle(context, size: size),
    ),
  );
}

/// Bottom sheet explaining what each colour means.
Future<void> showTajweedLegend(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final brightness = Theme.of(context).brightness;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text('Tajweed colours',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'A reading aid only — always learn recitation from a qualified teacher.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...TajweedRule.values.map((rule) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: 3, right: 12),
                        decoration: BoxDecoration(
                          color: rule.color(brightness),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rule.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: rule.color(brightness),
                                )),
                            Text(rule.description,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      );
    },
  );
}
