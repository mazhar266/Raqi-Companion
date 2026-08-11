class RuqyahItem {
  final String id;
  final String reference;
  final String arabic;
  final String transliteration;
  final String translation;
  final int repeat;
  final String note;

  const RuqyahItem({
    required this.id,
    required this.reference,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.repeat,
    required this.note,
  });

  factory RuqyahItem.fromJson(Map<String, dynamic> json) => RuqyahItem(
        id: json['id'] as String,
        reference: json['reference'] as String,
        arabic: json['arabic'] as String,
        transliteration: json['transliteration'] as String? ?? '',
        translation: json['translation'] as String? ?? '',
        repeat: (json['repeat'] as num?)?.toInt() ?? 1,
        note: json['note'] as String? ?? '',
      );
}

class Category {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final List<RuqyahItem> items;

  const Category({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String? ?? '',
        icon: json['icon'] as String? ?? 'menu_book',
        items: (json['items'] as List<dynamic>)
            .map((e) => RuqyahItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
