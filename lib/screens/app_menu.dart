import 'package:flutter/material.dart';

import '../theme_store.dart';
import 'about_screen.dart';
import 'settings_screen.dart';

/// The overflow menu in the top-right of every tab.
///
/// Each tab keeps its own `Scaffold` and app bar, so this is a shared widget
/// rather than one menu on a shared bar.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key, required this.themeStore});

  final ThemeStore themeStore;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => value == 'settings'
              ? SettingsScreen(themeStore: themeStore)
              : const AboutScreen(),
        ));
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
          ),
        ),
        PopupMenuItem(
          value: 'about',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline),
            title: Text('About'),
          ),
        ),
      ],
    );
  }
}
