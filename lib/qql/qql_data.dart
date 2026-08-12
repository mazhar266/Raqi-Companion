import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Unpacks the bundled QQL data from Flutter's asset bundle onto the real
/// filesystem.
///
/// The native library reads its JSON with `std::fs` and cannot see the asset
/// bundle, so the files have to exist as actual files before any query runs.
/// This copies them once and remembers it with a marker file.
///
/// Not usable on web: there is no filesystem and no FFI consumer for the
/// result. Guard with `QqlHelper.isSupported`.
class QqlData {
  QqlData._();

  /// Prefix of the bundled assets, and the layout QQL's resolvers expect.
  /// Paths under this must be preserved exactly.
  static const assetPrefix = 'sources/';

  /// Bump to force a re-unpack after the bundled data changes.
  static const dataVersion = '1';

  static const _markerName = '.qql-data-version';

  static String? _cached;

  /// Unpack if needed and return the directory to hand to `QqlHelper.open`.
  ///
  /// Subsequent calls in the same process return the cached path without
  /// touching the disk. [onProgress] reports `(copied, total)` while files are
  /// being written; it is not called when the data is already present.
  ///
  /// [into] overrides the destination and bypasses the cache — for tests, so
  /// they need no `path_provider` plugin mock.
  static Future<String> ensureUnpacked({
    void Function(int copied, int total)? onProgress,
    Directory? into,
  }) async {
    if (into == null) {
      final cached = _cached;
      if (cached != null) return cached;
    }

    final root = into ??
        Directory('${(await getApplicationSupportDirectory()).path}/qql');
    final marker = File('${root.path}/$_markerName');

    if (await marker.exists() && await marker.readAsString() == dataVersion) {
      return into == null ? _cached = root.path : root.path;
    }

    // A partial unpack from an interrupted first launch would leave QQL
    // reading truncated data, so start clean.
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    await root.create(recursive: true);

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest
        .listAssets()
        .where((key) => key.startsWith(assetPrefix))
        .toList()
      ..sort();

    if (assets.isEmpty) {
      throw StateError(
        'No QQL data assets found. Check the "sources/" entries under '
        'flutter.assets in pubspec.yaml — asset directories are not recursive.',
      );
    }

    var copied = 0;
    for (final key in assets) {
      // Keep the path below assetPrefix intact: the resolvers hard-code it.
      final destination = File('${root.path}/${key.substring(assetPrefix.length)}');
      await destination.parent.create(recursive: true);
      final bytes = await rootBundle.load(key);
      await destination.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: false,
      );
      onProgress?.call(++copied, assets.length);
    }

    // Written last, so an interrupted run is not mistaken for a complete one.
    await marker.writeAsString(dataVersion, flush: true);
    return into == null ? _cached = root.path : root.path;
  }

  /// Forget the cached path. For tests.
  static void resetForTesting() => _cached = null;
}
