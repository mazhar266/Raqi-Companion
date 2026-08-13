@TestOn('vm')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/surahs.dart';
import 'package:raqi_companion/user_lists.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserListStore', () {
    late UserListStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = UserListStore();
      await store.load();
    });

    test('starts empty and loaded', () {
      expect(store.lists, isEmpty);
      expect(store.loaded, isTrue);
    });

    test('creates, renames and deletes a list', () async {
      final list = await store.create('Morning');
      expect(store.lists.single.name, 'Morning');

      await store.rename(list.id, 'Evening');
      expect(store.lists.single.name, 'Evening');

      await store.delete(list.id);
      expect(store.lists, isEmpty);
    });

    test('a blank name falls back rather than creating an unnamed list',
        () async {
      await store.create('   ');
      expect(store.lists.single.name, 'Untitled list');
    });

    test('adds, removes and reorders queries', () async {
      final list = await store.create('L');
      await store.addQuery(list.id, 'Q:2:255');
      await store.addQuery(list.id, 'Q:112');
      await store.addQuery(list.id, 'B::6018');
      expect(store.byId(list.id)!.queries, ['Q:2:255', 'Q:112', 'B::6018']);

      await store.moveQuery(list.id, 2, 0);
      expect(store.byId(list.id)!.queries, ['B::6018', 'Q:2:255', 'Q:112']);

      await store.removeQueryAt(list.id, 1);
      expect(store.byId(list.id)!.queries, ['B::6018', 'Q:112']);
    });

    test('blank queries are ignored', () async {
      final list = await store.create('L');
      await store.addQuery(list.id, '   ');
      expect(store.byId(list.id)!.queries, isEmpty);
    });

    test('survives a reload', () async {
      final list = await store.create('Kept');
      await store.addQuery(list.id, 'Q:2:1-5');

      final reloaded = UserListStore();
      await reloaded.load();

      expect(reloaded.lists.single.name, 'Kept');
      expect(reloaded.lists.single.queries, ['Q:2:1-5']);
    });

    test('persists as JSON under the userLists key', () async {
      await store.create('X');
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString('userLists')!) as List;
      expect(decoded.single, containsPair('name', 'X'));
    });

    test('corrupt preferences degrade to empty rather than throwing', () async {
      SharedPreferences.setMockInitialValues({'userLists': 'not json'});
      final broken = UserListStore();
      await broken.load();
      expect(broken.lists, isEmpty);
      expect(broken.loaded, isTrue);
    });

    test('mutations notify listeners', () async {
      var notifications = 0;
      store.addListener(() => notifications++);
      final list = await store.create('L');
      await store.addQuery(list.id, 'Q:1');
      expect(notifications, 2);
    });
  });

  group('buildQuery', () {
    test('chapter form with a range', () {
      expect(
        buildQuery(source: 'Q', bookWide: false, primary: 2, from: 1, to: 5),
        'Q:2:1-5',
      );
    });

    test('a single item omits the range', () {
      expect(
        buildQuery(source: 'Q', bookWide: false, primary: 2, from: 255),
        'Q:2:255',
      );
    });

    test('no selector takes the whole chapter', () {
      expect(buildQuery(source: 'Q', bookWide: false, primary: 112), 'Q:112');
    });

    test('an end before the start collapses to the single item', () {
      expect(
        buildQuery(source: 'Q', bookWide: false, primary: 2, from: 10, to: 3),
        'Q:2:10',
      );
    });

    test('book-wide form drops the chapter', () {
      expect(
        buildQuery(source: 'B', bookWide: true, primary: 1, from: 6018),
        'B::6018',
      );
      expect(
        buildQuery(source: 'Q', bookWide: true, from: 1, to: 7),
        'Q::1-7',
      );
    });
  });

  group('Surahs', () {
    test('loads all 114 with verse counts', () async {
      final surahs = await Surahs.load();
      expect(surahs, hasLength(114));
      expect(surahs.first.transliteration, 'Al-Fatihah');
      expect(surahs.first.verses, 7);
      expect(surahs[1].transliteration, 'Al-Baqarah');
      expect(surahs[1].verses, 286);
      expect(surahs.last.number, 114);
      expect(surahs.last.verses, 6);
    });

    test('every source the builder offers has a code', () {
      expect(QqlSource.all.map((s) => s.code),
          containsAll(['Q', 'HM', 'B', 'M', 'AD', 'T', 'N', 'IM']));
      expect(QqlSource.all.where((s) => s.isQuran), hasLength(1));
    });
  });
}
