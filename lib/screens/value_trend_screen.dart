import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../database/database.dart';
import '../widgets/search_filter_bar.dart';
import 'collection_list_screen.dart' show schemaErrorMessage;

/// ADR-12 (superseded by ADR-19), ADR-19 Option 1: a cumulative value-trend
/// chart over `watchAllItems()`, filterable via the shared
/// [SearchFilterBar] (search term + clause builder), narrowing the same way
/// [CollectionListScreen]'s (ADR-18) does -- via [filterCollectionItems].
/// The filter's search term/clause list persist across restart through
/// [SearchFilterBar]'s own `shared_preferences` keys (REQ-034).
class ValueTrendScreen extends StatefulWidget {
  const ValueTrendScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<ValueTrendScreen> createState() => _ValueTrendScreenState();
}

class _ValueTrendScreenState extends State<ValueTrendScreen> {
  List<CollectionItem> _filtered = const [];
  // REQ-034: cached once, not re-created per build -- SearchFilterBar's
  // onFiltered callback setState()s this very State, and re-calling
  // watchAllItems() on every build would hand it a freshly-subscribed
  // stream (a new emitted list identity) each time, which its own
  // didUpdateWidget would read as "items changed" and recompute again,
  // looping forever under pumpAndSettle.
  late final Stream<List<CollectionItem>> _itemsStream = widget.database.watchAllItems();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collection Value')),
      body: StreamBuilder<List<CollectionItem>>(
        stream: _itemsStream,
        builder: (context, snapshot) {
          // REQ-018 (ADR-07): this screen holds its own independent
          // watchAllItems() stream -- an unrecognized schema version must
          // surface here too, not only on CollectionListScreen.
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      schemaErrorMessage(snapshot.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final allItems = snapshot.data ?? const [];
          final filtered = _filtered;

          // REQ-015: cumulative running total over time, sorted by
          // dateAdded, matching ADR-12's "value trend over time" framing --
          // not a per-item scatter of individual values. A missing
          // valueTotal/paidTotal on an otherwise-dated item contributes 0,
          // so both lines share the same x-axis (item order by dateAdded).
          final withDates = filtered.where((i) => i.dateAdded != null).toList()
            ..sort((a, b) => a.dateAdded!.compareTo(b.dateAdded!));

          double runningValue = 0;
          double runningPaid = 0;
          final valueSpots = <FlSpot>[];
          final paidSpots = <FlSpot>[];
          for (var i = 0; i < withDates.length; i++) {
            runningValue += withDates[i].valueTotal ?? 0;
            runningPaid += withDates[i].paidTotal ?? 0;
            valueSpots.add(FlSpot(i.toDouble(), runningValue));
            paidSpots.add(FlSpot(i.toDouble(), runningPaid));
          }
          final total = valueSpots.isEmpty ? 0.0 : valueSpots.last.y;
          final totalPaid = paidSpots.isEmpty ? 0.0 : paidSpots.last.y;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
                SearchFilterBar(
                  prefsKeyPrefix: 'value_trend_filter',
                  items: allItems,
                  onFiltered: (result) => setState(() => _filtered = result),
                ),
                const SizedBox(height: 12),
                Text(
                  total.toStringAsFixed(2),
                  key: const Key('value-trend-total'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'Paid: ${totalPaid.toStringAsFixed(2)}',
                  key: const Key('value-trend-paid-total'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: valueSpots.isEmpty
                      ? const Center(child: Text('No value data yet'))
                      : LineChart(
                          LineChartData(
                            lineBarsData: [
                              LineChartBarData(spots: valueSpots, isCurved: true),
                              LineChartBarData(
                                spots: paidSpots,
                                isCurved: true,
                                color: Colors.orange,
                                dashArray: [6, 4],
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Matching items · ${filtered.length}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                for (final item in filtered)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name),
                              Text(
                                [
                                  item.setName,
                                  item.rarity,
                                ].whereType<String>().join(' · '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(item.valueTotal?.toStringAsFixed(2) ?? '--'),
                            Text(
                              'Paid: ${item.paidTotal?.toStringAsFixed(2) ?? '--'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
