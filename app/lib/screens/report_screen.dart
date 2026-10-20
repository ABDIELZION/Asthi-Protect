import 'package:flutter/material.dart';

import '../models/screening.dart';
import '../services/gait_metrics.dart';
import '../services/risk_model.dart';
import '../services/storage.dart';

class ReportScreen extends StatelessWidget {
  final GaitSession session;
  final Map<String, int> answers;
  final BandSummary band;

  const ReportScreen({
    super.key,
    required this.session,
    required this.answers,
    required this.band,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = session.metrics();
    final flags = session.flags(metrics);
    final risk = RiskModel.assess(metrics, flags, answers);
    return Scaffold(
      appBar: AppBar(title: const Text('Screening report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: risk.level == 'high'
                ? Colors.red.shade50
                : risk.level == 'moderate'
                    ? Colors.orange.shade50
                    : Colors.green.shade50,
            child: ListTile(
              title: Text('Risk: ${risk.level.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(risk.referral),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Gait metrics', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final e in metrics.entries) Text('${e.key}: ${e.value}'),
          if (flags.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Screening flags', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final f in flags) Text('- $f'),
          ],
          if (band.sampleCount > 0) ...[
            const SizedBox(height: 12),
            const Text('Band data', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('samples: ${band.sampleCount}'),
            Text('EMG RMS mean: ${band.emgRmsMean.toStringAsFixed(3)}'),
            Text('IMU pitch range: ${band.imuPitchRangeDeg.toStringAsFixed(1)} deg'),
            Text('mic level mean: ${band.micLevelMean.toStringAsFixed(3)}'),
          ],
          const SizedBox(height: 12),
          const Text('Screening only - not a medical diagnosis.'),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () async {
            final s = Screening(
              gaitMetrics: metrics,
              gaitFlags: flags,
              questionnaire: Map.of(answers),
              band: band,
              riskLevel: risk.level,
              referral: risk.referral,
            );
            await Storage.insert(s);
            if (context.mounted) Navigator.of(context).pop(s);
          },
          child: const Text('Save screening'),
        ),
      ),
    );
  }
}
