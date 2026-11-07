import 'package:flutter/material.dart';

import '../annualized_return.dart';
import '../collection_search.dart';
import '../database/database.dart';
import '../database/overrides_schema.dart';

/// REQ-042 (f): shown by every item list when its filter leaves no rows.
const noMatchingItemsMessage = 'No items match the current filter';

/// REQ-042 (c), ADR-22 Option 1: the row shared by the item-list tabs. The
/// first chosen column is the title, the second the subtitle, the rest are
/// trailing values stacked right-aligned in chosen order. The host wraps it
/// in its own tap target. [returnBarMax] is the largest absolute annual
/// return over the displayed rows (see [maxAbsReturnAnnual]); the
/// `returnAnnual` cell draws a bar of `abs(percent) / returnBarMax`.
class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    required this.item,
    required this.columns,
    this.returnBarMax = 0,
    this.registry,
  });

  /// REQ-043 (d): declared custom columns; null means the generated registry.
  final List<CustomColumn>? registry;

  final MergedItem item;
  final List<String> columns;
  final double returnBarMax;

  // Value and quantity read on their own; every other trailing cell carries
  // its label so two numbers are never ambiguous.
  Widget _cell(BuildContext context, String id, {required bool trailing, TextStyle? style}) {
    final text = cellText(item, id, registry: registry) ?? '--';
    final bare = !trailing || id == SearchField.value.name || id == SearchField.quantity.name;
    final label = Text(bare ? text : '${sortKeyLabel(id, registry)}: $text', style: style);
    if (id != SearchField.returnAnnual.name) return label;
    final pct = annualizedReturnPercent(item, DateTime.now());
    final factor = pct == null || returnBarMax == 0
        ? 0.0
        : (pct.abs() / returnBarMax).clamp(0.0, 1.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        const SizedBox(width: 6),
        SizedBox(
          width: 48,
          height: 6,
          child: LinearProgressIndicator(key: const Key('return-bar'), value: factor),
        ),
      ],
    );
  }

  // REQ-054: a small outlined pill, like the mock's language chip.
  Widget _chip(BuildContext context, String text) {
    final color = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final hasSubtitle = columns.length > 1 &&
        (columns[1] == SearchField.returnAnnual.name ||
            cellText(item, columns[1], registry: registry) != null);
    final chips = rowChips(item);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cell(context, columns.first, trailing: false),
                // REQ-054: the chips sit on the subtitle line, as the ADR-24 mock shows.
                if (hasSubtitle || chips.isNotEmpty)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      if (hasSubtitle) _cell(context, columns[1], trailing: false, style: small),
                      for (final c in chips) _chip(context, c),
                    ],
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final id in columns.skip(2)) _cell(context, id, trailing: true, style: small),
            ],
          ),
        ],
      ),
    );
  }
}
