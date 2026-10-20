class BandSummary {
  final double emgRmsMean;
  final double imuPitchRangeDeg;
  final double micLevelMean;
  final int sampleCount;

  const BandSummary({
    this.emgRmsMean = 0,
    this.imuPitchRangeDeg = 0,
    this.micLevelMean = 0,
    this.sampleCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'emg_rms_mean': emgRmsMean,
        'imu_pitch_range_deg': imuPitchRangeDeg,
        'mic_level_mean': micLevelMean,
        'sample_count': sampleCount,
      };

  factory BandSummary.fromJson(Map<String, dynamic> j) => BandSummary(
        emgRmsMean: (j['emg_rms_mean'] ?? 0).toDouble(),
        imuPitchRangeDeg: (j['imu_pitch_range_deg'] ?? 0).toDouble(),
        micLevelMean: (j['mic_level_mean'] ?? 0).toDouble(),
        sampleCount: j['sample_count'] ?? 0,
      );
}

class Screening {
  int? id;
  final DateTime createdAt;
  Map<String, dynamic> gaitMetrics;
  List<String> gaitFlags;
  Map<String, int> questionnaire;
  BandSummary band;
  String riskLevel;
  String referral;
  bool synced;

  Screening({
    this.id,
    DateTime? createdAt,
    Map<String, dynamic>? gaitMetrics,
    List<String>? gaitFlags,
    Map<String, int>? questionnaire,
    BandSummary? band,
    this.riskLevel = 'pending',
    this.referral = '',
    this.synced = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        gaitMetrics = gaitMetrics ?? {},
        gaitFlags = gaitFlags ?? [],
        questionnaire = questionnaire ?? {},
        band = band ?? const BandSummary();
}
