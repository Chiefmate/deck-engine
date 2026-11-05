import 'package:flutter_test/flutter_test.dart';
import '../lib/safety_depth_model.dart';

VesselSafetySettings profile({bool tables = false}) => VesselSafetySettings(name: 'Test Vessel',
  lengthBP: 198.8,breadth: 30.1,cbMethod: tables ? tableCbMethod : calculateCbMethod);
SafetyDepthInput input({double fore = 9.41,double aft = 9.71,double displacement = 35496,
  double rho = 1.025,double depth = 8.8,double speed = 6,double heel = 0,double density = 0,
  String catzoc = 'A1',double? cb,double? manual,String? basis}) => SafetyDepthInput(foreDraft: fore,aftDraft: aft,
    displacementMT: displacement,waterDensity: rho,chartedDepth: depth,speedThroughWater: speed,
    heelDegrees: heel,densityCorrection: density,catzoc: catzoc,tableCb: cb,manualDepthAllowance: manual,depthAllowanceBasis: basis);
void main() {
  test('Calculated Cb converts mass to volume', () {
    final r = SafetyDepthResult.calculate(profile(),input());
    expect(r.blockCoefficient,closeTo(0.6053614795159533,1e-12));
    expect(r.squat,closeTo(0.4358602652514864,1e-12));
    expect(r.total,closeTo(11.704860265251487,1e-12));
    expect(r.displayedDepth,11.71);
  });
  test('Uses maximum draft and arithmetic mean', () {
    final r = SafetyDepthResult.calculate(profile(),input(fore: 12,aft: 10));
    expect(r.maximumDraft,12); expect(r.meanDraft,11); expect(r.margin,closeTo(1.2,1e-12));
  });
  test('Table Cb used directly', () {
    final r = SafetyDepthResult.calculate(profile(tables: true),input(cb: 0.7));
    expect(r.blockCoefficient,0.7); expect(r.squat,closeTo(0.504,1e-12));
  });
  test('Table Cb does not depend on displacement', () {
    final a = SafetyDepthResult.calculate(profile(tables: true),input(cb: 0.7));
    final b = SafetyDepthResult.calculate(profile(tables: true),input(cb: 0.7,displacement: 30000));
    expect(a.total,b.total);
  });
  test('Missing and invalid table Cb rejected', () {
    for (final c in [null,0.0,-0.1,1.1,double.nan,double.infinity]) {
      expect(() => SafetyDepthResult.calculate(profile(tables: true),input(cb: c)),throwsFormatException);
    }
  });
  test('Heel uses breadth and absolute angle', () {
    final a = SafetyDepthResult.calculate(profile(),input(heel: 2));
    final b = SafetyDepthResult.calculate(profile(),input(heel: -2));
    expect(a.heelCorrection,closeTo(0.4816,1e-12)); expect(a.total,b.total);
  });
  test('Density correction is added once', () {
    final a = SafetyDepthResult.calculate(profile(),input());
    final b = SafetyDepthResult.calculate(profile(),input(density: 0.2));
    expect(b.total-a.total,closeTo(0.2,1e-12));
  });
  test('Squat scales with speed squared; zero speed is allowed', () {
    final a = SafetyDepthResult.calculate(profile(),input(speed: 3));
    final b = SafetyDepthResult.calculate(profile(),input(speed: 6));
    expect(b.squat,closeTo(4*a.squat,1e-12));
    expect(SafetyDepthResult.calculate(profile(),input(speed: 0)).squat,0);
  });
  test('CATZOC formulas and D/U warning', () {
    for (final category in ['A1','A2','B','C']) {
      final r = SafetyDepthResult.calculate(profile(),input(catzoc: category));
      expect(r.chartAllowance,closeTo(category == 'A1' ? 0.588 : ['A2','B'].contains(category) ? 1.176 : 2.44,1e-12));
      expect(r.warning != null,['D','U'].contains(category));
    }
  });
  test('D/U never default to C and require a documented manual value', () {
    for(final cat in ['D','U']) {
      expect(()=>SafetyDepthResult.calculate(profile(),input(catzoc:cat)),throwsFormatException);
      expect(()=>SafetyDepthResult.calculate(profile(),input(catzoc:cat,manual:3)),throwsFormatException);
      final r=SafetyDepthResult.calculate(profile(),input(catzoc:cat,manual:3,basis:'Port assessment'));
      expect(r.chartAllowance,3);
      expect(r.warning,contains('Port assessment'));
      expect(r.calculationLines[7].formula,contains('manual'));
    }
  });
  test('Invalid conditions rejected', () {
    for (final v in [0.0,-1.0,double.nan,double.infinity]) {
      expect(() => SafetyDepthResult.calculate(profile(),input(fore: v)),throwsFormatException);
      expect(() => SafetyDepthResult.calculate(profile(),input(rho: v)),throwsFormatException);
    }
    expect(() => SafetyDepthResult.calculate(profile(),input(heel: 90)),throwsFormatException);
    expect(() => SafetyDepthResult.calculate(profile(),input(speed: -1)),throwsFormatException);
    expect(() => SafetyDepthResult.calculate(profile(),input(density: -0.1)),throwsFormatException);
    expect(() => SafetyDepthResult.calculate(profile(),input(catzoc: 'Z')),throwsFormatException);
  });
  test('Impossible calculated Cb rejected', () {
    expect(() => SafetyDepthResult.calculate(profile(),input(displacement: 1e8)),throwsFormatException);
  });
  test('Profile round trip stores exactly four particulars', () {
    final p = profile(tables: true);
    expect(p.toJson().length,4); expect(VesselSafetySettings.fromJson(p.toJson()).toJson(),p.toJson());
  });
  test('Report snapshot retains time and all calculation components', () {
    final time = DateTime.utc(2026,11,2,12,34,56);
    final r = SafetyDepthResult.calculate(profile(),input(),calculatedUTC: time);
    expect(r.calculatedUTC,time); expect(r.calculationLines.length,10);
    expect(r.calculationLines.last.value,r.displayedDepth);
    expect(r.calculationLines[5].formula,contains('30.1'));
  });
}
