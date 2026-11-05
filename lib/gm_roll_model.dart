class GmRollEstimate {
  final double breadth, coefficient, elapsedSeconds, periodSeconds, gm;
  final int cycles;
  const GmRollEstimate._(this.breadth,this.coefficient,this.elapsedSeconds,this.cycles,this.periodSeconds,this.gm);
  factory GmRollEstimate.calculate({required double breadth,required double coefficient,
    required double elapsedSeconds,required int cycles}) {
    if ([breadth,coefficient,elapsedSeconds].any((v)=>!v.isFinite || v<=0) || cycles<=0) {
      throw const FormatException('Enter positive breadth, coefficient, elapsed time and whole-cycle count.');
    }
    final period=elapsedSeconds/cycles;
    final ratio=coefficient*breadth/period;
    final gm=ratio*ratio;
    if (!period.isFinite || period<=0 || !gm.isFinite || gm<=0) {
      throw const FormatException('Values are outside the calculation range.');
    }
    return GmRollEstimate._(breadth,coefficient,elapsedSeconds,cycles,period,gm);
  }
}
