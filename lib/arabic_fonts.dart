import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One bundled Quranic typeface.
///
/// [family] must match the `family:` declared in `pubspec.yaml`; [id] is what
/// gets stored, so renaming a family does not invalidate saved preferences.
class ArabicFont {
  const ArabicFont({
    required this.id,
    required this.family,
    required this.label,
    this.note = '',
  });

  final String id;
  final String family;
  final String label;

  /// Shown under the name in Settings — currently used to flag the marks a
  /// font cannot draw, measured by `tool/check_font_coverage.py`.
  final String note;

  /// The default. Hafs is the Madinah mushaf face and the only one of the
  /// eight that draws every *combining* mark in the bundled text — including
  /// the open tanwin forms the others drop.
  ///
  /// It does lack the ornate ayah brackets ﴿ ﴾ used in this app's multi-verse
  /// passages and the ﷺ ligature, but those are standalone glyphs: they come
  /// from a fallback face and still look right. A missing combining mark
  /// would be positioned by the fallback's metrics and land wrong, which is
  /// the failure worth avoiding.
  static const fallback = ArabicFont(
    id: 'hafs',
    family: 'Hafs',
    label: 'Hafs',
    note: 'Madinah mushaf. Every diacritic; the ﴿ ﴾ markers fall back.',
  );

  /// Offered in Settings, in this order.
  static const all = <ArabicFont>[
    fallback,
    ArabicFont(
      id: 'al-majeed',
      family: 'AlMajeed',
      label: 'Al Majeed',
      note: 'Indo-Pak style. Missing the open dammatan.',
    ),
    ArabicFont(
      id: 'al-qalam',
      family: 'AlQalam',
      label: 'Al Qalam',
      note: 'Indo-Pak style. Missing the open dammatan.',
    ),
    ArabicFont(
      id: 'pdms-saleem',
      family: 'PdmsSaleem',
      label: 'PDMS Saleem',
      note: 'Indo-Pak, heavier stroke. Missing the open dammatan.',
    ),
    ArabicFont(
      id: 'muhammadi',
      family: 'Muhammadi',
      label: 'Muhammadi',
      note: 'Naskh, wide counters. Missing the open dammatan.',
    ),
    ArabicFont(
      id: 'al-mushaf',
      family: 'AlMushaf',
      label: 'Al Mushaf',
      note: 'Missing the open dammatan and the small waw.',
    ),
    ArabicFont(
      id: 'nabi',
      family: 'Nabi',
      label: 'Nabi',
      note: 'Missing the open fathatan and dammatan.',
    ),
    ArabicFont(
      id: 'neirizi',
      family: 'Neirizi',
      label: 'Neirizi',
      note: 'Missing the open fathatan and dammatan.',
    ),
  ];

  static ArabicFont byId(String? id) {
    for (final font in all) {
      if (font.id == id) return font;
    }
    return fallback;
  }
}

/// The chosen Arabic typeface and its size, persisted under `'arabicFont'`
/// and `'arabicFontScale'`.
///
/// Affects Arabic text only — every string rendered through `arabicText()`.
/// The interface font and size are untouched.
class ArabicFontStore extends ChangeNotifier {
  static const _fontKey = 'arabicFont';
  static const _scaleKey = 'arabicFontScale';

  /// The size is a multiplier, not a point size: call sites already pass
  /// their own base (26 in the detail view, 16 in the session list), and
  /// scaling preserves that hierarchy instead of flattening it.
  static const minScale = 0.8;
  static const maxScale = 2.0;
  static const defaultScale = 1.0;

  ArabicFont _font = ArabicFont.fallback;
  double _scale = defaultScale;
  bool _loaded = false;

  ArabicFont get font => _font;
  double get scale => _scale;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _font = ArabicFont.byId(prefs.getString(_fontKey));
    _scale = _clamp(prefs.getDouble(_scaleKey) ?? defaultScale);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setFont(ArabicFont font) async {
    if (font.id == _font.id) return;
    _font = font;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontKey, font.id);
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

/// Publishes the chosen family and size to `arabicStyle()`.
///
/// An inherited widget rather than parameters on `arabicText()`: the style
/// helper is called from a dozen places, and threading these through all of
/// them would put the settings in every widget's constructor.
class ArabicFontScope extends InheritedWidget {
  const ArabicFontScope({
    super.key,
    required this.font,
    required this.scale,
    required super.child,
  });

  final ArabicFont font;
  final double scale;

  static ArabicFontScope? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ArabicFontScope>();

  /// Falls back to the default face outside a scope, so widgets built in
  /// isolation — tests, previews — still render.
  static ArabicFont fontOf(BuildContext context) =>
      _of(context)?.font ?? ArabicFont.fallback;

  static double scaleOf(BuildContext context) =>
      _of(context)?.scale ?? ArabicFontStore.defaultScale;

  @override
  bool updateShouldNotify(ArabicFontScope oldWidget) =>
      oldWidget.font.id != font.id || oldWidget.scale != scale;
}
