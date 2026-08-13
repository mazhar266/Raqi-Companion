import 'package:flutter/material.dart';

import '../qql/qql_data.dart';
import '../qql/qql_helper.dart';
import '../tajweed.dart';
import '../theme_store.dart';
import '../user_lists.dart';
import 'app_menu.dart';

/// Runs a QQL query and shows the resolved records.
///
/// QQL references look like `Q:2:1-5,255` — source, primary index, then an
/// optional selector. See third_party/qql/README.md for the full grammar.
class QqlQueryScreen extends StatefulWidget {
  const QqlQueryScreen({
    super.key,
    required this.themeStore,
    required this.userLists,
  });

  final ThemeStore themeStore;
  final UserListStore userLists;

  @override
  State<QqlQueryScreen> createState() => _QqlQueryScreenState();
}

enum _Stage { preparing, ready, unsupported, failed }

class _QqlQueryScreenState extends State<QqlQueryScreen> {
  // A mix of the chapter form and the flat book-wide form (SOURCE::n).
  static const _examples = [
    'Q:2:255',
    'Q:112',
    'Q:2:1-5,255',
    'HM:27:1-3',
    'B:1:1',
    'B::6018',
    'Q::100',
  ];

  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  _Stage _stage = _Stage.preparing;
  String _prepareMessage = 'Preparing data…';
  String? _prepareError;

  QqlHelper? _qql;
  List<QqlRecord>? _records;
  QqlQueryException? _queryError;

  @override
  void initState() {
    super.initState();
    if (!QqlHelper.isSupported) {
      _stage = _Stage.unsupported;
    } else {
      _prepare();
    }
  }

  @override
  void dispose() {
    _qql?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final directory = await QqlData.ensureUnpacked(
        onProgress: (copied, total) {
          if (!mounted) return;
          setState(() => _prepareMessage = 'Unpacking data… $copied / $total');
        },
      );
      final helper = QqlHelper.open(dataDirectory: directory);
      if (!mounted) {
        helper.dispose();
        return;
      }
      setState(() {
        _qql = helper;
        _stage = _Stage.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _prepareError = '$e';
        _stage = _Stage.failed;
      });
    }
  }

  void _run([String? value]) {
    final query = (value ?? _controller.text).trim();
    final qql = _qql;
    if (query.isEmpty || qql == null) return;

    FocusScope.of(context).unfocus();
    setState(() {
      try {
        _records = qql.query(query);
        _queryError = null;
      } on QqlQueryException catch (e) {
        _records = null;
        _queryError = e;
      }
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _useExample(String example) {
    _controller.text = example;
    _run(example);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Query'),
        actions: [
          AppMenuButton(
              themeStore: widget.themeStore, userLists: widget.userLists)
        ],
      ),
      body: switch (_stage) {
        _Stage.unsupported => const _Notice(
            icon: Icons.web_asset_off_outlined,
            title: 'Not available on the web',
            detail: 'QQL is a native library reached through dart:ffi, which '
                'the browser does not have. Run the app on Android to use it.',
          ),
        _Stage.failed => _Notice(
            icon: Icons.error_outline,
            title: 'Could not start QQL',
            detail: _prepareError ?? 'Unknown error.',
          ),
        _Stage.preparing => _Notice(
            icon: Icons.hourglass_empty,
            title: _prepareMessage,
            detail: 'The data is copied out of the app bundle once, on first '
                'launch, so the native library can read it.',
            busy: true,
          ),
        _Stage.ready => _buildReady(context),
      },
    );
  }

  Widget _buildReady(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autocorrect: false,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _run,
                      decoration: const InputDecoration(
                        labelText: 'QQL query',
                        hintText: 'Q:2:1-5,255',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _run,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Run'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: _examples
                    .map((e) => ActionChip(
                          label: Text(e, style: const TextStyle(fontSize: 12)),
                          onPressed: () => _useExample(e),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildResults(context)),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final error = _queryError;
    if (error != null) {
      return _Notice(
        icon: Icons.report_gmailerrorred_outlined,
        title: error.code,
        detail: error.position == null
            ? error.message
            : '${error.message} (at position ${error.position})',
      );
    }

    final records = _records;
    if (records == null) {
      return const _Notice(
        icon: Icons.search,
        title: 'Enter a query',
        detail: 'source : primary : selector — for example Q:2:1-5,255 for '
            'Surah 2 ayat 1 to 5 plus ayah 255. Double the colon to number '
            'across the whole book instead: B::6018 is Bukhari hadith 6018. '
            'Sources include Q (Quran), HM (Hisnul Muslim) and '
            'B, M, AD, T, N, IM (hadith).',
      );
    }
    if (records.isEmpty) {
      return const _Notice(
        icon: Icons.inbox_outlined,
        title: 'No results',
        detail: 'The query resolved but matched nothing.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: records.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${records.length} result${records.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          );
        }
        return _RecordCard(record: records[i - 1]);
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final QqlRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.reference,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                Text(record.source,
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            if (record.arabic.isNotEmpty) ...[
              const SizedBox(height: 10),
              // Tajweed colouring only for the Quran. Hadith and supplication
              // texts are Arabic but are not recited under these rules, and
              // colouring them would imply otherwise.
              arabicText(context, record.arabic,
                  size: 22, tajweed: record.isQuran),
            ],
            if (record.narrator != null) ...[
              const SizedBox(height: 10),
              Text(record.narrator!,
                  style: const TextStyle(
                      fontSize: 12, fontStyle: FontStyle.italic)),
            ],
            if (record.translation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(record.translation, style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.detail,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const CircularProgressIndicator()
            else
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(detail,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
