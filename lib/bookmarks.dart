import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkStore extends ChangeNotifier {
  static const _key = 'bookmarks';

  final Set<String> _ids = {};
  bool _loaded = false;

  Set<String> get ids => Set.unmodifiable(_ids);
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll(prefs.getStringList(_key) ?? const []);
    _loaded = true;
    notifyListeners();
  }

  bool isBookmarked(String itemId) => _ids.contains(itemId);

  Future<void> toggle(String itemId) async {
    if (_ids.contains(itemId)) {
      _ids.remove(itemId);
    } else {
      _ids.add(itemId);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids.toList());
  }
}
