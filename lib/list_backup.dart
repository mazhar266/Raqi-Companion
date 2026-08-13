import 'dart:convert';

import 'user_lists.dart';

/// Thrown when a file does not hold a readable Raqi Companion list backup.
///
/// The message is shown to the user, so it says what is wrong with the file
/// rather than naming a Dart type.
class ListBackupException implements Exception {
  const ListBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One list as it appears in a backup: a name and its references, nothing
/// resolved. Ids are not carried — they are reassigned on import so a file
/// restored onto another device cannot collide with what is already there.
typedef BackupList = ({String name, List<String> queries});

/// Marker fields, so a JSON file that is not one of ours fails with a useful
/// message instead of a type error deep in the decoder.
const _app = 'raqi_companion';
const _type = 'lists';

/// Bump only for a breaking change to the shape below. [decodeBackup] accepts
/// anything at or below this.
const backupFormatVersion = 1;

/// Serialises [lists] to the backup format: references only, no Arabic,
/// translations or any other resolved content.
String encodeBackup(List<UserList> lists, {DateTime? exportedAt}) {
  final payload = <String, dynamic>{
    'app': _app,
    'type': _type,
    'version': backupFormatVersion,
    'exported': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'lists': [
      for (final list in lists)
        {'name': list.name, 'queries': list.queries},
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

/// Parses a backup file.
///
/// Throws [ListBackupException] for anything unreadable; never returns
/// partially valid data, so an import either applies wholly or not at all.
List<BackupList> decodeBackup(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    return throw const ListBackupException('That file is not valid JSON.');
  }

  if (decoded is! Map<String, dynamic>) {
    throw const ListBackupException(
        'That file does not look like a Raqi Companion backup.');
  }
  if (decoded['type'] != _type) {
    throw const ListBackupException(
        'That file is not a list backup from Raqi Companion.');
  }

  final version = decoded['version'];
  if (version is! int || version > backupFormatVersion) {
    throw ListBackupException(
        'That backup was written by a newer version of the app '
        '(format $version, this build reads $backupFormatVersion).');
  }

  final rawLists = decoded['lists'];
  if (rawLists is! List) {
    throw const ListBackupException('That backup has no lists in it.');
  }

  final out = <BackupList>[];
  for (final raw in rawLists) {
    if (raw is! Map<String, dynamic>) {
      throw const ListBackupException('One of the lists is malformed.');
    }
    final name = raw['name'];
    final queries = raw['queries'];
    if (name is! String || name.trim().isEmpty) {
      throw const ListBackupException('One of the lists has no name.');
    }
    if (queries is! List || queries.any((q) => q is! String)) {
      throw ListBackupException('The entries of "$name" are malformed.');
    }
    out.add((
      name: name.trim(),
      queries: [
        for (final q in queries.cast<String>())
          if (q.trim().isNotEmpty) q.trim()
      ],
    ));
  }
  return out;
}

/// Default file name for an export, e.g. `raqi-lists-2026-08-13.json`.
String backupFileName({DateTime? now}) {
  final d = (now ?? DateTime.now());
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return 'raqi-lists-${d.year}-$month-$day.json';
}
