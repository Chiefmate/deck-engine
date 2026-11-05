import 'dart:math' as math;
import 'safety_depth_model.dart' show calculateBlockCoefficient;
import 'depth_accuracy.dart';

// Presentation only: never use formatted values as calculation inputs.
String ukcDisplay(double value) {
  final text = value.toStringAsFixed(2);
  return text == '-0.00' ? '0.00' : text;
}

class UkcInput {
  final double length, breadth, fore, aft, waterDensity, depth, tide, speed;
  final double heel, densityCorrection, swell;
  final double? maxDraft, displacement, manualCb, manualSquat, manualDepth;
  final String catzoc, depthBasis;
  final bool confined;
  const UkcInput({required this.length, required this.breadth,
    required this.fore, required this.aft, required this.waterDensity,
    required this.depth, required this.tide, required this.speed,
    required this.heel, required this.densityCorrection, required this.swell,
    required this.catzoc, required this.confined,
    this.maxDraft, this.displacement, this.manualCb, this.manualSquat,
    this.manualDepth, this.depthBasis = ''});
}

class UkcResult {
  final UkcInput input;
  final double mean, maximum, cb, squat, heelCorrection, staticUkc;
  final double? chartAllowance, calculatedUkc;
  final DateTime calculatedUtc;
  const UkcResult._(this.input, this.mean, this.maximum, this.cb, this.squat,
    this.heelCorrection, this.staticUkc, this.chartAllowance, this.calculatedUkc,
    this.calculatedUtc);
  bool get complete => calculatedUkc != null;
  bool get usesManualDepth => requiresManualDepthAllowance(input.catzoc);
  factory UkcResult.calculate(UkcInput p) {
    if ([p.length,p.breadth,p.fore,p.aft,p.waterDensity,p.depth]
        .any((x) => !x.isFinite || x <= 0) ||
        [p.speed,p.densityCorrection,p.swell].any((x) => !x.isFinite || x < 0) ||
        !p.tide.isFinite || !p.heel.isFinite || p.heel.abs() >= 90 ||
        !['A1','A2','B','C','D','U'].contains(p.catzoc)) {
      throw const FormatException('Check positive dimensions, drafts, density and depth. Speed and allowances must be non-negative; heel must be between -90 and 90 degrees.');
    }
    if (p.maxDraft != null && (!p.maxDraft!.isFinite || p.maxDraft! <= 0)) {
      throw const FormatException('Additional maximum draft must be positive or blank.');
    }
    if (p.manualSquat != null && (!p.manualSquat!.isFinite || p.manualSquat! < 0)) {
      throw const FormatException('Manual squat must be non-negative.');
    }
    if (p.manualDepth != null && (!p.manualDepth!.isFinite || p.manualDepth! < 0)) {
      throw const FormatException('Manual depth allowance must be non-negative.');
    }
    final mean = p.fore / 2 + p.aft / 2;
    final maximum = math.max(math.max(p.fore,p.aft),p.maxDraft ?? 0.0);
    final cb = p.manualCb ?? calculateBlockCoefficient(
      displacementMT: p.displacement ?? 0, waterDensity:p.waterDensity,
      lengthBP:p.length,breadth:p.breadth,meanDraft:mean);
    if (!cb.isFinite || cb <= 0 || cb > 1) {
      throw const FormatException('Cb must be greater than 0 and no greater than 1.');
    }
    final squat = p.manualSquat ?? cb * p.speed * p.speed / (p.confined ? 50 : 100);
    final heel = p.breadth / 2 * math.tan(p.heel.abs() * math.pi / 180);
    final staticUkc = p.depth + p.tide - maximum - p.densityCorrection;
    final missing = requiresManualDepthAllowance(p.catzoc) &&
      (p.manualDepth == null || p.depthBasis.trim().isEmpty);
    final chart = missing ? null : depthAccuracyAllowance(p.catzoc,p.depth,
      manual:p.manualDepth,basis:p.depthBasis);
    final ukc = chart == null ? null : staticUkc - chart - squat - heel - p.swell;
    if ([mean,maximum,cb,squat,heel,staticUkc,if(chart!=null)chart,if(ukc!=null)ukc]
        .any((x) => !x.isFinite || x.abs()>1e9)) {
      throw const FormatException('Values exceed the calculation range.');
    }
    return UkcResult._(p,mean,maximum,cb,squat,heel,staticUkc,chart,ukc,DateTime.now().toUtc());
  }
  double atSpeed(double stw) {
    if (!complete || input.manualSquat != null || !stw.isFinite || stw < 0) {
      throw const FormatException('Speed comparison requires automatic squat and a complete assessment.');
    }
    return staticUkc-chartAllowance!-heelCorrection-input.swell-cb*stw*stw/(input.confined?50:100);
  }
  List<String> get details => [
    'Mean Draft = (${ukcDisplay(input.fore)} + ${ukcDisplay(input.aft)}) / 2 = ${ukcDisplay(mean)} m',
    'Maximum Draft = MAX(${ukcDisplay(input.fore)}, ${ukcDisplay(input.aft)}, ${ukcDisplay(input.maxDraft ?? 0)}) = ${ukcDisplay(maximum)} m',
    input.manualCb != null ? 'Cb = ${ukcDisplay(cb)} (manual)' :
      'Cb = ${ukcDisplay(input.displacement!)} / (${ukcDisplay(input.waterDensity)} × ${ukcDisplay(input.length)} × ${ukcDisplay(input.breadth)} × ${ukcDisplay(mean)}) ≈ ${ukcDisplay(cb)}',
    input.manualSquat != null ? 'Squat = ${ukcDisplay(squat)} m (manual at ${ukcDisplay(input.speed)} kn STW)' :
      'Squat = ${ukcDisplay(cb)} × ${ukcDisplay(input.speed)}² / ${input.confined?50:100} ≈ ${ukcDisplay(squat)} m',
    'Heel = ${ukcDisplay(input.breadth)}/2 × tan(|${ukcDisplay(input.heel)}| × pi/180) ≈ ${ukcDisplay(heelCorrection)} m',
    'Static UKC = ${ukcDisplay(input.depth)} + (${ukcDisplay(input.tide)}) - ${ukcDisplay(maximum)} - ${ukcDisplay(input.densityCorrection)} ≈ ${ukcDisplay(staticUkc)} m',
    chartAllowance == null ? 'Depth allowance: missing; CATZOC ${input.catzoc}' :
      'Depth allowance = ${ukcDisplay(chartAllowance!)} m; CATZOC ${input.catzoc}${usesManualDepth ? '; manual basis: ${input.depthBasis}' : '; evaluated at charted depth ${ukcDisplay(input.depth)} m'}',
    if(complete) 'Calculated UKC = ${ukcDisplay(staticUkc)} - ${ukcDisplay(chartAllowance!)} - ${ukcDisplay(squat)} - ${ukcDisplay(heelCorrection)} - ${ukcDisplay(input.swell)} ≈ ${ukcDisplay(calculatedUkc!)} m',
  ];
}
