class RuqyahItem {
  final String id;
  final String reference;
  final String arabic;
  final String transliteration;
  final String translation;
  final int repeat;
  final String note;

  /// Orthography of [arabic]: empty for imlaei, `'uthmani'` for passages
  /// sourced from the Quran data in `sources/`.
  ///
  /// Informational. The tajweed parser handles both, so this no longer gates
  /// colouring — it records where the text came from, which matters when
  /// re-checking a passage against its source.
  final String script;

  const RuqyahItem({
    required this.id,
    required this.reference,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.repeat,
    required this.note,
    this.script = '',
  });

  factory RuqyahItem.fromJson(Map<String, dynamic> json) => RuqyahItem(
        id: json['id'] as String,
        reference: json['reference'] as String,
        arabic: json['arabic'] as String,
        transliteration: json['transliteration'] as String? ?? '',
        translation: json['translation'] as String? ?? '',
        repeat: (json['repeat'] as num?)?.toInt() ?? 1,
        note: json['note'] as String? ?? '',
        script: json['script'] as String? ?? '',
      );
}

class Category {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final List<RuqyahItem> items;

  /// Optional menu this category is nested under, e.g. `'Dawah'`. Categories
  /// sharing a group are reached through one card on the home screen instead
  /// of appearing at the top level, and are left out of the Session
  /// checklist, which is for ruqyah recitation. Empty means top level.
  final String group;

  const Category({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    this.group = '',
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String? ?? '',
        icon: json['icon'] as String? ?? 'menu_book',
        group: json['group'] as String? ?? '',
        items: (json['items'] as List<dynamic>)
            .map((e) => RuqyahItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
