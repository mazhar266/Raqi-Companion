import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

class DataService {
  static List<Category>? _cache;

  static Future<List<Category>> loadCategories() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/ruqyah.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = (decoded['categories'] as List<dynamic>)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache = list;
    return list;
  }

  static RuqyahItem? findItem(List<Category> categories, String itemId) {
    for (final c in categories) {
      for (final item in c.items) {
        if (item.id == itemId) return item;
      }
    }
    return null;
  }
}
