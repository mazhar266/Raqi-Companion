@TestOn('vm')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/list_backup.dart';
import 'package:raqi_companion/user_lists.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lists = [
  UserList(id: 'a', name: 'Morning', queries: ['Q:2:255', 'Q:112']),
  UserList(id: 'b', name: 'Against sihr', queries: ['Q:2:102', 'B::6018']),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('encodeBackup', () {
    test('writes references only, never resolved content', () {
      final decoded =
          jsonDecode(encodeBackup(_lists)) as Map<String, dynamic>;

      expect(decoded['app'], 'raqi_companion');
      expect(decoded['type'], 'lists');
      expect(decoded['version'], backupFormatVersion);
      expect(decoded['lists'], hasLength(2));

      final first = (decoded['lists'] as List).first as Map<String, dynamic>;
      expect(first, {
        'name': 'Morning',
        'queries': ['Q:2:255', 'Q:112'],
      });
      // Ids are device-local and must not travel; nothing else may either.
      expect(first.containsKey('id'), isFalse);
    });

    test('carries no Arabic — the whole file is ASCII references', () {
      final text = encodeBackup(_lists);
      expect(text.runes.every((r) => r < 128), isTrue);
    });

    test('is stable enough to diff — indented and dated', () {
      final text =
          encodeBackup(_lists, exportedAt: DateTime.utc(2026, 8, 13, 9, 30));
      expect(text, contains('\n  '));
      expect(text, contains('2026-08-13T09:30:00.000Z'));
    });
  });

  group('decodeBackup', () {
    test('round-trips what encodeBackup wrote', () {
      final restored = decodeBackup(encodeBackup(_lists));

      expect(restored, hasLength(2));
      expect(restored.first.name, 'Morning');
      expect(restored.first.queries, ['Q:2:255', 'Q:112']);
      expect(restored.last.queries, ['Q:2:102', 'B::6018']);
    });

    test('drops blank entries and trims', () {
      final restored = decodeBackup(jsonEncode({
        'type': 'lists',
        'version': 1,
        'lists': [
          {
            'name': '  Spaced  ',
            'queries': [' Q:1 ', '', '   ']
          }
        ],
      }));
      expect(restored.single.name, 'Spaced');
      expect(restored.single.queries, ['Q:1']);
    });

    test('rejects a file that is not JSON', () {
      expect(() => decodeBackup('nonsense'),
          throwsA(isA<ListBackupException>()));
    });

    test('rejects JSON that is not one of our backups', () {
      expect(
        () => decodeBackup('{"hello":"world"}'),
        throwsA(isA<ListBackupException>().having((e) => e.message, 'message',
            contains('not a list backup'))),
      );
    });

    test('rejects a newer format version rather than guessing', () {
      expect(
        () => decodeBackup(
            jsonEncode({'type': 'lists', 'version': 99, 'lists': []})),
        throwsA(isA<ListBackupException>()
            .having((e) => e.message, 'message', contains('newer version'))),
      );
    });

    test('rejects a malformed list instead of importing half of it', () {
      expect(
        () => decodeBackup(jsonEncode({
          'type': 'lists',
          'version': 1,
          'lists': [
            {
              'name': 'Good',
              'queries': ['Q:1']
            },
            {
              'name': 'Bad',
              'queries': [42]
            },
          ],
        })),
        throwsA(isA<ListBackupException>()
            .having((e) => e.message, 'message', contains('"Bad"'))),
      );
    });

    test('rejects an unnamed list', () {
      expect(
        () => decodeBackup(jsonEncode({
          'type': 'lists',
          'version': 1,
          'lists': [
            {'name': '  ', 'queries': []}
          ],
        })),
        throwsA(isA<ListBackupException>()),
      );
    });
  });

  group('importing into the store', () {
    late UserListStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = UserListStore();
      await store.load();
    });

    test('merging keeps what is already there', () async {
      await store.create('Existing');
      final added =
          await store.importLists(decodeBackup(encodeBackup(_lists)),
              replace: false);

      expect(added, 2);
      expect(store.lists.map((l) => l.name),
          ['Existing', 'Morning', 'Against sihr']);
    });

    test('replacing drops what is already there', () async {
      await store.create('Existing');
      await store.importLists(decodeBackup(encodeBackup(_lists)),
          replace: true);

      expect(store.lists.map((l) => l.name), ['Morning', 'Against sihr']);
    });

    test('restored lists get fresh, distinct ids', () async {
      await store.importLists(decodeBackup(encodeBackup(_lists)),
          replace: false);

      final ids = store.lists.map((l) => l.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      // The ids in the fixture must not survive the trip.
      expect(ids, isNot(contains('a')));
    });

    test('an import survives a reload', () async {
      await store.importLists(decodeBackup(encodeBackup(_lists)),
          replace: true);

      final reloaded = UserListStore();
      await reloaded.load();
      expect(reloaded.lists.map((l) => l.name), ['Morning', 'Against sihr']);
      expect(reloaded.lists.first.queries, ['Q:2:255', 'Q:112']);
    });

    test('a full export/import cycle preserves everything', () async {
      await store.create('One');
      await store.addQuery(store.lists.single.id, 'Q:2:1-5,255');
      await store.addQuery(store.lists.single.id, 'HM::75');

      final file = encodeBackup(store.lists);
      final fresh = UserListStore();
      SharedPreferences.setMockInitialValues({});
      await fresh.load();
      await fresh.importLists(decodeBackup(file), replace: true);

      expect(fresh.lists.single.name, 'One');
      expect(fresh.lists.single.queries, ['Q:2:1-5,255', 'HM::75']);
    });
  });

  test('the file name is dated and ends in .json', () {
    expect(backupFileName(now: DateTime(2026, 8, 3)),
        'raqi-lists-2026-08-03.json');
  });
}
