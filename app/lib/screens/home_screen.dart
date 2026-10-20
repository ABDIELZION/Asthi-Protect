import 'package:flutter/material.dart';

import '../models/screening.dart';
import '../services/gait_metrics.dart';
import '../services/storage.dart';
import 'band_screen.dart';
import 'gait_capture_screen.dart';
import 'questionnaire_screen.dart';
import 'report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _session = GaitSession();
  final _answers = <String, int>{};
  BandSummary _band = const BandSummary();
  List<Screening> _history = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await Storage.list();
    setState(() => _history = list);
  }

  @override
  Widget build(BuildContext context) {
    final unsynced = _history.where((s) => !s.synced).length;
    return Scaffold(
      appBar: AppBar(title: const Text('ASTHI-PROTECT')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.videocam),
            title: const Text('1. Record gait video'),
            subtitle: Text('${_session.frames.length} frames captured'),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => GaitCaptureScreen(session: _session))),
          ),
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('2. Sensor band'),
            subtitle: Text(_band.sampleCount > 0
                ? '${_band.sampleCount} samples'
                : 'not connected'),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        BandScreen(onSummary: (s) => _band = s))),
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('3. Symptom questions'),
            subtitle: Text('${_answers.length} answered'),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => QuestionnaireScreen(answers: _answers))),
          ),
          ListTile(
            leading: const Icon(Icons.summarize),
            title: const Text('4. Risk report'),
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ReportScreen(
                          session: _session, answers: _answers, band: _band)));
              _reload();
            },
          ),
          const Divider(),
          Text('Saved screenings (offline, $unsynced unsynced)',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          for (final s in _history)
            ListTile(
              dense: true,
              title: Text('${s.riskLevel} - ${s.createdAt.toLocal()}'),
              subtitle: Text(s.synced ? 'synced' : 'stored, will sync when online'),
            ),
        ],
      ),
    );
  }
}
