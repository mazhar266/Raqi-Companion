import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A list the user assembled themselves, as an ordered set of QQL queries.
///
/// Queries are stored rather than resolved text: they stay small, they survive
/// a data update, and one entry can stand for a whole passage (`Q:2:1-5`).
/// They are resolved for display by `QqlHelper`, so a list can be built and
/// read only where QQL runs.
@immutable
class UserList {
  const UserList({required this.id, required this.name, required this.queries});

  final String id;
  final String name;
  final List<String> queries;

  UserList copyWith({String? name, List<String>? queries}) => UserList(
        id: id,
        name: name ?? this.name,
        queries: queries ?? this.queries,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'queries': queries};

  factory UserList.fromJson(Map<String, dynamic> json) => UserList(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Untitled',
        queries:
            (json['queries'] as List<dynamic>? ?? const []).cast<String>(),
      );
}

/// The user's lists, persisted in `shared_preferences` as one JSON string
/// under `'userLists'`.
///
/// Mirrors [BookmarkStore]: a plain [ChangeNotifier] created once at the app
/// root and passed down. Every mutation writes through immediately.
class UserListStore extends ChangeNotifier {
  static const _key = 'userLists';

  List<UserList> _lists = const [];
  bool _loaded = false;

  List<UserList> get lists => List.unmodifiable(_lists);
  bool get loaded => _loaded;

  UserList? byId(String id) {
    for (final list in _lists) {
      if (list.id == id) return list;
    }
    return null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _lists = _decode(raw);
    _loaded = true;
    notifyListeners();
  }

  static List<UserList> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(UserList.fromJson)
          .toList();
    } on FormatException {
      // Corrupt or hand-edited preferences must not brick the tab.
      return const [];
    }
  }

  Future<void> _save() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_lists.map((l) => l.toJson()).toList()));
  }

  /// Creates an empty list and returns it.
  Future<UserList> create(String name) async {
    final list = UserList(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Untitled list' : name.trim(),
      queries: const [],
    );
    _lists = [..._lists, list];
    await _save();
    return list;
  }

  Future<void> rename(String id, String name) async {
    if (name.trim().isEmpty) return;
    _lists = [
      for (final l in _lists) l.id == id ? l.copyWith(name: name.trim()) : l
    ];
    await _save();
  }

  Future<void> delete(String id) async {
    _lists = [for (final l in _lists) if (l.id != id) l];
    await _save();
  }

  Future<void> addQuery(String id, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _lists = [
      for (final l in _lists)
        l.id == id ? l.copyWith(queries: [...l.queries, trimmed]) : l
    ];
    await _save();
  }

  Future<void> removeQueryAt(String id, int index) async {
    _lists = [
      for (final l in _lists)
        if (l.id == id && index >= 0 && index < l.queries.length)
          l.copyWith(queries: [...l.queries]..removeAt(index))
        else
          l
    ];
    await _save();
  }

  /// Adds lists read from a backup, giving each a fresh id so a file restored
  /// onto a device that already has lists cannot collide with them.
  ///
  /// With [replace] the existing lists are dropped first. Returns how many
  /// were added.
  Future<int> importLists(
    List<({String name, List<String> queries})> incoming, {
    required bool replace,
  }) async {
    // Ids are microsecond timestamps, so nudge each one to keep them distinct
    // within a single import.
    final base = DateTime.now().microsecondsSinceEpoch;
    final restored = [
      for (final (index, entry) in incoming.indexed)
        UserList(
          id: '${base + index}',
          name: entry.name,
          queries: entry.queries,
        )
    ];
    _lists = replace ? restored : [..._lists, ...restored];
    await _save();
    return restored.length;
  }

  Future<void> moveQuery(String id, int from, int to) async {
    _lists = [
      for (final l in _lists)
        if (l.id == id)
          l.copyWith(queries: () {
            final q = [...l.queries];
            if (from < 0 || from >= q.length) return q;
            final item = q.removeAt(from);
            q.insert(to.clamp(0, q.length), item);
            return q;
          }())
        else
          l
    ];
    await _save();
  }
}
