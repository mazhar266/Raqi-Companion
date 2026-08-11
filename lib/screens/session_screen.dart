import 'package:flutter/material.dart';

import '../models.dart';
import '../tajweed.dart';

class SessionScreen extends StatefulWidget {
  final List<Category> categories;

  const SessionScreen({super.key, required this.categories});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final Set<String> _done = {};

  List<RuqyahItem> get _all =>
      [for (final c in widget.categories) ...c.items];

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final progress = all.isEmpty ? 0.0 : _done.length / all.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruqyah Session'),
        actions: [
          IconButton(
            tooltip: 'Reset session',
            icon: const Icon(Icons.restart_alt),
            onPressed: () => setState(_done.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${_done.length} / ${all.length} completed',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final category in widget.categories) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(category.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  ...category.items.map((item) {
                    final checked = _done.contains(item.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: CheckboxListTile(
                        value: checked,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _done.add(item.id);
                          } else {
                            _done.remove(item.id);
                          }
                        }),
                        title: Text(item.reference),
                        subtitle: arabicText(context, item.arabic,
                            size: 16, maxLines: 1),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
