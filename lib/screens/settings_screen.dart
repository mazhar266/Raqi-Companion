import 'package:flutter/material.dart';

import '../tajweed.dart';
import '../theme_store.dart';

/// App settings. Appearance today; the sections are here so more can be added
/// without another navigation level.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.themeStore});

  final ThemeStore themeStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AnimatedBuilder(
        animation: themeStore,
        builder: (context, _) => ListView(
          children: [
            const _SectionHeader('Appearance'),
            RadioGroup<ThemeMode>(
              groupValue: themeStore.mode,
              onChanged: (mode) {
                if (mode != null) themeStore.setMode(mode);
              },
              child: Column(
                children: [
                  for (final mode in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      value: mode,
                      title: Text(mode.label),
                      subtitle: mode == ThemeMode.system
                          ? const Text('Follow the device setting')
                          : null,
                      secondary: Icon(mode.icon),
                    ),
                ],
              ),
            ),
            const Divider(height: 32),
            const _SectionHeader('Reading'),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Tajweed colours'),
              subtitle: const Text('What each colour in the Arabic means'),
              onTap: () => showTajweedLegend(context),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
