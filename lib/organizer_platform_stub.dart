import 'package:flutter/material.dart';
class DeckOrganizerScreen extends StatelessWidget {
  const DeckOrganizerScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Deck Organizer')),
    body: const Center(child: Padding(padding: EdgeInsets.all(24),child: Text(
      'This version of Deck Organizer runs in Chrome / Flutter Web. '
      'Native Android and Windows integration is not included in this web preview.'))),
  );
}
