import 'package:flutter/material.dart';

import '../version.dart';

/// Who made the app, what it is built on, and which version this is.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Professional roles, in the order they were given.
  static const _roles = [
    'CTO of atB Jobs',
    'Lead Software Architect of Pounce Technology Oy',
    'CIO of Executive Insights Ltd',
    'CIO of Meghdoot Tourism',
  ];

  /// Qualifications, in the order they were given.
  static const _education = [
    'BA in Islamic Studies in IOU',
    'Dawra-e-Hadith on Qawmi Madrasa',
    'MSc in Computer Science',
  ];

  /// Bundled third-party work. QQL is GPL-3, which obliges the app to say so.
  static const _components = [
    ('QQL — Quran Query Language', 'GPL-3.0-or-later'),
    ('quran-json-arabic', 'Quran text, translation and transliteration'),
    ('hadith-json', 'The nine hadith collections'),
    ('Hisn-Muslim-Json', 'Hisnul Muslim'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.asset('assets/icon/app_icon.png',
                  width: 112, height: 112),
            ),
          ),
          const SizedBox(height: 20),
          Text('Raqi Companion',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('An open sourced helper application',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 20),
          Text('Initially contributed by',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Mazhar Ahmed',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          for (final role in _roles)
            _Line(icon: Icons.work_outline, text: role),
          const SizedBox(height: 12),
          for (final item in _education)
            _Line(icon: Icons.school_outlined, text: item),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 20),
          Text('Built on',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final (name, detail) in _components)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(detail,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Version $appVersionLabel',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
