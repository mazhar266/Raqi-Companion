@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raqi_companion/version.dart';

void main() {
  test('lib/version.dart matches the version in pubspec.yaml', () {
    // The About screen shows these constants, so a bumped pubspec that forgot
    // them would ship the wrong number to users.
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere(
      (l) => l.startsWith('version:'),
      orElse: () => fail('no version: line in pubspec.yaml'),
    );
    final value = line.substring('version:'.length).trim();

    expect(value, '$appVersion+$appBuildNumber',
        reason: 'update lib/version.dart to match pubspec.yaml');
    expect(appVersionLabel, '$appVersion ($appBuildNumber)');
  });
}
