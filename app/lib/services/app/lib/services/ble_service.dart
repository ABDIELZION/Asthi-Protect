import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const String bandNamePrefix = 'ASTHI';
final Guid bandServiceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
final Guid bandDataUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

class BandSample {
  final double emgRms;
  final double imuPitchDeg;
  final double micLevel;
  const BandSample(this.emgRms, this.imuPitchDeg, this.micLevel);
}

class BleService {
  BluetoothDevice? device;
  final _samples = StreamController<BandSample>.broadcast();
  Stream<BandSample> get samples => _samples.stream;
  StreamSubscription<List<int>>? _sub;

  Stream<List<ScanResult>> scan() {
    FlutterBluePlus.startScan(
        withNames: [bandNamePrefix], timeout: const Duration(seconds: 10));
    return FlutterBluePlus.onScanResults;
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<bool> connect(BluetoothDevice d) async {
    await d.connect(timeout: const Duration(seconds: 15));
    device = d;
    final services = await d.discoverServices();
    for (final s in services) {
      if (s.serviceUuid == bandServiceUuid) {
        for (final c in s.characteristics) {
          if (c.characteristicUuid == bandDataUuid) {
            await c.setNotifyValue(true);
            _sub = c.onValueReceived.listen(_parse);
            return true;
          }
        }
      }
    }
    return false;
  }

  void _parse(List<int> bytes) {
    if (bytes.length < 12) return;
    final bd = ByteData.sublistView(Uint8List.fromList(bytes));
    _samples.add(BandSample(
      bd.getFloat32(0, Endian.little),
      bd.getFloat32(4, Endian.little),
      bd.getFloat32(8, Endian.little),
    ));
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await device?.disconnect();
    device = null;
  }
}
