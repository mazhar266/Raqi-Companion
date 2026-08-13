import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../surahs.dart';

/// Asks for a QQL reference, either typed or assembled from dropdowns.
///
/// Returns the query string, or null if dismissed. Purely a builder — it does
/// not run the query, so it works before QQL is ready and on the web.
Future<String?> showAddEntrySheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: const _AddEntrySheet(),
    ),
  );
}

class _AddEntrySheet extends StatefulWidget {
  const _AddEntrySheet();

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

enum _Mode { picker, typed }

class _AddEntrySheetState extends State<_AddEntrySheet> {
  _Mode _mode = _Mode.picker;

  // Typed mode.
  final _typed = TextEditingController();

  // Picker mode.
  QqlSource _source = QqlSource.all.first;
  bool _bookWide = false;
  int _surah = 1;
  final _chapter = TextEditingController(text: '1');
  final _from = TextEditingController();
  final _to = TextEditingController();

  List<Surah>? _surahs;

  @override
  void initState() {
    super.initState();
    Surahs.load().then((s) {
      if (mounted) setState(() => _surahs = s);
    });
  }

  @override
  void dispose() {
    _typed.dispose();
    _chapter.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Surah? get _currentSurah {
    final all = _surahs;
    if (all == null) return null;
    for (final s in all) {
      if (s.number == _surah) return s;
    }
    return null;
  }

  int? _parse(TextEditingController c) => int.tryParse(c.text.trim());

  String get _built => buildQuery(
        source: _source.code,
        bookWide: _bookWide,
        primary: _source.isQuran ? _surah : _parse(_chapter),
        from: _parse(_from),
        to: _parse(_to),
      );

  /// The upper bound for the range fields, where one is known.
  int? get _limit {
    if (_bookWide || !_source.isQuran) return null;
    return _currentSurah?.verses;
  }

  String? get _rangeError {
    final from = _parse(_from);
    final to = _parse(_to);
    final limit = _limit;
    if (from != null && from < 1) return 'Start at 1 or more';
    if (from != null && limit != null && from > limit) {
      return '${_currentSurah!.transliteration} has $limit ayat';
    }
    if (to != null && limit != null && to > limit) {
      return '${_currentSurah!.transliteration} has $limit ayat';
    }
    if (from != null && to != null && to < from) return 'End before start';
    return null;
  }

  void _submit(String query) {
    if (query.trim().isEmpty) return;
    Navigator.of(context).pop(query.trim());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add to list',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<_Mode>(
              segments: const [
                ButtonSegment(
                    value: _Mode.picker,
                    label: Text('Choose'),
                    icon: Icon(Icons.list_alt_outlined)),
                ButtonSegment(
                    value: _Mode.typed,
                    label: Text('Type'),
                    icon: Icon(Icons.keyboard_outlined)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            if (_mode == _Mode.typed) ..._typedFields() else ..._pickerFields(),
          ],
        ),
      ),
    );
  }

  List<Widget> _typedFields() => [
        TextField(
          controller: _typed,
          autofocus: true,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
          decoration: const InputDecoration(
            labelText: 'QQL reference',
            hintText: 'Q:2:1-5,255',
            helperText: 'Commas and ranges are allowed. Use :: to number '
                'across the whole book, e.g. B::6018.',
            helperMaxLines: 3,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _submit(_typed.text),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Add'),
          ),
        ),
      ];

  List<Widget> _pickerFields() {
    final error = _rangeError;
    return [
      DropdownButtonFormField<QqlSource>(
        initialValue: _source,
        decoration: const InputDecoration(
            labelText: 'Source', border: OutlineInputBorder(), isDense: true),
        items: [
          for (final s in QqlSource.all)
            DropdownMenuItem(value: s, child: Text('${s.code} · ${s.name}'))
        ],
        onChanged: (s) => setState(() => _source = s ?? _source),
      ),
      const SizedBox(height: 12),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _bookWide,
        onChanged: (v) => setState(() => _bookWide = v),
        title: const Text('Number across the whole book'),
        subtitle: Text(_bookWide
            ? 'Continuous numbering, as citations use'
            : 'Counting within a ${_source.isQuran ? 'surah' : 'chapter'}'),
      ),
      if (!_bookWide) ...[
        const SizedBox(height: 4),
        if (_source.isQuran)
          DropdownButtonFormField<int>(
            initialValue: _surah,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Surah',
                border: OutlineInputBorder(),
                isDense: true),
            items: [
              for (final s in _surahs ?? const <Surah>[])
                DropdownMenuItem(
                  value: s.number,
                  child: Text('${s.label}  ·  ${s.verses} ayat',
                      overflow: TextOverflow.ellipsis),
                )
            ],
            onChanged: (v) => setState(() => _surah = v ?? _surah),
          )
        else
          TextField(
            controller: _chapter,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'Chapter',
                border: OutlineInputBorder(),
                isDense: true),
          ),
      ],
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _from,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'From',
                hintText: _limit == null ? 'all' : '1',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _to,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'To',
                hintText: _limit?.toString() ?? 'optional',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        error ?? 'Leave both blank to take everything.',
        style: TextStyle(
          fontSize: 12,
          color: error == null
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.error,
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.terminal, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_built,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 15)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: error == null ? () => _submit(_built) : null,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Add'),
        ),
      ),
    ];
  }
}
