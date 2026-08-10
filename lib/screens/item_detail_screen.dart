import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../database/database.dart';

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// REQ-014: matches the ADR-04 mock's date format ("24 Mar 2026").
String _formatDate(DateTime date) =>
    '${date.day} ${_monthAbbrev[date.month - 1]} ${date.year}';

/// REQ-014: gradeType/gradeSubtype are always paired concepts in real data
/// (e.g. "PSA" + "10 GEM-MT") -- shown as one combined field, not two.
String? _gradeText(CollectionItem item) {
  final parts = [item.gradeType, item.gradeSubtype].whereType<String>();
  return parts.isEmpty ? null : parts.join(' ');
}

/// REQ-014: the 10 read-only imported fields the ADR-04 mock shows, in
/// display order. Excludes brandName/valueCurrency/paidCurrency/groupName/
/// groupWishlist/tag (constant across every real row, zero variance) and
/// id/importedId/tcgplayerId/pricechartingId/doubleholoId (internal keys).
List<MapEntry<String, String>> _importedFields(CollectionItem item) {
  final entries = <MapEntry<String, String?>>[
    MapEntry('Set', item.setName),
    MapEntry('Discriminator', item.discriminator),
    MapEntry('Rarity', item.rarity),
    MapEntry('Quantity', item.quantity?.toString()),
    MapEntry('Value (total)', item.valueTotal?.toString()),
    MapEntry('Value (per unit)', item.valuePerUnit?.toString()),
    MapEntry('Paid (total)', item.paidTotal?.toString()),
    MapEntry('Paid (per unit)', item.paidPerUnit?.toString()),
    MapEntry('Grade', _gradeText(item)),
    MapEntry(
      'Date added',
      item.dateAdded == null ? null : _formatDate(item.dateAdded!),
    ),
  ];
  return entries
      .where((e) => e.value != null)
      .map((e) => MapEntry(e.key, e.value!))
      .toList();
}

class _ImportedFieldRow extends StatelessWidget {
  const _ImportedFieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // REQ-014: circular nav buttons + position indicator,
                // replacing the old bottom-row Prev/Next buttons.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentIndex > 0
                          ? () => _controller.previousPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                            )
                          : null,
                    ),
                    Text(
                      '${_currentIndex + 1} / ${widget.items.length}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentIndex < widget.items.length - 1
                          ? () => _controller.nextPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                            )
                          : null,
                    ),
                  ],
                ),
                Text(
                  '← swipe also moves between cards →',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 12),
                // REQ-014: hero banner, matches the ADR-04 mock.
                Container(
                  height: 120,
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                    ),
                  ),
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'IMPORTED DATA',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
                ),
                ..._importedFields(
                  item,
                ).map((e) => _ImportedFieldRow(label: e.key, value: e.value)),
                const SizedBox(height: 16),
                Text(
                  'EDITABLE',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
                ),
                FormBuilder(
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
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          final state = formKey.currentState;
                          if (state != null && state.saveAndValidate()) {
                            _save(item, state.value);
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
