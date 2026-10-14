import 'package:flutter/material.dart';

import '../annualized_return.dart';
import '../collection_search.dart';
import '../database/database.dart';

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
  });

  final CollectionItem item;
  final List<String> columns;
  final double returnBarMax;

  // Value and quantity read on their own; every other trailing cell carries
  // its label so two numbers are never ambiguous.
  Widget _trailing(BuildContext context, String id) {
    final style = Theme.of(context).textTheme.bodySmall;
    final text = cellText(item, id) ?? '--';
    final bare = id == SearchField.value.name || id == SearchField.quantity.name;
    final label = Text(bare ? text : '${sortKeyLabel(id)}: $text', style: bare ? null : style);
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

  @override
  Widget build(BuildContext context) {
    final subtitle = columns.length > 1 ? cellText(item, columns[1]) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cellText(item, columns.first) ?? '--'),
                if (subtitle != null)
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [for (final id in columns.skip(2)) _trailing(context, id)],
          ),
        ],
      ),
    );
  }
}
