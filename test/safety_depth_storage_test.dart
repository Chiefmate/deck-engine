import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../lib/deck_safety_depth.dart';
import '../lib/safety_depth_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() { SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty(); });
  test('Profile and last inputs persist independently', () async {
    const p = VesselSafetySettings(name: 'Saved Vessel',lengthBP: 150,breadth: 25,cbMethod: tableCbMethod);
    await SafetyDepthStore.saveProfile(p);
    await SafetyDepthStore.saveInputs({'fore': '8,2','catzoc': 'U','tableCb': '0.72'});
    final saved = await SafetyDepthStore.load();
    expect((saved['profile'] as VesselSafetySettings).toJson(),p.toJson());
    expect((saved['inputs'] as Map)['fore'],'8,2');
    expect(saved['reviewSettings'],false);
  });
  test('Previous dimensions migrate and require method review', () async {
    await SharedPreferencesAsync().setString('deck_safety_vessel_v2',jsonEncode({
      'name': 'Previous Vessel','lengthBP': 150,'breadth': 25,'marginPercent': 10,
      'reference': 'old','useApprovedSquatRelation': false}));
    final loaded = await SafetyDepthStore.load();
    expect((loaded['profile'] as VesselSafetySettings).name,'Previous Vessel');
    expect(loaded['reviewSettings'],true);
    await SafetyDepthStore.saveProfile(loaded['profile'] as VesselSafetySettings);
    expect((await SafetyDepthStore.load())['reviewSettings'],false);
  });
  testWidgets('Saved particulars restore and the current form uses defaults', (tester) async {
    await tester.runAsync(() async {
      await SafetyDepthStore.saveProfile(const VesselSafetySettings(name: 'Restored Vessel',
        lengthBP: 150,breadth: 25,cbMethod: tableCbMethod));
      await tester.pumpWidget(const MaterialApp(home: SafetyDepthScreen()));
      await SafetyDepthStore.load();
    });
    await tester.pumpAndSettle();
    expect(find.text('Restored Vessel'),findsOneWidget);
    final density = tester.widget<TextFormField>(find.byKey(const ValueKey('waterDensity')));
    expect(density.controller!.text,'1.025');
    final correction = tester.widget<TextFormField>(find.byKey(const ValueKey('density')));
    expect(correction.controller!.text,'0');
    expect(find.byKey(const ValueKey('tableCb')),findsOneWidget);
    expect(find.text('Export Full Report'),findsNothing);
  });
}
