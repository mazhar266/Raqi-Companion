import 'package:flutter/material.dart';

import '../theme_store.dart';
import '../user_lists.dart';
import 'app_menu.dart';
import 'list_detail_screen.dart';

/// The user's own lists: create, rename, delete, and open.
class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key, required this.store, required this.themeStore});

  final UserListStore store;
  final ThemeStore themeStore;

  Future<void> _create(BuildContext context) async {
    final name = await _promptForName(context, title: 'New list');
    if (name == null) return;
    final list = await store.create(name);
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ListDetailScreen(listId: list.id, store: store),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final lists = store.lists;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Lists'),
            actions: [AppMenuButton(themeStore: themeStore, userLists: store)],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _create(context),
            icon: const Icon(Icons.add),
            label: const Text('New list'),
          ),
          body: lists.isEmpty
              ? const _Empty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: lists.length,
                  itemBuilder: (context, i) {
                    final list = lists[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.only(
                            left: 20, right: 8, top: 8, bottom: 8),
                        leading: const Icon(Icons.playlist_play, size: 30),
                        title: Text(list.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(list.queries.isEmpty
                            ? 'Empty'
                            : '${list.queries.length} '
                                'entr${list.queries.length == 1 ? 'y' : 'ies'}'
                                '  ·  ${list.queries.take(3).join(', ')}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'rename') {
                              final name = await _promptForName(context,
                                  title: 'Rename list', initial: list.name);
                              if (name != null) store.rename(list.id, name);
                            } else if (value == 'delete') {
                              final ok = await _confirmDelete(context, list);
                              if (ok) store.delete(list.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'rename', child: Text('Rename')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        ),
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ListDetailScreen(
                              listId: list.id, store: store),
                        )),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

Future<String?> _promptForName(BuildContext context,
    {required String title, String? initial}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
            labelText: 'Name', hintText: 'Morning routine'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save')),
      ],
    ),
  ).then((value) => (value == null || value.trim().isEmpty) ? null : value);
}

Future<bool> _confirmDelete(BuildContext context, UserList list) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete "${list.name}"?'),
      content: const Text('The list is removed from this device. '
          'Nothing else is affected.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete')),
      ],
    ),
  );
  return ok ?? false;
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_add,
                size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No lists yet',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              'Build your own sequence of ayat, hadith and supplications — '
              'pick them from dropdowns or type a reference like Q:2:1-5,255.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
