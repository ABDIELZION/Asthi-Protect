import 'dart:math';

class Point2 {
  final double x;
  final double y;
  const Point2(this.x, this.y);
}

double angleBetween(Point2 a, Point2 b, Point2 c) {
  final bax = a.x - b.x;
  final bay = a.y - b.y;
  final bcx = c.x - b.x;
  final bcy = c.y - b.y;
  final denom = sqrt(bax * bax + bay * bay) * sqrt(bcx * bcx + bcy * bcy);
  if (denom < 1e-9) return double.nan;
  final cosang = ((bax * bcx + bay * bcy) / denom).clamp(-1.0, 1.0);
  return acos(cosang) * 180 / pi;
}

class FrameSample {
  final double timeS;
  final double? kneeLeft;
  final double? kneeRight;
  final double? hipLeft;
  final double? hipRight;
  final double? trunkLean;
  final double? reachLeft;
  final double? reachRight;

  const FrameSample({
    required this.timeS,
    this.kneeLeft,
    this.kneeRight,
    this.hipLeft,
    this.hipRight,
    this.trunkLean,
    this.reachLeft,
    this.reachRight,
  });
}

class GaitSession {
  final List<FrameSample> frames = [];

  void add(FrameSample f) => frames.add(f);

  void clear() => frames.clear();

  List<double> _series(double? Function(FrameSample) pick) =>
      frames.map(pick).whereType<double>().toList();

  List<double> _smooth(List<double> v, int window) {
    if (v.length < window || window < 2) return List.of(v);
    final out = List<double>.filled(v.length, 0);
    final half = window ~/ 2;
    for (var i = 0; i < v.length; i++) {
      final lo = max(0, i - half);
      final hi = min(v.length, i + half + 1);
      var s = 0.0;
      for (var j = lo; j < hi; j++) {
        s += v[j];
      }
      out[i] = s / (hi - lo);
    }
    return out;
  }

  List<int> _peaks(List<double> v, int minDistance, double minProminence) {
    final raw = <int>[];
    for (var i = 1; i < v.length - 1; i++) {
      if (v[i] >= v[i - 1] && v[i] > v[i + 1]) {
        final lo = max(0, i - minDistance);
        final hi = min(v.length, i + minDistance + 1);
        var leftMin = double.infinity;
        var rightMin = double.infinity;
        for (var j = lo; j <= i; j++) {
          leftMin = min(leftMin, v[j]);
        }
        for (var j = i; j < hi; j++) {
          rightMin = min(rightMin, v[j]);
        }
        if (v[i] - max(leftMin, rightMin) >= minProminence) raw.add(i);
      }
    }
    final merged = <int>[];
    for (final p in raw) {
      if (merged.isNotEmpty && p - merged.last < minDistance) {
        if (v[p] > v[merged.last]) merged[merged.length - 1] = p;
      } else {
        merged.add(p);
      }
    }
    return merged;
  }

  List<double> _stepTimes(bool left) {
    final reach = _smooth(_series((f) => left ? f.reachLeft : f.reachRight), 5);
    if (reach.length < 10) return const [];
    final times = <double>[];
    for (final f in frames) {
      final r = left ? f.reachLeft : f.reachRight;
      if (r != null) times.add(f.timeS);
    }
    if (times.length != reach.length) return const [];
    final span = reach.reduce(max) - reach.reduce(min);
    final prom = max(0.02, 0.25 * span);
    final idx = _peaks(reach, max(3, (reach.length * 0.15).round()), prom);
    return idx.map((i) => times[i]).toList();
  }

  double _kneeRom(List<double> knee, List<double> strikes) {
    final sm = _smooth(knee, 5);
    if (strikes.length > 1) {
      final roms = <double>[];
      for (var i = 0; i < strikes.length - 1; i++) {
        final a = strikes[i];
        final b = strikes[i + 1];
        final seg = <double>[];
        for (var j = 0; j < frames.length; j++) {
          final v = sm.length == frames.length ? sm[j] : null;
          if (v != null && frames[j].timeS >= a && frames[j].timeS <= b) seg.add(v);
        }
        if (seg.length >= 3) roms.add(seg.reduce(max) - seg.reduce(min));
      }
      if (roms.isNotEmpty) return roms.reduce((a, b) => a + b) / roms.length;
    }
    if (sm.isEmpty) return 0;
    return sm.reduce(max) - sm.reduce(min);
  }

  Map<String, dynamic> metrics() {
    if (frames.length < 10) return {};
    final duration = frames.last.timeS - frames.first.timeS;
    final stepsL = _stepTimes(true);
    final stepsR = _stepTimes(false);
    final kneeL = _series((f) => f.kneeLeft);
    final kneeR = _series((f) => f.kneeRight);
    final lean = _series((f) => f.trunkLean);
    final romL = _kneeRom(kneeL, stepsL);
    final romR = _kneeRom(kneeR, stepsR);
    final m = <String, dynamic>{
      'duration_s': double.parse(duration.toStringAsFixed(2)),
      'steps_left': stepsL.length,
      'steps_right': stepsR.length,
      'cadence_spm': duration > 0
          ? double.parse((((stepsL.length + stepsR.length) / duration) * 60).toStringAsFixed(1))
          : null,
      'knee_rom_left_deg': double.parse(romL.toStringAsFixed(1)),
      'knee_rom_right_deg': double.parse(romR.toStringAsFixed(1)),
    };
    if (romL > 0 && romR > 0) {
      m['knee_rom_asymmetry_pct'] =
          double.parse((((romL - romR).abs() / (0.5 * (romL + romR))) * 100).toStringAsFixed(1));
    }
    if (lean.isNotEmpty) {
      m['trunk_lean_mean_deg'] =
          double.parse((lean.reduce((a, b) => a + b) / lean.length).toStringAsFixed(1));
    }
    return m;
  }

  List<String> flags(Map<String, dynamic> m) {
    final out = <String>[];
    final romL = (m['knee_rom_left_deg'] ?? 0).toDouble();
    final romR = (m['knee_rom_right_deg'] ?? 0).toDouble();
    if (romL > 0 && romL < 45) out.add('reduced knee range of motion (left: $romL deg)');
    if (romR > 0 && romR < 45) out.add('reduced knee range of motion (right: $romR deg)');
    final asym = (m['knee_rom_asymmetry_pct'] ?? 0).toDouble();
    if (asym > 15) out.add('left-right knee asymmetry $asym%');
    final cad = (m['cadence_spm'] ?? 0).toDouble();
    if (cad > 0 && cad < 90) out.add('low cadence ($cad steps/min)');
    final lean = (m['trunk_lean_mean_deg'] ?? 0).toDouble();
    if (lean > 10) out.add('forward trunk lean ($lean deg)');
    return out;
  }
}
