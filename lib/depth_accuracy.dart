// Shared by UKC and Safety Depth. D/U never inherit category C.
bool requiresManualDepthAllowance(String category) => category == 'D' || category == 'U';
double depthAccuracyAllowance(String category, double depth,
    {double? manual, String? basis}) {
  if (!depth.isFinite || depth <= 0) {
    throw const FormatException('Enter a positive charted depth.');
  }
  switch (category) {
    case 'A1': return 0.5 + 0.01 * depth;
    case 'A2':
    case 'B': return 1 + 0.02 * depth;
    case 'C': return 2 + 0.05 * depth;
    case 'D':
    case 'U':
      if (manual == null || !manual.isFinite || manual < 0 ||
          basis == null || basis.trim().isEmpty) {
        throw const FormatException('Assessment incomplete: CATZOC D/U requires a justified manual depth allowance and its basis. Category C is not substituted.');
      }
      return manual;
    default: throw const FormatException('Select CATZOC.');
  }
}
