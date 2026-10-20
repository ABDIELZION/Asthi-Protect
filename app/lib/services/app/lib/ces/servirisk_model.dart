class RiskResult {
  final String level;
  final String referral;
  const RiskResult(this.level, this.referral);
}

class RiskModel {
  static RiskResult assess(Map<String, dynamic> gaitMetrics, List<String> gaitFlags,
      Map<String, int> questionnaire) {
    var qTotal = 0;
    questionnaire.forEach((_, v) => qTotal += v);
    final flagCount = gaitFlags.length;
    if (flagCount == 0 && qTotal <= 4) {
      return const RiskResult('low', 'No referral needed now. Re-screen in 6 months.');
    }
    if (flagCount <= 1 && qTotal <= 9) {
      return const RiskResult(
          'moderate', 'Refer to the nearest PHC for a clinical knee exam within 1 month.');
    }
    return const RiskResult(
        'high', 'Priority referral to PHC/orthopaedic OPD. Advise reduced load on the joint.');
  }
}
