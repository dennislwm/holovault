import 'package:flutter/material.dart';

void main() {
  runApp(const HolovaultApp());
}

class HolovaultApp extends StatelessWidget {
  const HolovaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'holovault',
      home: Scaffold(
        body: Center(child: Text('holovault')),
      ),
    );
  }
}
