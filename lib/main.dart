import 'package:flutter/material.dart';

import 'arabic_fonts.dart';
import 'bookmarks.dart';
import 'data_service.dart';
import 'models.dart';
import 'screens/home_shell.dart';
import 'theme_store.dart';
import 'user_lists.dart';

void main() {
  runApp(const RuqyahApp());
}

class RuqyahApp extends StatefulWidget {
  const RuqyahApp({super.key});

  @override
  State<RuqyahApp> createState() => _RuqyahAppState();
}

class _RuqyahAppState extends State<RuqyahApp> {
  final BookmarkStore bookmarks = BookmarkStore();
  final ThemeStore themeStore = ThemeStore();
  final UserListStore userLists = UserListStore();
  final ArabicFontStore arabicFonts = ArabicFontStore();
  late final Future<List<Category>> future;

  @override
  void initState() {
    super.initState();
    future = DataService.loadCategories();
    bookmarks.load();
    themeStore.load();
    userLists.load();
    arabicFonts.load();
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6B5D4F),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFFAF7F2)
          : const Color(0xFF1C1A17),
      appBarTheme: const AppBarTheme(centerTitle: true),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([bookmarks, themeStore, userLists, arabicFonts]),
      builder: (context, _) {
        // Above MaterialApp so every route, dialog and sheet inherits it.
        return ArabicFontScope(
          font: arabicFonts.font,
          scale: arabicFonts.scale,
          child: MaterialApp(
          title: 'Raqi Companion',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: themeStore.mode,
          home: FutureBuilder<List<Category>>(
            future: future,
            builder: (context, snapshot) {
              if (!snapshot.hasData || !bookmarks.loaded || !themeStore.loaded || !userLists.loaded ||
                  !arabicFonts.loaded) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return HomeShell(
                categories: snapshot.data!,
                bookmarks: bookmarks,
                themeStore: themeStore,
                userLists: userLists,
                arabicFonts: arabicFonts,
              );
            },
            ),
          ),
        );
      },
    );
  }
}

/// Shared Arabic text style used across screens.
///
/// The family and size both come from [ArabicFontScope], so the Settings
/// choices reach every Arabic string without being threaded through each
/// widget. [size] is the call site's own base — the setting scales it, which
/// keeps the relative sizes across screens intact. The fallbacks only catch
/// codepoints the chosen face lacks; see `tool/check_font_coverage.py`.
///
/// Pass `scaled: false` to ignore the size setting, which the font previews
/// in Settings do so the list stays scannable at any scale.
TextStyle arabicStyle(
  BuildContext context, {
  double size = 26,
  bool scaled = true,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final scale = scaled ? ArabicFontScope.scaleOf(context) : 1.0;
  return TextStyle(
    fontSize: size * scale,
    height: 1.8,
    fontFamily: ArabicFontScope.fontOf(context).family,
    fontFamilyFallback: const ['Hafs', 'Amiri', 'Scheherazade New', 'serif'],
    color: dark ? const Color(0xFFEDE6DA) : const Color(0xFF3B332A),
  );
}
