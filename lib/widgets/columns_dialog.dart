import 'package:flutter/material.dart';

import '../collection_search.dart';

/// REQ-042 (c), ADR-22: pick which fields a row shows and in what order.
/// Returns the checked ids in chosen order, or null when cancelled. An empty
/// result is returned as is; the caller falls back to the screen default.
Future<List<String>?> showColumnsDialog(
  BuildContext context, {
  required List<String> selected,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _ColumnsDialog(selected: selected),
  );
}

class _ColumnsDialog extends StatefulWidget {
  const _ColumnsDialog({required this.selected});

  final List<String> selected;

  @override
  State<_ColumnsDialog> createState() => _ColumnsDialogState();
}

class _ColumnsDialogState extends State<_ColumnsDialog> {
  late final List<String> _order = [
    ...widget.selected,
    for (final id in sortKeyIds)
      if (!widget.selected.contains(id)) id,
  ];
  late final Set<String> _checked = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Columns'),
      content: SizedBox(
        width: double.maxFinite,
        child: ReorderableListView(
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          onReorderItem: (from, to) => setState(() {
            _order.insert(to, _order.removeAt(from));
          }),
          children: [
            for (final (i, id) in _order.indexed)
              CheckboxListTile(
                key: ValueKey(id),
                value: _checked.contains(id),
                title: Text(sortKeyLabel(id)),
                onChanged: (v) => setState(() {
                  v == true ? _checked.add(id) : _checked.remove(id);
                }),
                secondary: ReorderableDragStartListener(
                  index: i,
                  child: Icon(Icons.drag_handle, key: Key('drag-$id')),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop([
            for (final id in _order)
              if (_checked.contains(id)) id,
          ]),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
