@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/qql/qql_helper.dart';

/// The checked-in Linux build. Only x86-64 Linux is vendored, so these tests
/// skip elsewhere rather than fail — see third_party/qql/README.md.
const _libraryPath = 'third_party/qql/native/linux-x64/libqql.so';
const _dataDirectory = 'sources';

void main() {
  final available =
      Platform.isLinux && File(_libraryPath).existsSync() && Directory(_dataDirectory).existsSync();
  final skip = available
      ? null
      : 'needs the vendored Linux build at $_libraryPath and $_dataDirectory/';

  group('QqlHelper', () {
    late QqlHelper qql;

    setUp(() {
      qql = QqlHelper.open(
        dataDirectory: _dataDirectory,
        libraryPath: _libraryPath,
      );
    });

    tearDown(() => qql.dispose());

    test('reports the native library version', () {
      expect(qql.version, matches(RegExp(r'^\d+\.\d+\.\d+')));
    });

    test('resolves a Quran reference with its metadata', () {
      final records = qql.query('Q:112:1');

      expect(records, hasLength(1));
      final record = records.single;
      expect(record.source, 'Q');
      expect(record.collection, 'Quran');
      expect(record.surah, 112);
      expect(record.ayah, 1);
      expect(record.arabic, isNotEmpty);
      expect(record.translation, isNotEmpty);
      expect(record.reference, 'Al-Ikhlas 112:1');
    });

    test('preserves query order and dedups within a reference', () {
      final ayat = qql.query('Q:2:255,1-3,3').map((r) => r.ayah).toList();
      expect(ayat, [255, 1, 2, 3]);
    });

    test('resolves across several sources in one query', () {
      final records = qql.query('Q:112:1;HM:27:1;B:1:1');
      expect(records.map((r) => r.source), ['Q', 'HM', 'B']);
      expect(records.every((r) => r.arabic.isNotEmpty), isTrue);
    });

    test('exposes hadith metadata through the record getters', () {
      final record = qql.query('B:1:1').single;
      expect(record.collection, 'Sahih al-Bukhari');
      expect(record.chapter, 1);
      expect(record.number, 1);
      expect(record.narrator, isNotNull);
      expect(record.reference, 'Sahih al-Bukhari 1:1');
    });

    test('a whole surah resolves to all of its ayat', () {
      expect(qql.query('Q:114'), hasLength(6));
    });

    test('a malformed query throws QqlQueryException with its position', () {
      expect(
        () => qql.query('Q:'),
        throwsA(isA<QqlQueryException>()
            .having((e) => e.code, 'code', isNotEmpty)
            .having((e) => e.position, 'position', isNotNull)),
      );
    });

    test('an out-of-range reference throws rather than returning empty', () {
      expect(() => qql.query('Q:115'), throwsA(isA<QqlQueryException>()));
    });

    test('queryJson reports a bad query as data instead of throwing', () {
      // Compact JSON over FFI, unlike the CLI's pretty-printed output.
      final response = jsonDecode(qql.queryJson('Q:')) as Map<String, dynamic>;
      expect(response['ok'], isFalse);
      expect(response['error'], isA<Map<String, dynamic>>());
    });

    test('dispose is idempotent and blocks further queries', () {
      qql.dispose();
      qql.dispose();
      expect(() => qql.query('Q:1:1'), throwsStateError);
    });
  }, skip: skip);

  test('isSupported is true on the VM', () {
    expect(QqlHelper.isSupported, isTrue);
  });
}
