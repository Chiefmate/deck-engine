import 'package:flutter_test/flutter_test.dart';
import '../lib/eco_speed_model.dart';
void main(){
 final departure=DateTime.utc(2026,11,2,12);
 EcoSpeedPlan plan(double hours,{double eco=12,double full=19})=>EcoSpeedPlan.calculate(distance:861,ecoSpeed:eco,fullSpeed:full,departure:departure,arrival:departure.add(Duration(microseconds:(hours*3600000000).round())));
 test('Workbook example conserves distance and time',(){final r=plan(52);expect(r.ecoHours,closeTo(18.142857142857,1e-9));expect(r.fullHours,closeTo(33.857142857143,1e-9));expect(r.ecoDistance+r.fullDistance,closeTo(861,1e-9));expect(r.ecoHours+r.fullHours,52);});
 test('Impossible early arrival rejected',(){expect(()=>plan(40),throwsFormatException);});
 test('Excess time rejected instead of negative full time',(){expect(()=>plan(80),throwsFormatException);});
 test('Equal or inverted speeds rejected',(){expect(()=>plan(52,eco:19),throwsFormatException);expect(()=>plan(52,eco:20),throwsFormatException);});
 test('Past arrival rejected',(){expect(()=>plan(-1),throwsFormatException);});
 test('Eco-only boundary',(){final r=plan(861/12);expect(r.fullHours,closeTo(0,1e-9));});
 test('Full-only boundary',(){final r=plan(861/19);expect(r.ecoHours,closeTo(0,1e-8));});
 test('Invalid speeds rejected',(){for(final v in [0.0,-1.0,double.nan,double.infinity]){expect(()=>plan(52,eco:v),throwsFormatException);}});
}
