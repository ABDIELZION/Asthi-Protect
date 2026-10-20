import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/screening.dart';
import '../services/ble_service.dart';

class BandScreen extends StatefulWidget {
  final void Function(BandSummary) onSummary;
  const BandScreen({super.key, required this.onSummary});

  @override
  State<BandScreen> createState() => _BandScreenState();
}

class _BandScreenState extends State<BandScreen> {
  final _ble = BleService();
  String _status = 'Scanning for band...';
  StreamSubscription<BandSample>? _sub;
  final _emg = <double>[];
  final _pitch = <double>[];
  final _mic = <double>[];
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final results = _ble.scan().listen((list) async {
      if (list.isEmpty || _connected) return;
      await _ble.stopScan();
      setState(() => _status = 'Connecting to ${list.first.device.platformName}...');
      final ok = await _ble.connect(list.first.device);
      setState(() {
        _connected = ok;
        _status = ok ? 'Connected. Collecting band data...' : 'Band found, data channel missing.';
      });
      if (ok) {
        _sub = _ble.samples.listen((s) {
          _emg.add(s.emgRms);
          _pitch.add(s.imuPitchDeg);
          _mic.add(s.micLevel);
        });
      }
    });
    await Future.delayed(const Duration(seconds: 12));
    await results.cancel();
    await _ble.stopScan();
    if (!_connected && mounted) setState(() => _status = 'No band found. Check it is on and nearby.');
  }

  @override
  void dispose() {
    if (_emg.isNotEmpty) {
      widget.onSummary(BandSummary(
        emgRmsMean: _emg.reduce((a, b) => a + b) / _emg.length,
        imuPitchRangeDeg: _pitch.isEmpty
            ? 0
            : _pitch.reduce((a, b) => a > b ? a : b) - _pitch.reduce((a, b) => a < b ? a : b),
        micLevelMean: _mic.reduce((a, b) => a + b) / _mic.length,
        sampleCount: _emg.length,
      ));
    }
    _sub?.cancel();
    _ble.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor band')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_connected ? Icons.bluetooth_connected : Icons.bluetooth_searching, size: 48),
            const SizedBox(height: 16),
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('${_emg.length} samples'),
          ],
        ),
      ),
    );
  }
}
