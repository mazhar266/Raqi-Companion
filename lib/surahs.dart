import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One surah's identity, for the visual query builder.
class Surah {
  const Surah({
    required this.number,
    required this.name,
    required this.transliteration,
    required this.verses,
  });

  final int number;

  /// Arabic name, e.g. البقرة.
  final String name;

  /// Latin name, e.g. Al-Baqarah.
  final String transliteration;

  /// Ayah count, used to bound the range fields.
  final int verses;

  String get label => '$number · $transliteration';

  factory Surah.fromJson(Map<String, dynamic> json) => Surah(
        number: json['id'] as int,
        name: json['name'] as String,
        transliteration: json['transliteration'] as String,
        verses: json['total_verses'] as int,
      );
}

/// Surah metadata from `assets/data/surahs.json`.
///
/// A plain app asset rather than part of the QQL data in `sources/`, so the
/// query builder works without waiting for that to unpack — and on the web,
/// where it never does.
class Surahs {
  Surahs._();

  static List<Surah>? _cache;

  static Future<List<Surah>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/data/surahs.json');
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((e) => Surah.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache = list;
  }
}

/// The QQL sources the query builder offers, in the order they appear.
class QqlSource {
  const QqlSource(this.code, this.name, {this.isQuran = false});

  final String code;
  final String name;
  final bool isQuran;

  static const all = [
    QqlSource('Q', 'Quran', isQuran: true),
    QqlSource('HM', 'Hisnul Muslim'),
    QqlSource('B', 'Sahih al-Bukhari'),
    QqlSource('M', 'Sahih Muslim'),
    QqlSource('AD', 'Sunan Abi Dawud'),
    QqlSource('T', "Jami' at-Tirmidhi"),
    QqlSource('N', "Sunan an-Nasa'i"),
    QqlSource('IM', 'Sunan Ibn Majah'),
  ];
}

/// Builds a QQL reference from the builder's fields.
///
/// [primary] is ignored when [bookWide] is set, which produces the `SOURCE::n`
/// form that numbers across the whole collection.
String buildQuery({
  required String source,
  required bool bookWide,
  int? primary,
  int? from,
  int? to,
}) {
  final selector = switch ((from, to)) {
    (null, _) => '',
    (final f?, null) => '$f',
    (final f?, final t?) when t <= f => '$f',
    (final f?, final t?) => '$f-$t',
  };
  if (bookWide) return '$source::$selector';
  final chapter = primary ?? 1;
  return selector.isEmpty ? '$source:$chapter' : '$source:$chapter:$selector';
}
