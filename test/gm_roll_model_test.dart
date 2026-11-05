import 'package:flutter_test/flutter_test.dart';
import '../lib/gm_roll_model.dart';
void main() {
  GmRollEstimate calc({double b=30,double k=0.8,double t=180,int n=10}) =>
    GmRollEstimate.calculate(breadth:b,coefficient:k,elapsedSeconds:t,cycles:n);
  test('Reference example and mean period', () {
    expect(calc().periodSeconds,18);
    expect(calc().gm,closeTo(1.7777777778,1e-9));
  });
  test('Equivalent observations and period sensitivity', () {
    expect(calc(t:360,n:20).gm,calc().gm);
    expect(calc(t:360).gm,closeTo(calc().gm/4,1e-12));
    expect(calc(k:0.4).gm,closeTo(calc().gm/4,1e-12));
  });
  test('Invalid input is rejected', () {
    for(final v in [0.0,-1.0,double.nan,double.infinity]) {
      expect(()=>calc(b:v),throwsFormatException);
      expect(()=>calc(k:v),throwsFormatException);
      expect(()=>calc(t:v),throwsFormatException);
    }
    expect(()=>calc(n:0),throwsFormatException);
    expect(()=>calc(n:-1),throwsFormatException);
    expect(()=>calc(b:1e308),throwsFormatException);
  });
}
