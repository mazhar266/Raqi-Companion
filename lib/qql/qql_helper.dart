/// Flutter-facing helper over the vendored QQL native library.
///
/// QQL ("Quran Query Language") resolves compact references such as
/// `Q:2:1-5,255` against the JSON data in the repository's `sources/`
/// directory. See `third_party/qql/README.md` for provenance and the
/// remaining work needed to ship it on Android.
///
/// ```dart
/// if (!QqlHelper.isSupported) return;           // web
/// final qql = QqlHelper.open(dataDirectory: dir);
/// try {
///   for (final record in qql.query('Q:112')) {
///     print('${record.reference}  ${record.arabic}');
///   }
/// } on QqlQueryException catch (e) {
///   print(e);
/// } finally {
///   qql.dispose();                              // not optional
/// }
/// ```
///
/// The implementation is selected at compile time: the real `dart:ffi`
/// binding where FFI exists, and a stub that reports
/// [QqlHelper.isSupported] as false on the web.
library;

export 'qql_helper_web.dart' if (dart.library.ffi) 'qql_helper_io.dart';
export 'qql_record.dart';
