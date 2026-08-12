/// `dart:ffi` implementation of [QqlHelper], used on every platform that has
/// FFI. The web gets `qql_helper_web.dart` instead; do not import this file
/// directly, import `qql_helper.dart`.
library;

import 'qql_record.dart';
import 'vendor/qql.dart' as vendor;

/// Wraps the vendored QQL binding in the shape this app wants: typed
/// [QqlRecord]s and a single exception type that does not leak the vendored
/// classes.
class QqlHelper {
  QqlHelper._(this._qql);

  final vendor.Qql _qql;

  /// True on this platform — FFI is available.
  static bool get isSupported => true;

  /// Open a context reading data from [dataDirectory].
  ///
  /// [dataDirectory] must be a real filesystem path: the native library reads
  /// the JSON with `std::fs`, so a Flutter asset path will not work. On
  /// Android the data has to be unpacked to app storage first.
  ///
  /// [libraryPath] defaults to the platform's usual name (`libqql.so` on
  /// Linux and Android), which resolves against the system search path and
  /// the APK's bundled libraries. Pass an explicit path to load a specific
  /// build — for example the checked-in
  /// `third_party/qql/native/linux-x64/libqql.so` when running tests.
  ///
  /// Throws [QqlQueryException] if the context cannot be created, or
  /// [ArgumentError] if the native library itself cannot be loaded.
  factory QqlHelper.open({
    required String dataDirectory,
    String? libraryPath,
  }) {
    try {
      return QqlHelper._(
        vendor.Qql.open(dataDirectory, libraryPath: libraryPath),
      );
    } on vendor.QqlException catch (e) {
      throw QqlQueryException(e.code, e.message, e.position);
    }
  }

  /// Native library version, e.g. `0.1.0`.
  String get version => _qql.version;

  /// Run [query] and return the resolved records.
  ///
  /// Throws [QqlQueryException] for a malformed or unresolvable query.
  List<QqlRecord> query(String query) {
    try {
      return _qql
          .execute(query)
          .map(QqlRecord.fromJson)
          .toList(growable: false);
    } on vendor.QqlException catch (e) {
      throw QqlQueryException(e.code, e.message, e.position);
    }
  }

  /// Run [query] and return the raw JSON response.
  ///
  /// Never throws for a bad query — failures arrive as `{"ok": false, ...}`.
  String queryJson(String query) => _qql.executeJson(query);

  /// Release the native context.
  ///
  /// Not optional: Dart's GC does not know about the Rust allocation behind
  /// it and there is no finalizer. Safe to call more than once.
  void dispose() => _qql.dispose();
}
