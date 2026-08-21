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
const int _maddahAbove = 0x0653;
const int _superscriptAlef = 0x0670;

// The "open" tanwin forms. Their Unicode names describe the glyph, not the
// role: verified against this data's own transliterations, U+0657 spells
// fathatan (jameeAAan), U+065E dammatan (sharabun) and U+0656 kasratan
// (rajulin). They outnumber the stacked forms above roughly three to one, so
// missing them would blind the parser to most tanwin in the Uthmani text.
const int _fathatanOpen = 0x0657;
const int _dammatanOpen = 0x065E;
const int _kasratanOpen = 0x0656;

// Uthmani script marks. The imlaei text in assets/data/ruqyah.json uses the
// codepoints above; the Quran data in sources/ writes several of them
// differently, and spells out some rulings the imlaei text leaves implicit.
//
// The conventions, verified against the data:
//   izhar   noon carries the sukun sign      مِنۡ عَاصِمٖ
//   iqlab   noon carries a small meem        مِنۢ بَعۡدِ
//   ikhfa   noon carries nothing             مِن شَفِيعٍ
//   idgham  noon carries nothing             مَن يَشَآء
const int _sukunUthmani = 0x06E1; // small high dotless head of khah
const int _iqlabMeemHigh = 0x06E2;
const int _iqlabMeemLow = 0x06ED;
const int _smallHighMadda = 0x06E4;
const int _smallWaw = 0x06E5;
const int _smallYeh = 0x06E6;
const int _smallHighYeh = 0x06E7;
const int _smallHighNoon = 0x06E8;
// Zeros marking a letter that is written but not pronounced.
const int _silentRoundZero = 0x06DF;
const int _silentRectZero = 0x06E0;

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

/// Marks that attach to the preceding letter.
///
/// Covers the imlaei set (harakat, tanwin, shadda, sukun, superscript alef)
/// plus the Uthmani signs that behave the same way. The remaining Quranic
/// annotation signs in 0x06D6-0x06ED are waqf and sajdah marks that stand on
/// their own, and stay separators.
bool _isMark(int c) =>
    (c >= 0x064B && c <= 0x065F) ||
    c == _superscriptAlef ||
    c == _sukunUthmani ||
    c == _iqlabMeemHigh ||
    c == _iqlabMeemLow ||
    c == _smallHighMadda ||
    c == _smallWaw ||
    c == _smallYeh ||
    c == _smallHighYeh ||
    c == _smallHighNoon ||
    c == _silentRoundZero ||
    c == _silentRectZero;

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

  bool get hasTanwin =>
      has(_fathatan) ||
      has(_dammatan) ||
      has(_kasratan) ||
      has(_fathatanOpen) ||
      has(_dammatanOpen) ||
      has(_kasratanOpen);

  bool get hasSukun => has(_sukun) || has(_sukunUthmani);

  /// The Uthmani small meem written over a noon sakin or tanwin, which is the
  /// mushaf spelling iqlab out rather than leaving it to be inferred.
  bool get hasIqlabMark => has(_iqlabMeemHigh) || has(_iqlabMeemLow);

  /// A letter written but not pronounced, marked with one of the small zeros.
  bool get isSilent => has(_silentRoundZero) || has(_silentRectZero);

  bool get isVowelled =>
      has(_fatha) || has(_damma) || has(_kasra) || hasTanwin || hasShadda;

  /// True for an explicit sukun and for a consonant carrying no vowel at all:
  /// in fully vocalised text that means the same thing. Uthmani leaves the
  /// noon bare for ikhfa and idgham, so this has to cover both.
  bool get isSakin => hasSukun || !isVowelled;

  /// The Uthmani maddah, and the marks standing in for a written madd letter
  /// (small waw and yeh, subscript alef, inverted damma).
  bool get hasMaddahSign => has(_maddahAbove) || has(_smallHighMadda);

  /// The superscript alef, and the small waw and yeh that stand in for the
  /// lengthened vowel of a pronoun (madd silah). Deliberately not the
  /// subscript alef or inverted damma — in this text those are tanwin.
  bool get hasMaddLetterMark =>
      has(_superscriptAlef) || has(_smallWaw) || has(_smallYeh);
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
    // Uthmani marks unpronounced letters explicitly.
    if (u.isSilent) continue;
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
  if (u.hasMaddLetterMark) return true;
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
    if (!u.isLetter || u.isSilent) continue;

    // Ghunnah — a doubled noon or meem, regardless of what follows.
    if ((u.base == _noon || u.base == _meem) && u.hasShadda) {
      rules[i] = TajweedRule.ghunnah;
      continue;
    }

    // Iqlab spelled out by the mushaf. Trusted over the lookahead below,
    // which cannot see it when the ب falls in the next word.
    if (u.hasIqlabMark) {
      rules[i] = TajweedRule.iqlab;
      continue;
    }

    // A maddah sign is the mushaf marking a madd longer than two counts, so
    // it needs no structural inference.
    if (u.hasMaddahSign) {
      rules[i] = TajweedRule.madd;
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
/// The open tanwin, rewritten to codepoints fonts actually draw as tanwin.
///
/// The bundled Quran data spells the open (staggered) tanwin with three
/// codepoints that mean something else in Unicode:
///
/// | in the data | Unicode says | the data means |
/// | --- | --- | --- |
/// | `U+0657` | inverted damma | open fathatan |
/// | `U+065E` | fatha with two dots | open dammatan |
/// | `U+0656` | subscript alef | open kasratan |
///
/// A font that follows Unicode draws them literally, so `إِصۡرٗا` in 2:286
/// renders with a damma above the reh and reads as *isru* instead of *isran*.
/// Checked against the data's own transliterations, U+0657 ends a word
/// transliterated `-an` in 2680 of 2680 cases, U+0656 `-in` in 99.8% and
/// U+065E `-un` in 97.7%, so the intent is not in doubt.
///
/// Unicode does have real open tanwin at U+08F0-U+08F2, but almost no font
/// ships those glyphs — the bundled face does not — so this maps to the plain
/// tanwin instead. That loses the staggered shape the printed mushaf uses to
/// mark idgham and ikhfa, and keeps the reading correct, which matters more.
///
/// One character in, one out, so offsets into the string are unchanged and
/// the tajweed segments still line up.
String normalizeQuranicMarks(String text) {
  const replacements = {
    0x0657: _fathatan,
    0x065E: _dammatan,
    0x0656: _kasratan,
  };
  if (!text.codeUnits.any(replacements.containsKey)) return text;
  return String.fromCharCodes(
      text.codeUnits.map((c) => replacements[c] ?? c));
}

Widget arabicText(
  BuildContext context,
  String arabic, {
  double size = 26,
  int? maxLines,
  bool tajweed = true,
}) {
  // Every Arabic string in the app goes through here, so this is the one
  // place the open-tanwin codepoints need correcting — the app's own content
  // and QQL results alike.
  final text = normalizeQuranicMarks(arabic);
  return Directionality(
    textDirection: TextDirection.rtl,
    child: Text.rich(
      TextSpan(
        children: tajweed ? tajweedSpans(context, text) : null,
        text: tajweed ? null : text,
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
