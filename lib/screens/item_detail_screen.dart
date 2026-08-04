import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../database/database.dart';

/// ADR-04, mechanisms B1 (flutter_form_builder) and C1 (PageView): one
/// editable form per item, swipeable and button-navigable between items.
///
/// Edits the base imported fields only (name, extra) -- ADR-04 depends on
/// ADR-03's override/merge layer for override-field editing, and ADR-03 is
/// still Held, so this screen doesn't invent that layer ahead of it.
class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({
    super.key,
    required this.database,
    required this.items,
    required this.initialIndex,
  });

  final AppDatabase database;
  final List<CollectionItem> items;
  final int initialIndex;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(CollectionItem item, Map<String, dynamic> values) {
    // Only name/extra are set here -- every other column stays absent, so
    // drift's DoUpdate leaves the item's imported typed fields untouched.
    return widget.database.upsertItem(
      CollectionItemsCompanion.insert(
        importedId: item.importedId,
        name: values['name'] as String,
        extra: Value(
          (values['extra'] as String?)?.isEmpty ?? true
              ? null
              : values['extra'] as String,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item detail')),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final formKey = GlobalKey<FormBuilderState>();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: FormBuilder(
              key: formKey,
              initialValue: {'name': item.name, 'extra': item.extra ?? ''},
              child: Column(
                children: [
                  FormBuilderTextField(
                    name: 'name',
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  FormBuilderTextField(
                    name: 'extra',
                    decoration: const InputDecoration(labelText: 'Extra'),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _currentIndex > 0
                            ? () => _controller.previousPage(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                              )
                            : null,
                        child: const Text('Prev'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final state = formKey.currentState;
                          if (state != null && state.saveAndValidate()) {
                            _save(item, state.value);
                          }
                        },
                        child: const Text('Save'),
                      ),
                      ElevatedButton(
                        onPressed: _currentIndex < widget.items.length - 1
                            ? () => _controller.nextPage(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                              )
                            : null,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
