import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Arabic typeface, declared in `pubspec.yaml`.
///
/// One face rather than a choice. Hafs is the Madinah mushaf style and the
/// only one of the candidates tried that draws every *combining* mark the app
/// renders — the open tanwin forms in particular, which most Arabic faces
/// lack and which a fallback font would misposition. Run
/// `tool/check_font_coverage.py` before ever swapping it.
const arabicFontFamily = 'Hafs';

/// The size of Arabic text, persisted under `'arabicFontScale'`.
///
/// Affects Arabic only — every string rendered through `arabicText()`. The
/// interface font and size are untouched.
class ArabicFontStore extends ChangeNotifier {
  static const _scaleKey = 'arabicFontScale';

  /// A multiplier, not a point size: call sites already pass their own base
  /// (26 in the detail view, 16 in the session list), and scaling preserves
  /// that hierarchy instead of flattening it.
  static const minScale = 0.8;
  static const maxScale = 2.0;
  static const defaultScale = 1.0;

  double _scale = defaultScale;
  bool _loaded = false;

  double get scale => _scale;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _scale = _clamp(prefs.getDouble(_scaleKey) ?? defaultScale);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setScale(double scale) async {
    final next = _clamp(scale);
    if (next == _scale) return;
    _scale = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_scaleKey, next);
  }

  /// Guards against a hand-edited or corrupt preference making the text
  /// unreadably small or large.
  static double _clamp(double value) {
    if (value.isNaN) return defaultScale;
    return value.clamp(minScale, maxScale);
  }
}

/// Publishes the chosen size to `arabicStyle()`.
///
/// An inherited widget rather than a parameter on `arabicText()`: the style
/// helper is called from a dozen places, and threading the size through all
/// of them would put the setting in every widget's constructor.
class ArabicFontScope extends InheritedWidget {
  const ArabicFontScope({
    super.key,
    required this.scale,
    required super.child,
  });

  final double scale;

  /// Falls back to the default outside a scope, so widgets built in
  /// isolation — tests, previews — still render.
  static double scaleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ArabicFontScope>()?.scale ??
      ArabicFontStore.defaultScale;

  @override
  bool updateShouldNotify(ArabicFontScope oldWidget) =>
      oldWidget.scale != scale;
}
