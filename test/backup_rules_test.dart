@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/qql/qql_data.dart';

/// Android Auto Backup copies the app's internal storage to the user's Google
/// Drive, with a 25 MB per-app quota. The unpacked QQL data is ~150 MB, so it
/// has to be excluded or the whole backup fails — taking the bookmarks, the
/// appearance setting and the user's lists with it.
///
/// These are string paths in XML that nothing else checks, so a rename of
/// [QqlData.directoryName] would break the exclusion silently. This test is
/// the link between the two.
void main() {
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const legacyRules = 'android/app/src/main/res/xml/backup_rules.xml';
  const modernRules =
      'android/app/src/main/res/xml/data_extraction_rules.xml';

  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    return file.readAsStringSync();
  }

  test('the manifest points at both rule files', () {
    final manifest = read(manifestPath);
    // fullBackupContent covers API 30 and below, dataExtractionRules 31+.
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    expect(manifest, contains('android:allowBackup="true"'));
  });

  test('both rule files exclude the directory QQL actually unpacks into', () {
    const expected = 'path="${QqlData.directoryName}/"';

    for (final path in [legacyRules, modernRules]) {
      final rules = read(path);
      expect(rules, contains(expected),
          reason: '$path does not exclude ${QqlData.directoryName}/ — '
              'the unpacked data would break Auto Backup');
      expect(rules, contains('domain="file"'),
          reason: '$path must scope the exclusion to internal files');
    }
  });

  test('the modern rules cover cloud backup and device transfer', () {
    final rules = read(modernRules);
    for (final section in ['cloud-backup', 'device-transfer']) {
      expect(rules, contains('<$section>'), reason: 'missing <$section>');
    }
    // One exclusion in each section.
    expect('path="${QqlData.directoryName}/"'.allMatches(rules), hasLength(2));
  });

  test('shared_preferences is not excluded — it holds what we want backed up',
      () {
    for (final path in [legacyRules, modernRules]) {
      final rules = read(path);
      expect(rules, isNot(contains('domain="sharedpref"')),
          reason: '$path excludes shared_preferences, which holds the '
              'bookmarks, appearance setting and user lists');
    }
  });
}
