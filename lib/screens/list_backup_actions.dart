import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../list_backup.dart';
import '../user_lists.dart';

/// Writes every list to a JSON file the user chooses.
///
/// The file holds names and QQL references only — no Arabic, translations or
/// other resolved content — so it stays small and survives a data update.
Future<void> exportLists(BuildContext context, UserListStore store) async {
  final messenger = ScaffoldMessenger.of(context);
  final json = encodeBackup(store.lists);
  final bytes = utf8.encode(json);

  try {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export lists',
      fileName: backupFileName(),
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
    if (path == null) return; // cancelled

    // Mobile and web have already written the bytes by this point; the
    // desktop implementations only return the chosen path.
    if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    messenger.showSnackBar(SnackBar(
      content: Text('Exported ${store.lists.length} '
          'list${store.lists.length == 1 ? '' : 's'}'),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

/// Reads lists back from a file, after asking whether to merge or replace.
Future<void> importLists(BuildContext context, UserListStore store) async {
  final messenger = ScaffoldMessenger.of(context);

  final String contents;
  try {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Restore lists',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (result == null || result.files.isEmpty) return; // cancelled

    // readAsBytes() rather than .bytes: it works whichever way the platform
    // handed the file over, and does not need withData up front.
    contents = utf8.decode(await result.files.single.readAsBytes());
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open file: $e')));
    return;
  }

  final List<BackupList> incoming;
  try {
    incoming = decodeBackup(contents);
  } on ListBackupException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }

  if (incoming.isEmpty) {
    messenger.showSnackBar(
        const SnackBar(content: Text('That backup contains no lists.')));
    return;
  }

  if (!context.mounted) return;
  final replace = await _askReplace(context, incoming.length, store);
  if (replace == null) return; // cancelled

  final added = await store.importLists(incoming, replace: replace);
  messenger.showSnackBar(SnackBar(
    content: Text(replace
        ? 'Replaced with $added list${added == 1 ? '' : 's'}'
        : 'Added $added list${added == 1 ? '' : 's'}'),
  ));
}

/// Null if cancelled, true to replace, false to merge.
///
/// Replacing discards existing lists, so it is never the default.
Future<bool?> _askReplace(
    BuildContext context, int incoming, UserListStore store) {
  final existing = store.lists.length;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Restore $incoming list${incoming == 1 ? '' : 's'}?'),
      content: Text(existing == 0
          ? 'They will be added to this device.'
          : 'You have $existing list${existing == 1 ? '' : 's'} already. '
              'Add the restored ones alongside them, or replace everything?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        if (existing > 0)
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace all'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(existing == 0 ? 'Restore' : 'Add'),
        ),
      ],
    ),
  );
}
