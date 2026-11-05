import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vessel_assistant/main.dart';

void main() {
  testWidgets('Deck + Engine opens both departments', (tester) async {
    await tester.pumpWidget(const VesselApp());
    expect(find.text('Deck + Engine'), findsOneWidget);
    await tester.tap(find.text('Engine'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Open Deck + Engine in a browser'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deck'));
    await tester.pumpAndSettle();
    expect(find.text('Cargo'), findsOneWidget);
    expect(find.text('Deck Organizer'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
