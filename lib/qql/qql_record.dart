/// Types returned by [QqlHelper]. Pure Dart — no `dart:ffi`, so this file is
/// safe to import on every platform including the web.
library;

/// One resolved ayah, hadith, or supplication.
///
/// QQL guarantees `source`, `collection`, `ar` and `en` on every record.
/// Everything else is source-specific and arrives flattened into [extra]:
/// `surah`/`ayah` for the Quran, `chapter`/`number`/`narrator` for hadith,
/// `chapter`/`chapter_title` for Hisnul Muslim.
class QqlRecord {
  const QqlRecord({
    required this.source,
    required this.collection,
    required this.arabic,
    required this.translation,
    required this.extra,
  });

  factory QqlRecord.fromJson(Map<String, dynamic> json) {
    final extra = Map<String, dynamic>.from(json)
      ..remove('source')
      ..remove('collection')
      ..remove('ar')
      ..remove('en');
    return QqlRecord(
      source: json['source'] as String? ?? '',
      collection: json['collection'] as String? ?? '',
      arabic: json['ar'] as String? ?? '',
      translation: json['en'] as String? ?? '',
      extra: Map.unmodifiable(extra),
    );
  }

  /// Source code, e.g. `Q`, `B`, `HM`.
  final String source;

  /// Human-readable collection name, e.g. `Quran`.
  final String collection;

  /// Arabic text, byte-for-byte as stored in the data files.
  final String arabic;

  /// English text.
  final String translation;

  /// Source-specific fields. Read through the getters below where one exists.
  final Map<String, dynamic> extra;

  int? get surah => extra['surah'] as int?;
  int? get ayah => extra['ayah'] as int?;
  int? get chapter => extra['chapter'] as int?;
  int? get number => extra['number'] as int?;
  String? get narrator => extra['narrator'] as String?;

  /// A human-readable citation, shaped to the source.
  ///
  /// Quran records read `Al-Ikhlas 112:1`; everything else falls back to the
  /// collection name with whatever chapter and item numbers are present.
  String get reference {
    if (surah != null) {
      final name = extra['surah_name_en'] as String?;
      final base = name == null ? 'Surah $surah' : '$name $surah';
      return ayah == null ? base : '$base:$ayah';
    }
    if (chapter == null) return collection;
    return number == null
        ? '$collection $chapter'
        : '$collection $chapter:$number';
  }

  @override
  String toString() => 'QqlRecord($reference)';
}

/// Thrown when a query could not be parsed or resolved.
class QqlQueryException implements Exception {
  const QqlQueryException(this.code, this.message, this.position);

  /// QQL error code, e.g. `QQL_PARSE_ERROR`.
  final String code;
  final String message;

  /// Character offset into the query, when the failure was a parse error.
  final int? position;

  @override
  String toString() => position == null
      ? 'QqlQueryException($code): $message'
      : 'QqlQueryException($code) at $position: $message';
}
