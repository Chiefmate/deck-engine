import 'package:flutter/material.dart';

class EngineLogScreen extends StatelessWidget {
  const EngineLogScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Engine')),
    body: const Center(
      child: Text('Open Deck + Engine in a browser to use EngineLog.'),
    ),
  );
}
