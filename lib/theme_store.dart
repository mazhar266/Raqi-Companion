import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's theme mode, persisted locally across launches.
///
/// Defaults to [ThemeMode.system], so the app follows the device setting until
/// the user picks light or dark explicitly. An explicit choice is remembered
/// and keeps overriding the system setting until it is changed again or set
/// back to [ThemeMode.system].
class ThemeStore extends ChangeNotifier {
  static const _key = 'themeMode';

  ThemeMode _mode = ThemeMode.system;
  bool _loaded = false;

  ThemeMode get mode => _mode;

  /// False until [load] has finished; the app shows a spinner until then so it
  /// never flashes the wrong theme on launch.
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = _parse(prefs.getString(_key));
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Falls back to [ThemeMode.system] for a missing or unrecognised value.
  static ThemeMode _parse(String? value) {
    for (final mode in ThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return ThemeMode.system;
  }
}

/// Label and icon shown for each mode in the picker.
extension ThemeModeDisplay on ThemeMode {
  String get label {
    switch (this) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  IconData get icon {
    switch (this) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }
}
