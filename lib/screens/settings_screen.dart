import 'package:flutter/material.dart';

import '../tajweed.dart';
import '../theme_store.dart';
import '../user_lists.dart';
import 'list_backup_actions.dart';

/// App settings: appearance, reading aids, and list backup.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themeStore,
    this.userLists,
  });

  final ThemeStore themeStore;

  /// Null hides the backup section — used where settings is shown without the
  /// rest of the app around it.
  final UserListStore? userLists;

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
            if (userLists != null) ...[
              const Divider(height: 32),
              const _SectionHeader('Your lists'),
              AnimatedBuilder(
                animation: userLists!,
                builder: (context, _) {
                  final count = userLists!.lists.length;
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.upload_file_outlined),
                        title: const Text('Export to a file'),
                        subtitle: Text(count == 0
                            ? 'Nothing to export yet'
                            : 'Saves the $count list${count == 1 ? '' : 's'} '
                                'as JSON — references only, no text'),
                        enabled: count > 0,
                        onTap: () => exportLists(context, userLists!),
                      ),
                      ListTile(
                        leading: const Icon(Icons.restore_page_outlined),
                        title: const Text('Restore from a file'),
                        subtitle:
                            const Text('Read lists back from an exported JSON'),
                        onTap: () => importLists(context, userLists!),
                      ),
                    ],
                  );
                },
              ),
            ],
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
