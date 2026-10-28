import 'package:flutter/material.dart';

import '../data/expense_repository.dart';
import '../widgets/common.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _add(BuildContext context, List<String> current) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Gifts'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !context.mounted) return;
    if (current.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
      showMessage(context, '"$trimmed" already exists');
      return;
    }
    await context.repo.saveCategories([...current, trimmed]);
  }

  Future<void> _remove(BuildContext context, List<String> current, String name) async {
    if (current.length <= 1) {
      showMessage(context, 'Keep at least one category');
      return;
    }
    final repo = context.repo;
    await repo.saveCategories(current.where((c) => c != name).toList());
    if (!context.mounted) return;
    showMessage(
      context,
      'Removed "$name". Past expenses keep it.',
      action: SnackBarAction(label: 'Undo', onPressed: () => repo.saveCategories(current)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    return StreamBuilder<List<String>>(
      stream: repo.watchCategories(),
      builder: (context, snap) {
        final cats = snap.data ?? const <String>[];
        return Scaffold(
          appBar: AppBar(title: const Text('Categories')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: snap.hasData ? () => _add(context, cats) : null,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New category'),
          ),
          body: !snap.hasData
              ? const Center(child: CircularProgressIndicator())
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: cats.length,
                  onReorderItem: (from, to) {
                    final list = List.of(cats);
                    final item = list.removeAt(from);
                    list.insert(to, item);
                    repo.saveCategories(list);
                  },
                  itemBuilder: (context, i) => ListTile(
                    key: ValueKey(cats[i]),
                    leading: CategoryBadge(category: cats[i], size: 40),
                    title: Text(cats[i]),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Remove ${cats[i]}',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _remove(context, cats, cats[i]),
                        ),
                        ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle_rounded)),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
