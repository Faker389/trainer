import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/dates.dart';
import '../data/models.dart';
import '../data/store.dart';

/// Selected app theme; updated on sign-in and by the account tab toggle.
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

/// When set, the whole app runs on this in-memory store ("Wypróbuj demo" / platforms
/// without Firebase). Cleared by "Wyjdź z trybu demo" on the account tab.
final demoStoreOverride = ValueNotifier<AppStore?>(null);

ThemeMode themeModeFromStore(String name) => switch (name) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

/// Theme-aware shades — use instead of hard-coded `Colors.whiteNN`.
extension AppShades on BuildContext {
  /// `onSurface` at the given opacity: readable in both light and dark mode.
  Color shade([double alpha = 0.6]) =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: alpha);

  /// Subtle fill for icons, badges and separators.
  Color faintFill([double alpha = 0.06]) =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: alpha);
}

/// One-shot fade + slide-up entrance; use `index` for a staggered effect.
class FadeSlide extends StatelessWidget {
  final Widget child;

  /// Stagger position; each step adds ~45 ms of delay.
  final int index;
  const FadeSlide({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    const animMs = 380, stepMs = 45, maxSteps = 8;
    final delay = math.min(index, maxSteps) * stepMs;
    final total = animMs + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

class CategoryAvatar extends StatelessWidget {
  final MuscleCategory category;
  const CategoryAvatar(this.category, {super.key});

  static const _icons = {
    MuscleCategory.chest: Icons.fitness_center,
    MuscleCategory.back: Icons.rowing,
    MuscleCategory.legs: Icons.directions_run,
    MuscleCategory.glutes: Icons.sports_gymnastics,
    MuscleCategory.shoulders: Icons.accessibility_new,
    MuscleCategory.biceps: Icons.sports_martial_arts,
    MuscleCategory.triceps: Icons.sports_handball,
    MuscleCategory.forearms: Icons.back_hand,
    MuscleCategory.core: Icons.self_improvement,
    MuscleCategory.calves: Icons.directions_walk,
    MuscleCategory.cardio: Icons.monitor_heart,
  };

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: category.color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(_icons[category] ?? Icons.fitness_center, color: category.color, size: 22),
      );
}

class SectionHeader extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionHeader(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Row(children: [
        Container(
          width: 4,
          height: 16,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(2)),
        ),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyHint(this.text, {super.key, this.icon = Icons.info_outline});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 18),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.shade(), height: 1.45)),
        ]),
      );
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  const StatCard(this.label, this.value, {super.key, this.caption});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.shade(0.54), fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            if (caption != null)
              Text(caption!,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.shade(0.38), fontSize: 11)),
          ]),
        ),
      );
}

/// Number input with -/+ buttons (FitNotes-style).
class NumberStepper extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final double step;
  final bool decimal;
  const NumberStepper({super.key, required this.label, required this.controller, required this.step, this.decimal = false});

  void _bump(double delta) {
    final v = math.max(0.0, (parseNum(controller.text) ?? 0) + delta);
    controller.text = decimal ? fmtNum(v) : v.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Card(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(color: context.shade(), fontSize: 12, fontWeight: FontWeight.w600)),
            Row(children: [
              IconButton.filledTonal(
                onPressed: () => _bump(-step),
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(backgroundColor: scheme.surfaceContainerHighest),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(decimal: decimal),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: '0',
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => _bump(step),
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(backgroundColor: scheme.surfaceContainerHighest),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class SimpleLineChart extends StatelessWidget {
  final List<(DateTime, double)> points;
  final Color color;
  const SimpleLineChart({super.key, required this.points, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 220,
        width: double.infinity,
        child: CustomPaint(painter: _LineChartPainter(points, color, Theme.of(context).colorScheme.onSurface)),
      );
}

void _paintText(Canvas canvas, String s, Offset at, double width, TextAlign align, Color color) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(minWidth: width, maxWidth: width);
  tp.paint(canvas, at);
}

class _LineChartPainter extends CustomPainter {
  final List<(DateTime, double)> points;
  final Color color, textColor;
  _LineChartPainter(this.points, this.color, this.textColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const left = 48.0, right = 12.0, top = 8.0, bottom = 24.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    var minY = points.map((p) => p.$2).reduce(math.min);
    var maxY = points.map((p) => p.$2).reduce(math.max);
    if (maxY - minY < 1e-9) {
      minY -= 1;
      maxY += 1;
    }
    final pad = (maxY - minY) * 0.1;
    minY = math.max(0, minY - pad);
    maxY += pad;
    final t0 = points.first.$1.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.$1.millisecondsSinceEpoch.toDouble();
    double x(DateTime t) => t1 == t0 ? left + w / 2 : left + (t.millisecondsSinceEpoch - t0) / (t1 - t0) * w;
    double y(double v) => top + (1 - (v - minY) / (maxY - minY)) * h;

    final grid = Paint()
      ..color = textColor.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final v = minY + (maxY - minY) * i / 4;
      canvas.drawLine(Offset(left, y(v)), Offset(size.width - right, y(v)), grid);
      _paintText(canvas, fmtNum(v, 1), Offset(0, y(v) - 7), left - 6, TextAlign.right, textColor);
    }
    _paintText(canvas, formatShortDate(points.first.$1), Offset(left, size.height - bottom + 6), 60, TextAlign.left,
        textColor);
    if (points.length > 1) {
      _paintText(canvas, formatShortDate(points.last.$1), Offset(size.width - right - 60, size.height - bottom + 6), 60,
          TextAlign.right, textColor);
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(points[i].$1), y(points[i].$2));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke);
    final dot = Paint()..color = color;
    for (final p in points) {
      canvas.drawCircle(Offset(x(p.$1), y(p.$2)), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.points != points || old.color != color;
}

class SimpleBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;
  const SimpleBarChart({super.key, required this.values, required this.labels, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 180,
        width: double.infinity,
        child: CustomPaint(painter: _BarChartPainter(values, labels, color, Theme.of(context).colorScheme.onSurface)),
      );
}

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color, textColor;
  _BarChartPainter(this.values, this.labels, this.color, this.textColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const top = 18.0, bottom = 22.0;
    final maxV = math.max(values.reduce(math.max), 1e-9);
    final slot = size.width / values.length;
    final h = size.height - top - bottom;
    final paint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final bh = values[i] / maxV * h;
      final rect = Rect.fromLTWH(i * slot + slot * 0.18, top + h - bh, slot * 0.64, bh);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
      if (values[i] > 0) {
        _paintText(canvas, _compact(values[i]), Offset(i * slot, top + h - bh - 15), slot, TextAlign.center, textColor);
      }
      _paintText(canvas, labels[i], Offset(i * slot, size.height - bottom + 6), slot, TextAlign.center, textColor);
    }
  }

  String _compact(double v) => v >= 10000 ? '${fmtNum(v / 1000, 0)}k' : v >= 1000 ? '${fmtNum(v / 1000, 1)}k' : fmtNum(v, 0);

  @override
  bool shouldRepaint(_BarChartPainter old) => old.values != values;
}
