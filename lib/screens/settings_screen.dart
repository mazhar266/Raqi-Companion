import 'package:flutter/material.dart';

import '../arabic_fonts.dart';
import '../main.dart' show arabicStyle;
import '../tajweed.dart';
import '../theme_store.dart';
import '../user_lists.dart';
import 'list_backup_actions.dart';

/// App settings: appearance, Arabic size, reading aids, and list backup.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themeStore,
    this.userLists,
    this.arabicFonts,
  });

  final ThemeStore themeStore;

  /// Null hides the Arabic size section — used where settings is shown
  /// standalone.
  final ArabicFontStore? arabicFonts;

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
            if (arabicFonts != null) ...[
              const Divider(height: 32),
              const _SectionHeader('Arabic size'),
              AnimatedBuilder(
                animation: arabicFonts!,
                builder: (context, _) => _SizeControl(store: arabicFonts!),
              ),
            ],
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

/// Scales Arabic text, with the sample rendered at the chosen size.
///
/// A multiplier rather than a point size: every screen passes its own base
/// size to `arabicStyle()`, and scaling keeps the detail view larger than the
/// session list instead of flattening them together.
class _SizeControl extends StatelessWidget {
  const _SizeControl({required this.store});

  static const _sample = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

  final ArabicFontStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (store.scale * 100).round();
    final isDefault = store.scale == ArabicFontStore.defaultScale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Arabic text only. Transliteration and translation keep '
                  'their size.',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 12),
              Text('$percent%',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary)),
            ],
          ),
        ),
        Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.text_fields, size: 16, color: scheme.onSurfaceVariant),
            Expanded(
              child: Slider(
                value: store.scale,
                min: ArabicFontStore.minScale,
                max: ArabicFontStore.maxScale,
                // 0.05 steps across the range, so the slider lands on round
                // percentages rather than 103%.
                divisions: ((ArabicFontStore.maxScale -
                            ArabicFontStore.minScale) /
                        0.05)
                    .round(),
                label: '$percent%',
                onChanged: store.setScale,
              ),
            ),
            Icon(Icons.text_fields, size: 26, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: isDefault
                  ? null
                  : () => store.setScale(ArabicFontStore.defaultScale),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Reset to 100%'),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              _sample,
              textAlign: TextAlign.right,
              // Scaled, so the preview is the real thing.
              style: arabicStyle(context),
            ),
          ),
        ),
      ],
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
