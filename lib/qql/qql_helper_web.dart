/// Web stub for [QqlHelper].
///
/// QQL is a native library reached through `dart:ffi`, which does not exist on
/// the web, and it reads its JSON data from the filesystem, which a browser
/// does not have either. This stub keeps the app compiling for web: the API is
/// identical, [QqlHelper.isSupported] is false, and every call throws.
///
/// Guard call sites with [QqlHelper.isSupported] rather than catching. Do not
/// import this file directly, import `qql_helper.dart`.
library;

import 'qql_record.dart';

class QqlHelper {
  /// False on the web — `dart:ffi` is unavailable.
  static bool get isSupported => false;

  factory QqlHelper.open({
    required String dataDirectory,
    String? libraryPath,
  }) =>
      throw _unsupported();

  String get version => throw _unsupported();

  List<QqlRecord> query(String query) => throw _unsupported();

  String queryJson(String query) => throw _unsupported();

  /// No-op: no instance can exist on this platform.
  void dispose() {}
}

UnsupportedError _unsupported() => UnsupportedError(
      'QQL is unavailable on the web: it needs dart:ffi and filesystem access. '
      'Guard call sites with QqlHelper.isSupported.',
    );
