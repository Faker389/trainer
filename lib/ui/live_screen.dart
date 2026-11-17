import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mlkit;
import 'package:trainer_engine/trainer_engine.dart';

import '../data/dates.dart';
import '../data/models.dart';
import 'report_screen.dart';
import 'skeleton_painter.dart';

/// Camera -> ML Kit pose (BlazePose, 33 points) -> trainer_engine -> skeleton overlay + feedback.
class LiveScreen extends StatefulWidget {
  final ExerciseDefinition exercise;
  final CameraDescription camera;
  final ResolutionPreset resolution;
  final bool accurateModel;
  final bool voice;

  /// Logbook exercise the reps can be saved to from the report.
  final Exercise? logExercise;
  const LiveScreen({
    super.key,
    required this.exercise,
    required this.camera,
    required this.resolution,
    required this.accurateModel,
    required this.voice,
    this.logExercise,
  });

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  CameraController? _controller;
  late final mlkit.PoseDetector _detector;
  late final ExerciseAnalyzer _analyzer;
  final _tts = FlutterTts();
  final _clock = Stopwatch()..start();
  bool _busy = false;
  bool _closing = false;
  String? _error;
  String? _frameError;
  LiveState? _state;
  double? _brightness;
  double _lastBrightnessAt = double.negativeInfinity;

  bool get _front => widget.camera.lensDirection == CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _detector = mlkit.PoseDetector(
      options: mlkit.PoseDetectorOptions(
        model: widget.accurateModel ? mlkit.PoseDetectionModel.accurate : mlkit.PoseDetectionModel.base,
        mode: mlkit.PoseDetectionMode.stream,
      ),
    );
    _analyzer = ExerciseAnalyzer(
      widget.exercise,
      candidates: exercises.containsKey(widget.exercise.id) ? exercises.values.toList() : null,
    );
    if (widget.voice) _tts.setLanguage('pl-PL');
    _startCamera();
  }

  Future<void> _startCamera() async {
    final controller = CameraController(
      widget.camera,
      widget.resolution,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    try {
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.startImageStream(_onImage);
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = e.description ?? e.code);
      return;
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    _closing = true;
    final c = _controller;
    _controller = null;
    if (c != null) {
      if (c.value.isStreamingImages) c.stopImageStream().catchError((_) {});
      c.dispose();
    }
    _detector.close();
    _tts.stop();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _onImage(CameraImage image) async {
    if (_busy || _closing) return;
    _busy = true;
    try {
      final rotation = _rotation();
      final input = _inputImage(image, rotation);
      if (input == null) return;
      final ts = _clock.elapsedMicroseconds / 1000;
      if (ts - _lastBrightnessAt > 500) {
        _lastBrightnessAt = ts;
        _brightness = _meanLuma(image);
      }
      final poses = await _detector.processImage(input);
      if (_closing) return;
      final inferenceMs = _clock.elapsedMicroseconds / 1000 - ts;

      // On Android ML Kit returns coordinates in the rotated (upright) image; on iOS frames are already upright.
      final turned = Platform.isAndroid && (rotation == 90 || rotation == 270);
      final w = (turned ? image.height : image.width).toDouble();
      final h = (turned ? image.width : image.height).toDouble();
      final frame = _toPoseFrame(poses.firstOrNull, ts, w, h, inferenceMs);
      final state = _analyzer.processFrame(frame);
      final voice = state.feedback?.voice;
      if (widget.voice && voice != null) _tts.speak(voice);
      if (mounted) {
        setState(() {
          _state = state;
          _frameError = null;
        });
      }
    } catch (e) {
      debugPrint('pose frame failed: $e');
      if (mounted && !_closing) setState(() => _frameError = '$e');
    } finally {
      _busy = false;
    }
  }

  int _rotation() {
    final sensor = widget.camera.sensorOrientation;
    if (Platform.isIOS) return sensor;
    final device = _orientations[_controller?.value.deviceOrientation ?? DeviceOrientation.portraitUp] ?? 0;
    return _front ? (sensor + device) % 360 : (sensor - device + 360) % 360;
  }

  mlkit.InputImage? _inputImage(CameraImage image, int rotation) {
    final rot = mlkit.InputImageRotationValue.fromRawValue(rotation);
    if (rot == null) return null;
    final size = Size(image.width.toDouble(), image.height.toDouble());
    if (Platform.isAndroid) {
      // ML Kit's Android plugin only accepts NV21/YV12, while CameraX always streams YUV_420_888.
      final bytes = image.planes.length == 1 ? image.planes.first.bytes : _yuv420ToNv21(image);
      return mlkit.InputImage.fromBytes(
        bytes: bytes,
        metadata: mlkit.InputImageMetadata(
            size: size, rotation: rot, format: mlkit.InputImageFormat.nv21, bytesPerRow: image.width),
      );
    }
    final format = mlkit.InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null) return null;
    return mlkit.InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: mlkit.InputImageMetadata(
          size: size, rotation: rot, format: format, bytesPerRow: image.planes.first.bytesPerRow),
    );
  }

  /// Packs YUV_420_888 planes (any row/pixel stride) into a tightly packed NV21 buffer.
  static Uint8List _yuv420ToNv21(CameraImage image) {
    final w = image.width, h = image.height;
    final yPlane = image.planes[0], uPlane = image.planes[1], vPlane = image.planes[2];
    final cw = w ~/ 2, ch = h ~/ 2;
    final out = Uint8List(w * h + 2 * cw * ch);
    final yBytes = yPlane.bytes, yStride = yPlane.bytesPerRow;
    var o = 0;
    for (var r = 0; r < h; r++) {
      out.setRange(o, o + w, yBytes, r * yStride);
      o += w;
    }
    final uBytes = uPlane.bytes, vBytes = vPlane.bytes;
    final uvStride = uPlane.bytesPerRow, uvPixel = uPlane.bytesPerPixel ?? 1;
    for (var r = 0; r < ch; r++) {
      var i = r * uvStride;
      for (var c = 0; c < cw; c++, i += uvPixel) {
        out[o++] = vBytes[i];
        out[o++] = uBytes[i];
      }
    }
    return out;
  }

  /// Mean luma in [0, 1], sampled sparsely from the first plane.
  double? _meanLuma(CameraImage image) {
    final bytes = image.planes.first.bytes;
    if (bytes.isEmpty) return null;
    final bgra = image.format.group == ImageFormatGroup.bgra8888;
    final step = bgra ? 4 * 97 : 97;
    final limit = bgra ? bytes.length : image.width * image.height;
    var sum = 0, n = 0;
    for (var i = bgra ? 1 : 0; i < limit && i < bytes.length; i += step) {
      sum += bytes[i];
      n++;
    }
    return n == 0 ? null : sum / n / 255;
  }

  PoseFrame _toPoseFrame(mlkit.Pose? pose, double ts, double w, double h, double inferenceMs) {
    final landmarks = <String, Landmark>{};
    var visSum = 0.0;
    if (pose != null) {
      for (final name in landmarkNames) {
        final l = pose.landmarks[mlkit.PoseLandmarkType.values.byName(name)];
        if (l == null) continue;
        final visibility = l.likelihood.clamp(0.0, 1.0);
        landmarks[name] = Landmark(x: l.x / w, y: l.y / h, z: l.z / w, visibility: visibility);
        visSum += visibility;
      }
    }
    return PoseFrame(
      timestamp: ts,
      landmarks: landmarks,
      modelConfidence: landmarks.isEmpty ? 0 : visSum / landmarks.length,
      cameraMetadata: CameraMetadata(
        width: w,
        height: h,
        // ML Kit sees the raw sensor image, so left/right are anatomical even for the front camera.
        mirrored: false,
        facing: _front ? CameraFacing.user : CameraFacing.environment,
        brightness: _brightness,
      ),
      source: 'mlkit-pose',
      inferenceMs: inferenceMs,
    );
  }

  Future<void> _endSet() async {
    _closing = true;
    final c = _controller;
    if (c != null && c.value.isStreamingImages) await c.stopImageStream().catchError((_) {});
    _tts.stop();
    final report = _analyzer.endSet();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ReportScreen(exercise: widget.exercise, report: report, logExercise: widget.logExercise),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final state = _state;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: _error != null
          ? Center(child: Text('Kamera niedostępna: $_error'))
          : controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CameraPreview(controller),
                          if (state != null)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: SkeletonPainter(
                                  pose: state.pose,
                                  aspect: state.aspect,
                                  mirror: _front,
                                  color: _statusColor(state.status),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (state != null) _Hud(state: state),
                    if (_frameError != null)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 90,
                        child: _Banner(text: 'Błąd detekcji: $_frameError', color: Colors.red.shade900),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.stop),
                        label: const Padding(padding: EdgeInsets.all(10), child: Text('Zakończ serię')),
                        onPressed: _endSet,
                      ),
                    ),
                  ],
                ),
    );
  }
}

Color _statusColor(AnalyzerStatus s) => switch (s) {
      AnalyzerStatus.analysing => const Color(0xFF10B981),
      AnalyzerStatus.calibrating => Colors.amber,
      AnalyzerStatus.paused => Colors.orange,
      AnalyzerStatus.noPerson => Colors.white54,
    };

Color _cueColor(FeedbackItem f) => switch (f.kind) {
      FeedbackKind.safety => Colors.red.shade700,
      FeedbackKind.technique => f.severity == Severity.high ? Colors.red.shade600 : Colors.orange.shade700,
      FeedbackKind.setup => Colors.blueGrey.shade700,
      FeedbackKind.rep || FeedbackKind.info => const Color(0xFF047857),
    };

const _metricLabels = {'ankleAngle': 'Kąt skokowy', 'trunkInclination': 'Pochylenie tułowia'};

String _metricValue(KeyMetric m) => m.unit == 'deg' ? '${m.value.round()}°' : fmtNum(m.value);

class _Hud extends StatelessWidget {
  final LiveState state;
  const _Hud({required this.state});

  @override
  Widget build(BuildContext context) {
    final cal = state.calibration;
    final analysing = state.status == AnalyzerStatus.analysing;
    final guidance = !analysing && cal.guidance.isNotEmpty ? cal.guidance.first : null;
    return Positioned(
      left: 12,
      right: 12,
      top: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Chip(label: 'Powtórzenia', value: '${state.repCount}'),
              const SizedBox(width: 8),
              if (state.setScore != null) _Chip(label: 'Ocena', value: '${state.setScore}'),
              const Spacer(),
              if (state.phaseLabel != null && state.phaseLabel!.isNotEmpty)
                _Chip(label: 'Faza', value: state.phaseLabel!),
            ],
          ),
          if (analysing && state.keyMetrics.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in state.keyMetrics.take(3))
                _Chip(label: _metricLabels[m.name] ?? m.label, value: _metricValue(m)),
            ]),
          ],
          if (!analysing && cal.progress > 0 && cal.progress < 1) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: cal.progress),
          ],
          if (guidance != null) _Banner(text: guidance, color: Colors.black87),
          for (final cue in state.visualCues)
            if (cue.text != guidance) _Banner(text: cue.text, color: _cueColor(cue)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  const _Chip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      );
}
