import 'package:flutter/material.dart';

import 'bookmarks.dart';
import 'data_service.dart';
import 'models.dart';
import 'screens/home_shell.dart';
import 'theme_store.dart';

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
  late final Future<List<Category>> future;

  @override
  void initState() {
    super.initState();
    future = DataService.loadCategories();
    bookmarks.load();
    themeStore.load();
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
      animation: Listenable.merge([bookmarks, themeStore]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Raqi Companion',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: themeStore.mode,
          home: FutureBuilder<List<Category>>(
            future: future,
            builder: (context, snapshot) {
              if (!snapshot.hasData || !bookmarks.loaded || !themeStore.loaded) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return HomeShell(
                categories: snapshot.data!,
                bookmarks: bookmarks,
                themeStore: themeStore,
              );
            },
          ),
        );
      },
    );
  }
}

/// Shared Arabic text style used across screens.
TextStyle arabicStyle(BuildContext context, {double size = 26}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return TextStyle(
    fontSize: size,
    height: 1.8,
    fontFamilyFallback: const ['Amiri', 'Scheherazade New', 'serif'],
    color: dark ? const Color(0xFFEDE6DA) : const Color(0xFF3B332A),
  );
}
