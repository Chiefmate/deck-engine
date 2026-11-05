class EcoSpeedPlan {
  final double ecoHours, fullHours, ecoDistance, fullDistance, totalHours;
  const EcoSpeedPlan._(this.ecoHours,this.fullHours,this.ecoDistance,this.fullDistance,this.totalHours);
  factory EcoSpeedPlan.calculate({required double distance,required double ecoSpeed,
    required double fullSpeed,required DateTime departure,required DateTime arrival}) {
    if ([distance,ecoSpeed,fullSpeed].any((v)=>!v.isFinite || v<=0)) {
      throw const FormatException('Enter positive finite distance and speeds.');
    }
    if (fullSpeed<=ecoSpeed) throw const FormatException('Full Speed must be greater than Eco Speed.');
    final hours=arrival.toUtc().difference(departure.toUtc()).inMicroseconds/3600000000;
    if (hours<=0) throw const FormatException('Arrival must be later than departure.');
    final minimum=distance/fullSpeed,maximum=distance/ecoSpeed;
    if (!minimum.isFinite || !maximum.isFinite) throw const FormatException('Values are outside the calculation range.');
    const tolerance=1e-9;
    if (hours<minimum-tolerance) throw FormatException('Not enough time: even Full Speed needs ${minimum.toStringAsFixed(2)} hours.');
    if (hours>maximum+tolerance) throw FormatException('Too much time for these two speeds: Eco Speed takes ${maximum.toStringAsFixed(2)} hours. A lower speed or waiting time is needed.');
    final eco=((fullSpeed*hours-distance)/(fullSpeed-ecoSpeed)).clamp(0.0,hours).toDouble();
    final full=hours-eco;
    if (![eco,full,eco*ecoSpeed,full*fullSpeed].every((v)=>v.isFinite)) throw const FormatException('Values are outside the calculation range.');
    return EcoSpeedPlan._(eco,full,eco*ecoSpeed,full*fullSpeed,hours);
  }
}
