import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/main.dart';

void main() {
  testWidgets('renders holovault title', (WidgetTester tester) async {
    await tester.pumpWidget(const HolovaultApp());
    expect(find.text('holovault'), findsOneWidget);
  });
}
