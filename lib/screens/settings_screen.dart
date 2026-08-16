import 'package:flutter/material.dart';

import '../arabic_fonts.dart';
import '../main.dart' show arabicStyle;
import '../tajweed.dart';
import '../theme_store.dart';
import '../user_lists.dart';
import 'list_backup_actions.dart';

/// App settings: appearance, the Arabic typeface, reading aids, and list
/// backup.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themeStore,
    this.userLists,
    this.arabicFonts,
  });

  final ThemeStore themeStore;

  /// Null hides the font section — used where settings is shown standalone.
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
              const _SectionHeader('Arabic font'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Applies to Arabic text only. The rest of the interface is '
                  'unchanged.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              AnimatedBuilder(
                animation: arabicFonts!,
                builder: (context, _) => RadioGroup<String>(
                  groupValue: arabicFonts!.font.id,
                  onChanged: (id) {
                    if (id != null) arabicFonts!.setFont(ArabicFont.byId(id));
                  },
                  child: Column(
                    children: [
                      for (final font in ArabicFont.all)
                        _FontOption(
                          font: font,
                          selected: font.id == arabicFonts!.font.id,
                          onTap: () => arabicFonts!.setFont(font),
                        ),
                    ],
                  ),
                ),
              ),
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

/// One typeface, previewed in itself.
///
/// A font name is not something you can judge — the preview renders the same
/// ayah in each face, so the choice is made by eye. Al-Ikhlas 112:1 is short
/// and carries a shadda, a sukun and a dammatan, which is where these faces
/// differ most.
class _FontOption extends StatelessWidget {
  const _FontOption({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  static const _sample = 'قُلْ هُوَ اللَّهُ أَحَدٌ';

  final ArabicFont font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Value is the font id; the RadioGroup ancestor holds the
            // selection, since Radio.groupValue is deprecated.
            Radio<String>(value: font.id),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(font.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected ? scheme.primary : null,
                      )),
                  if (font.note.isNotEmpty)
                    Text(font.note,
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      _sample,
                      textAlign: TextAlign.right,
                      style: arabicStyle(context, size: 26, scaled: false)
                          .copyWith(fontFamily: font.family),
                    ),
                  ),
                ],
              ),
            ),
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
