import 'package:flutter/material.dart';

import '../qql/qql_data.dart';
import '../qql/qql_helper.dart';
import '../tajweed.dart';
import '../user_lists.dart';
import 'add_entry_sheet.dart';

/// One user list: its entries resolved through QQL, with add, remove and
/// reorder.
///
/// Entries are stored as queries, so each one may resolve to several records —
/// `Q:2:1-5` is one entry and five ayat. Resolution needs the native library,
/// so the screen degrades the same way the Query tab does.
class ListDetailScreen extends StatefulWidget {
  const ListDetailScreen({
    super.key,
    required this.listId,
    required this.store,
  });

  final String listId;
  final UserListStore store;

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

/// One entry, and whatever resolving it produced.
class _Resolved {
  const _Resolved(this.query, this.records, this.error);

  final String query;
  final List<QqlRecord> records;
  final String? error;
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  QqlHelper? _qql;
  String? _prepareError;
  bool _preparing = true;

  List<_Resolved> _resolved = const [];

  UserList? get _list => widget.store.byId(widget.listId);

  @override
  void initState() {
    super.initState();
    if (!QqlHelper.isSupported) {
      _preparing = false;
    } else {
      _prepare();
    }
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    _qql?.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) _resolve();
  }

  Future<void> _prepare() async {
    try {
      final directory = await QqlData.ensureUnpacked();
      final helper = QqlHelper.open(dataDirectory: directory);
      if (!mounted) {
        helper.dispose();
        return;
      }
      setState(() {
        _qql = helper;
        _preparing = false;
      });
      _resolve();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _prepareError = '$e';
        _preparing = false;
      });
    }
  }

  void _resolve() {
    final qql = _qql;
    final list = _list;
    if (qql == null || list == null) return;
    setState(() {
      _resolved = [
        for (final query in list.queries)
          () {
            try {
              return _Resolved(query, qql.query(query), null);
            } on QqlQueryException catch (e) {
              return _Resolved(query, const [], e.message);
            }
          }()
      ];
    });
  }

  Future<void> _add() async {
    final query = await showAddEntrySheet(context);
    if (query == null) return;
    await widget.store.addQuery(widget.listId, query);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final list = _list;
        if (list == null) {
          return const Scaffold(
            body: Center(child: Text('This list no longer exists.')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(list.name),
            actions: [
              IconButton(
                tooltip: 'Tajweed colours',
                icon: const Icon(Icons.palette_outlined),
                onPressed: () => showTajweedLegend(context),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          body: _body(list),
        );
      },
    );
  }

  Widget _body(UserList list) {
    if (!QqlHelper.isSupported) {
      return const _Notice(
        icon: Icons.web_asset_off_outlined,
        title: 'Not available on the web',
        detail: 'Lists resolve their entries through a native library the '
            'browser does not have. You can still build lists on Android.',
      );
    }
    if (_preparing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_prepareError != null) {
      return _Notice(
        icon: Icons.error_outline,
        title: 'Could not start QQL',
        detail: _prepareError!,
      );
    }
    if (list.queries.isEmpty) {
      return const _Notice(
        icon: Icons.playlist_add,
        title: 'Nothing in this list yet',
        detail: 'Tap Add to choose an ayah, hadith or supplication — from '
            'dropdowns, or by typing a reference.',
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: _resolved.length,
      // onReorderItem, not onReorder: it hands back an index already adjusted
      // for the removal, so no off-by-one correction is needed here.
      onReorderItem: (from, to) =>
          widget.store.moveQuery(widget.listId, from, to),
      itemBuilder: (context, i) {
        final entry = _resolved[i];
        return _EntryCard(
          key: ValueKey('${entry.query}#$i'),
          index: i,
          entry: entry,
          onRemove: () => widget.store.removeQueryAt(widget.listId, i),
        );
      },
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    super.key,
    required this.index,
    required this.entry,
    required this.onRemove,
  });

  final int index;
  final _Resolved entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.query,
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: scheme.onSurfaceVariant),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onRemove,
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4, right: 8),
                    child: Icon(Icons.drag_handle, size: 20),
                  ),
                ),
              ],
            ),
            if (entry.error != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(entry.error!,
                    style: TextStyle(fontSize: 13, color: scheme.error)),
              )
            else
              for (final record in entry.records)
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(record.reference,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      if (record.arabic.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        // Quran only: hadith and supplications are Arabic but
                        // are not recited under the tajweed rules.
                        arabicText(context, record.arabic,
                            size: 22, tajweed: record.isQuran),
                      ],
                      if (record.translation.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(record.translation,
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(
      {required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
