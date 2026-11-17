import 'package:flutter/material.dart';
import 'package:trainer_engine/trainer_engine.dart';

/// Draws the engine's filtered pose: dots on joints, lines along [skeletonConnections].
class SkeletonPainter extends CustomPainter {
  /// Aspect-corrected landmarks from [LiveState.pose] (x in [0, aspect], y in [0, 1]).
  final Pose pose;
  final double aspect;

  /// True when the preview is shown mirrored (front camera), so the overlay must be flipped too.
  final bool mirror;
  final Color color;
  final double minConfidence;

  const SkeletonPainter({
    required this.pose,
    required this.aspect,
    required this.mirror,
    required this.color,
    this.minConfidence = 0.3,
  });

  Offset? _at(String name, Size size) {
    final p = pose[name];
    if (p == null || p.confidence < minConfidence) return null;
    final nx = p.x / aspect;
    return Offset((mirror ? 1 - nx : nx) * size.width, p.y * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bone = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in skeletonConnections) {
      final pa = _at(a, size), pb = _at(b, size);
      if (pa != null && pb != null) canvas.drawLine(pa, pb, bone);
    }
    final fill = Paint()..color = Colors.white;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final name in landmarkNames) {
      final p = _at(name, size);
      if (p == null) continue;
      canvas.drawCircle(p, 5, fill);
      canvas.drawCircle(p, 5, ring);
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter old) =>
      old.pose != pose || old.aspect != aspect || old.mirror != mirror || old.color != color;
}
