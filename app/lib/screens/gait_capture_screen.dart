import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../services/gait_metrics.dart';

class GaitCaptureScreen extends StatefulWidget {
  final GaitSession session;
  const GaitCaptureScreen({super.key, required this.session});

  @override
  State<GaitCaptureScreen> createState() => _GaitCaptureScreenState();
}

class _GaitCaptureScreenState extends State<GaitCaptureScreen> {
  CameraController? _controller;
  final _detector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  bool _recording = false;
  bool _busy = false;
  Pose? _pose;
  final _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    final cameras = await availableCameras();
    final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first);
    _controller = CameraController(back, ResolutionPreset.medium,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);
    await _controller!.initialize();
    await _controller!.startImageStream(_onFrame);
    if (mounted) setState(() {});
  }

  InputImage? _inputImage(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    final buffer = WriteBuffer();
    for (final plane in image.planes) {
      buffer.putUint8List(plane.bytes);
    }
    return InputImage.fromBytes(
      bytes: buffer.done().buffer.asUint8List(),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _controller == null) return;
    _busy = true;
    try {
      final input = _inputImage(image, _controller!.description);
      if (input == null) return;
      final poses = await _detector.processImage(input);
      if (poses.isEmpty) return;
      _pose = poses.first;
      if (_recording) {
        final sample = _sampleFrom(poses.first, _stopwatch.elapsedMilliseconds / 1000.0);
        widget.session.add(sample);
      }
      if (mounted) setState(() {});
    } finally {
      _busy = false;
    }
  }

  PoseLandmark? _lm(Pose pose, PoseLandmarkType t) {
    final l = pose.landmarks[t];
    if (l == null || l.likelihood < 0.5) return null;
    return l;
  }

  Point2 _p(PoseLandmark l) => Point2(l.x, l.y);

  FrameSample _sampleFrom(Pose pose, double t) {
    double? kneeL;
    double? kneeR;
    double? hipL;
    double? hipR;
    double? lean;
    double? reachL;
    double? reachR;
    final lHip = _lm(pose, PoseLandmarkType.leftHip);
    final rHip = _lm(pose, PoseLandmarkType.rightHip);
    final lKnee = _lm(pose, PoseLandmarkType.leftKnee);
    final rKnee = _lm(pose, PoseLandmarkType.rightKnee);
    final lAnkle = _lm(pose, PoseLandmarkType.leftAnkle);
    final rAnkle = _lm(pose, PoseLandmarkType.rightAnkle);
    final lSh = _lm(pose, PoseLandmarkType.leftShoulder);
    final rSh = _lm(pose, PoseLandmarkType.rightShoulder);
    if (lHip != null && lKnee != null && lAnkle != null) {
      kneeL = angleBetween(_p(lHip), _p(lKnee), _p(lAnkle));
      reachL = lAnkle.x - lHip.x;
    }
    if (rHip != null && rKnee != null && rAnkle != null) {
      kneeR = angleBetween(_p(rHip), _p(rKnee), _p(rAnkle));
      reachR = rAnkle.x - rHip.x;
    }
    if (lSh != null && lHip != null && lKnee != null) {
      hipL = angleBetween(_p(lSh), _p(lHip), _p(lKnee));
    }
    if (rSh != null && rHip != null && rKnee != null) {
      hipR = angleBetween(_p(rSh), _p(rHip), _p(rKnee));
    }
    if (lSh != null && rSh != null && lHip != null && rHip != null) {
      final dx = ((lSh.x + rSh.x) / 2) - ((lHip.x + rHip.x) / 2);
      final dy = ((lSh.y + rSh.y) / 2) - ((lHip.y + rHip.y) / 2);
      if (dx.abs() + dy.abs() > 1e-9) {
        lean = (atan2(dx.abs(), dy.abs())) * 180 / 3.141592653589793;
      }
    }
    return FrameSample(
        timeS: t,
        kneeLeft: kneeL,
        kneeRight: kneeR,
        hipLeft: hipL,
        hipRight: hipR,
        trunkLean: lean,
        reachLeft: reachL,
        reachRight: reachR);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Gait capture')),
      body: c == null || !c.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(c),
                if (_pose != null)
                  CustomPaint(painter: _PosePainter(_pose!, c.value.previewSize ?? Size.zero)),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () {
            setState(() {
              if (_recording) {
                _stopwatch.stop();
              } else {
                widget.session.clear();
                _stopwatch
                  ..reset()
                  ..start();
              }
              _recording = !_recording;
            });
          },
          child: Text(_recording
              ? 'Stop (${widget.session.frames.length} frames)'
              : 'Start recording'),
        ),
      ),
    );
  }
}

class _PosePainter extends CustomPainter {
  final Pose pose;
  final Size previewSize;
  _PosePainter(this.pose, this.previewSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (previewSize.width == 0) return;
    final sx = size.width / previewSize.height;
    final sy = size.height / previewSize.width;
    final dot = Paint()..color = const Color(0xFFE53935);
    for (final l in pose.landmarks.values) {
      if (l.likelihood < 0.5) continue;
      canvas.drawCircle(Offset(l.x * sx, l.y * sy), 4, dot);
    }
  }

  @override
  bool shouldRepaint(_PosePainter old) => true;
}
