import 'package:flutter_test/flutter_test.dart';
import '../lib/ukc_model.dart';

UkcInput example({String cat='A1',double? manualDepth,String basis='',
  bool confined=true,double speed=3,double heel=0,double? manualSquat}) => UkcInput(
  length:131,breadth:30.1,fore:9,aft:9.3,waterDensity:1.025,
  depth:10,tide:0,speed:speed,heel:heel,densityCorrection:0,swell:0,
  catzoc:cat,confined:confined,displacement:33300,
  manualDepth:manualDepth,depthBasis:basis,manualSquat:manualSquat);
void main(){
  test('Screenshot example retains full calculation precision',(){
    final r=UkcResult.calculate(example());
    expect(r.cb,closeTo(0.9004538987326628,1e-12));
    expect(r.calculatedUkc,closeTo(-0.06208170177187994,1e-12));
    expect(r.details.last,endsWith('≈ -0.06 m'));
    expect(r.details.join('\n'),isNot(contains('Required residual')));
    expect(r.details.join('\n'),isNot(contains('Shortfall')));
    expect(r.details.join('\n'),isNot(matches(RegExp(r'\d+\.\d{3,}'))));
    expect(r.atSpeed(3),closeTo(r.calculatedUkc!,1e-12));
  });
  test('Only presentation is rounded; tiny negative values remain negative',(){
    expect(ukcDisplay(-0.0001),'0.00');
    expect(ukcDisplay(-0.0620817),'-0.06');
    expect(ukcDisplay(9),'9.00');
    final r=UkcResult.calculate(example());
    final before=r.calculatedUkc;
    r.details;
    expect(r.calculatedUkc,before);
  });
  test('D/U do not inherit C and require allowance plus basis',(){
    for(final cat in ['D','U']){
      for(final p in [example(cat:cat),example(cat:cat,manualDepth:3),example(cat:cat,basis:'Port assessment')]){
        final r=UkcResult.calculate(p);
        expect(r.calculatedUkc,isNull);
        expect(()=>r.atSpeed(3),throwsFormatException);
      }
      expect(UkcResult.calculate(example(cat:cat,manualDepth:3,basis:'Port assessment')).chartAllowance,3);
    }
  });
  test('Squat scales with speed and water type; heel remains symmetric',(){
    final r=UkcResult.calculate(example());
    expect(UkcResult.calculate(example(speed:6)).squat,closeTo(r.squat*4,1e-12));
    expect(UkcResult.calculate(example(confined:false)).squat,closeTo(r.squat/2,1e-12));
    expect(UkcResult.calculate(example(heel:-1)).heelCorrection,UkcResult.calculate(example(heel:1)).heelCorrection);
    expect(UkcResult.calculate(example(speed:0)).squat,0);
  });
  test('Manual squat disables speed extrapolation',(){
    final r=UkcResult.calculate(example(manualSquat:0.2));
    expect(r.squat,0.2);
    expect(()=>r.atSpeed(5),throwsFormatException);
  });
  test('Invalid values rejected',(){
    for(final speed in [-1.0,double.nan,double.infinity]){
      expect(()=>UkcResult.calculate(example(speed:speed)),throwsFormatException);
    }
    expect(()=>UkcResult.calculate(example(heel:90)),throwsFormatException);
    expect(()=>UkcResult.calculate(example(cat:'X')),throwsFormatException);
  });
}
