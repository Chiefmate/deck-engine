import 'dart:math' as math;
import 'depth_accuracy.dart';

const calculateCbMethod = 'calculate';
const tableCbMethod = 'tables';
const safetyDepthModelVersion = '3.1';

class VesselSafetySettings {
  final String name;
  final double lengthBP;
  final double breadth;
  final String cbMethod;
  const VesselSafetySettings({required this.name, required this.lengthBP,
    required this.breadth, required this.cbMethod});
  void validate() {
    if (name.trim().isEmpty || !lengthBP.isFinite || lengthBP <= 0 ||
        !breadth.isFinite || breadth <= 0 ||
        ![calculateCbMethod, tableCbMethod].contains(cbMethod)) {
      throw const FormatException('Check vessel name, LBP, breadth and Cb method.');
    }
  }
  Map<String, dynamic> toJson() => {'name': name, 'lengthBP': lengthBP,
    'breadth': breadth, 'cbMethod': cbMethod};
  factory VesselSafetySettings.fromJson(Map<String, dynamic> j) {
    final p = VesselSafetySettings(name: j['name'] as String,
      lengthBP: (j['lengthBP'] as num).toDouble(),
      breadth: (j['breadth'] as num).toDouble(), cbMethod: j['cbMethod'] as String);
    p.validate(); return p;
  }
  String get methodLabel => cbMethod == calculateCbMethod ? 'Calculate Cb' : 'Enter Cb from Tables';
}

class SafetyDepthInput {
  final double foreDraft, aftDraft, displacementMT, waterDensity, chartedDepth;
  final double speedThroughWater, heelDegrees, densityCorrection;
  final String catzoc;
  final double? tableCb, manualDepthAllowance;
  final String? depthAllowanceBasis;
  const SafetyDepthInput({required this.foreDraft, required this.aftDraft,
    required this.displacementMT, required this.waterDensity, required this.chartedDepth,
    required this.speedThroughWater, required this.heelDegrees,
    required this.densityCorrection, required this.catzoc, this.tableCb, this.manualDepthAllowance, this.depthAllowanceBasis});
}

class CalculationLine {
  final String label, formula, unit;
  final double value;
  const CalculationLine(this.label, this.value, this.unit, this.formula);
}

class SafetyDepthResult {
  final VesselSafetySettings vessel;
  final SafetyDepthInput input;
  final DateTime calculatedUTC;
  final double maximumDraft, meanDraft, blockCoefficient, margin, squat, heelCorrection;
  final double chartAllowance, total;
  const SafetyDepthResult._({required this.vessel, required this.input,
    required this.calculatedUTC, required this.maximumDraft, required this.meanDraft,
    required this.blockCoefficient, required this.margin, required this.squat,
    required this.heelCorrection, required this.chartAllowance, required this.total});
  factory SafetyDepthResult.calculate(VesselSafetySettings vessel, SafetyDepthInput p,
      {DateTime? calculatedUTC}) {
    vessel.validate();
    if ([p.foreDraft,p.aftDraft,p.displacementMT,p.waterDensity,p.chartedDepth]
        .any((v) => !v.isFinite || v <= 0) ||
        [p.speedThroughWater,p.densityCorrection].any((v) => !v.isFinite || v < 0) ||
        !p.heelDegrees.isFinite || p.heelDegrees.abs() >= 90 ||
        !['A1','A2','B','C','D','U'].contains(p.catzoc)) {
      throw const FormatException('Check positive draughts, displacement, density and charted depth; '
        'speed/correction must be non-negative and heel must be between -90 and 90 degrees.');
    }
    final maximum = math.max(p.foreDraft,p.aftDraft);
    final mean = p.foreDraft / 2 + p.aftDraft / 2;
    final cb = vessel.cbMethod == calculateCbMethod
      ? calculateBlockCoefficient(displacementMT: p.displacementMT, waterDensity: p.waterDensity,
          lengthBP: vessel.lengthBP, breadth: vessel.breadth, meanDraft: mean)
      : p.tableCb;
    if (cb == null || !cb.isFinite || cb <= 0 || cb > 1) {
      throw const FormatException('Cb must be greater than 0 and no greater than 1. Check inputs and units.');
    }
    final margin = maximum * 0.1;
    final squat = cb * p.speedThroughWater * p.speedThroughWater / 50;
    final heel = 0.008 * vessel.breadth * p.heelDegrees.abs();
    final chart = depthAccuracyAllowance(p.catzoc, p.chartedDepth,
      manual: p.manualDepthAllowance, basis: p.depthAllowanceBasis);
    final total = maximum + margin + squat + heel + p.densityCorrection + chart;
    if ([maximum,mean,cb,margin,squat,heel,chart,total].any((v) => !v.isFinite || v.abs() > 1e9)) {
      throw const FormatException('Values exceed the calculation range.');
    }
    return SafetyDepthResult._(vessel: vessel,input: p,calculatedUTC: (calculatedUTC ?? DateTime.now()).toUtc(),
      maximumDraft: maximum,meanDraft: mean,blockCoefficient: cb,margin: margin,squat: squat,
      heelCorrection: heel,chartAllowance: chart,total: total);
  }
  // Match Excel ROUNDUP(total, 2) for the positive depth sum.
  double get displayedDepth => (total * 100).ceilToDouble() / 100;
  bool get usesManualDepthAllowance => requiresManualDepthAllowance(input.catzoc);
  String? get warning => usesManualDepthAllowance
      ? 'CATZOC ${input.catzoc}: manual depth allowance used. D is worse than C; U is unassessed. '
        'Basis: ${input.depthAllowanceBasis}. This does not establish seabed reliability or passage safety.' : null;
  List<CalculationLine> get calculationLines {
    final p = input;
    String n(double v) => v.toString();
    final cbFormula = vessel.cbMethod == calculateCbMethod
      ? '(${n(p.displacementMT)} / ${n(p.waterDensity)}) / '
        '(${n(vessel.lengthBP)} * ${n(vessel.breadth)} * ${n(meanDraft)})'
      : '${n(blockCoefficient)} (entered from vessel tables)';
    final chartFormula = p.catzoc == 'A1' ? '0.5 + 0.01 * ${n(p.chartedDepth)}'
      : ['A2','B'].contains(p.catzoc) ? '1 + 0.02 * ${n(p.chartedDepth)}'
      : p.catzoc == 'C' ? '2 + 0.05 * ${n(p.chartedDepth)}'
      : '${n(chartAllowance)} (manual; ${p.depthAllowanceBasis})';
    return [
      CalculationLine('Max Draft',maximumDraft,'m','MAX(${n(p.foreDraft)}, ${n(p.aftDraft)})'),
      CalculationLine('Mean Draft',meanDraft,'m','(${n(p.foreDraft)} + ${n(p.aftDraft)}) / 2'),
      CalculationLine('Cb',blockCoefficient,'-',cbFormula),
      CalculationLine('Safety Margin (10%)',margin,'m','${n(maximumDraft)} * 0.10'),
      CalculationLine('Squat',squat,'m','${n(blockCoefficient)} * ${n(p.speedThroughWater)}^2 / 50'),
      CalculationLine('Heel Correction',heelCorrection,'m','0.008 * ${n(vessel.breadth)} * ABS(${n(p.heelDegrees)})'),
      CalculationLine('Density Correction',p.densityCorrection,'m','${n(p.densityCorrection)} (manual)'),
      CalculationLine('ENC ZOC Correction',chartAllowance,'m',chartFormula),
      CalculationLine('Safety Depth - unrounded',total,'m',
        '${n(maximumDraft)} + ${n(margin)} + ${n(squat)} + ${n(heelCorrection)} + ${n(p.densityCorrection)} + ${n(chartAllowance)}'),
      CalculationLine('Safety Depth',displayedDepth,'m','ROUNDUP(${n(total)}, 2)'),
    ];
  }
}

double calculateBlockCoefficient({required double displacementMT, required double waterDensity,
  required double lengthBP, required double breadth, required double meanDraft}) {
  if ([displacementMT,waterDensity,lengthBP,breadth,meanDraft].any((v) => !v.isFinite || v <= 0)) {
    throw const FormatException('Invalid Cb inputs.');
  }
  final cb = (displacementMT / waterDensity) / (lengthBP * breadth * meanDraft);
  if (!cb.isFinite || cb <= 0 || cb > 1) {
    throw const FormatException('Cb must be greater than 0 and no greater than 1; check displacement, density, dimensions and draughts.');
  }
  return cb;
}
