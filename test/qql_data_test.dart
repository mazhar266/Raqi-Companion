@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/qql/qql_data.dart';
import 'package:raqi_companion/qql/qql_helper.dart';

const _libraryPath = 'third_party/qql/native/linux-x64/libqql.so';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the QQL data is declared as assets in pubspec.yaml', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets =
        manifest.listAssets().where((k) => k.startsWith(QqlData.assetPrefix));

    // Asset directories are not recursive, so a missing pubspec entry shows up
    // here as a whole collection quietly vanishing.
    expect(assets, isNotEmpty, reason: 'no sources/ assets declared');
    expect(assets.where((k) => k.contains('quran-json-arabic')), hasLength(115));
    expect(assets.where((k) => k.contains('Hisn-Muslim-Json')), hasLength(1));
    expect(
      assets.where((k) => k.contains('hadith-json')),
      hasLength(429),
      reason: 'expected all nine hadith book directories',
    );
  });

  group('unpacking', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('qql-data-test');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('writes every asset and preserves the layout QQL expects', () async {
      var lastCopied = 0;
      var total = 0;
      final path = await QqlData.ensureUnpacked(
        into: temp,
        onProgress: (copied, t) {
          lastCopied = copied;
          total = t;
        },
      );

      expect(path, temp.path);
      expect(total, greaterThan(0));
      expect(lastCopied, total, reason: 'progress must reach the total');

      // The resolvers hard-code these paths relative to the data directory.
      expect(
        File('$path/quran-json-arabic/dist/chapters/en/112.json').existsSync(),
        isTrue,
      );
      expect(File('$path/Hisn-Muslim-Json/husn_en.json').existsSync(), isTrue);
      expect(
        File('$path/hadith-json/db/by_chapter/the_9_books/bukhari/1.json')
            .existsSync(),
        isTrue,
      );
    });

    test('is a no-op once the marker matches', () async {
      await QqlData.ensureUnpacked(into: temp);
      var copiedOnSecondRun = 0;
      await QqlData.ensureUnpacked(
        into: temp,
        onProgress: (_, __) => copiedOnSecondRun++,
      );
      expect(copiedOnSecondRun, 0);
    });

    test('unpacked data is queryable end to end', () async {
      final path = await QqlData.ensureUnpacked(into: temp);
      final qql =
          QqlHelper.open(dataDirectory: path, libraryPath: _libraryPath);
      addTearDown(qql.dispose);

      expect(qql.query('Q:112:1').single.reference, 'Al-Ikhlas 112:1');
      expect(qql.query('B:1:1').single.collection, 'Sahih al-Bukhari');
      expect(qql.query('HM:27:1').single.source, 'HM');
    },
        skip: Platform.isLinux && File(_libraryPath).existsSync()
            ? null
            : 'needs the vendored Linux build at $_libraryPath');
  });
}
