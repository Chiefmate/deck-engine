import 'package:flutter_test/flutter_test.dart';
import '../lib/eta_model.dart';

void main() {
  test('ETA = distance / speed', () {
    final start = DateTime.utc(2026,11,2,12);
    final r = EtaResult.calculateEta(distanceNM: 120,speedKnots: 12,departureUTC: start);
    expect(r.arrivalUTC,DateTime.utc(2026,11,2,22));
    expect(r.duration,const Duration(hours: 10));
  });
  test('Required average speed uses full available interval', () {
    final r = EtaResult.requiredSpeed(distanceNM: 302,departureUTC: DateTime.utc(2026,11,2,12),
      targetArrivalUTC: DateTime.utc(2026,11,3,12));
    expect(r.averageSpeedKnots,closeTo(302/24,1e-12));
    expect(r.requiredSpeedRounded,12.59);
  });
  test('Required speed does not round downward', () {
    final r = EtaResult.requiredSpeed(distanceNM: 100,departureUTC: DateTime.utc(2026,1,1),
      targetArrivalUTC: DateTime.utc(2026,1,1,9));
    expect(r.requiredSpeedRounded,11.12);
    expect(100/r.requiredSpeedRounded,lessThanOrEqualTo(9));
  });
  test('Port times are converted to UTC before calculating speed', () {
    final start = portTimeToUtc(DateTime.utc(2026,11,2,12),120);
    final end = portTimeToUtc(DateTime.utc(2026,11,2,18),240);
    final r = EtaResult.requiredSpeed(distanceNM: 60,departureUTC: start,targetArrivalUTC: end);
    expect(r.duration,const Duration(hours: 4)); expect(r.averageSpeedKnots,15);
  });
  test('Arrival day changes with port UTC offset', () {
    final r = EtaResult.calculateEta(distanceNM: 120,speedKnots: 12,
      departureUTC: DateTime.utc(2026,11,2,12));
    expect(utcToPortTime(r.arrivalUTC,180),DateTime.utc(2026,11,3,1));
  });
  test('Half-hour and quarter-hour offsets round trip', () {
    for (final offset in [-720,-210,0,330,345,840]) {
      final wall = DateTime.utc(2026,1,1,0,15);
      expect(utcToPortTime(portTimeToUtc(wall,offset),offset),wall);
    }
    expect(etaOffsetLabel(345),'UTC+05:45'); expect(etaOffsetLabel(-210),'UTC-03:30');
  });
  test('Year rollover and leap day are handled', () {
    final a = EtaResult.calculateEta(distanceNM: 48,speedKnots: 12,
      departureUTC: DateTime.utc(2026,12,31,22));
    expect(a.arrivalUTC,DateTime.utc(2027,1,1,2));
    final b = EtaResult.calculateEta(distanceNM: 48,speedKnots: 12,
      departureUTC: DateTime.utc(2028,2,28,22));
    expect(b.arrivalUTC,DateTime.utc(2028,2,29,2));
  });
  test('Target at or before departure is rejected', () {
    final start = DateTime.utc(2026,11,2,12);
    for (final end in [start,start.subtract(const Duration(minutes: 1))]) {
      expect(() => EtaResult.requiredSpeed(distanceNM: 10,departureUTC: start,
        targetArrivalUTC: end),throwsFormatException);
    }
  });
  test('Invalid distance and speed are rejected', () {
    final start = DateTime.utc(2026,11,2);
    for (final v in [0.0,-1.0,double.nan,double.infinity]) {
      expect(() => EtaResult.calculateEta(distanceNM: v,speedKnots: 12,departureUTC: start),throwsFormatException);
      expect(() => EtaResult.calculateEta(distanceNM: 120,speedKnots: v,departureUTC: start),throwsFormatException);
      expect(() => EtaResult.requiredSpeed(distanceNM: v,departureUTC: start,
        targetArrivalUTC: start.add(const Duration(hours: 1))),throwsFormatException);
    }
  });
  test('Formatting does not hide day rollover', () {
    expect(etaDateTime(DateTime.utc(2026,11,3,1,2,3)),'03.11.2026 01:02:03');
    expect(etaDuration(const Duration(days: 1,hours: 2,minutes: 3,seconds: 4)),'1 d 2 h 3 min 4 s');
  });
}
