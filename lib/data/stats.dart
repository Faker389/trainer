import 'dart:math' as math;

import 'dates.dart';
import 'models.dart';

/// Epley estimate of the one-rep max.
double epley1rm(double weight, int reps) {
  if (weight <= 0 || reps <= 0) return 0;
  return reps == 1 ? weight : weight * (1 + reps / 30);
}

class DaySummary {
  final String date;
  final List<WorkoutSet> sets;
  DaySummary(this.date, this.sets);

  DateTime get day => parseDateKey(date);
  double get maxWeight => sets.fold(0.0, (m, s) => math.max(m, s.weight));
  double get bestE1rm => sets.fold(0.0, (m, s) => math.max(m, epley1rm(s.weight, s.reps)));
  double get volume => sets.fold(0.0, (a, s) => a + s.volume);
  int get totalReps => sets.fold(0, (a, s) => a + s.reps);
  int get maxReps => sets.fold(0, (m, s) => math.max(m, s.reps));
  int get maxSeconds => sets.fold(0, (m, s) => math.max(m, s.seconds));
  int get totalSeconds => sets.fold(0, (a, s) => a + s.seconds);
  double get distance => sets.fold(0.0, (a, s) => a + s.distance);
}

class ExerciseStats {
  final Exercise exercise;

  /// Chronological.
  final List<WorkoutSet> sets;
  final List<DaySummary> days;

  /// Sets that were a personal record at the time they were done.
  final Set<String> prIds;

  /// Heaviest set done for at least N reps (N = 1..12).
  final Map<int, WorkoutSet> repRecords;
  final WorkoutSet? bestE1rmSet, heaviestSet, mostRepsSet, longestSet, farthestSet;

  const ExerciseStats({
    required this.exercise,
    required this.sets,
    required this.days,
    required this.prIds,
    required this.repRecords,
    this.bestE1rmSet,
    this.heaviestSet,
    this.mostRepsSet,
    this.longestSet,
    this.farthestSet,
  });

  double get bestE1rm => bestE1rmSet == null ? 0 : epley1rm(bestE1rmSet!.weight, bestE1rmSet!.reps);
  double get totalVolume => sets.fold(0.0, (a, s) => a + s.volume);
  int get totalReps => sets.fold(0, (a, s) => a + s.reps);
}

ExerciseStats computeStats(Exercise ex, List<WorkoutSet> input) {
  final sets = [...input]..sort(compareSets);
  final prIds = <String>{};
  final bestByReps = <int, double>{};
  final previous = <WorkoutSet>[];
  var maxSeconds = 0;
  var maxDistance = 0.0;
  WorkoutSet? bestE1rm, heaviest, mostReps, longest, farthest;

  for (final s in sets) {
    switch (ex.kind) {
      case ExerciseKind.weightReps:
        if (s.weight > 0 && s.reps > 0) {
          var prev = 0.0;
          bestByReps.forEach((r, w) {
            if (r >= s.reps) prev = math.max(prev, w);
          });
          if (s.weight > prev) prIds.add(s.id);
          bestByReps[s.reps] = math.max(bestByReps[s.reps] ?? 0, s.weight);
        }
      case ExerciseKind.bodyweight:
        if (s.reps > 0) {
          var prev = 0;
          for (final p in previous) {
            if (p.weight >= s.weight) prev = math.max(prev, p.reps);
          }
          if (s.reps > prev) prIds.add(s.id);
        }
      case ExerciseKind.duration:
        if (s.seconds > maxSeconds) {
          prIds.add(s.id);
          maxSeconds = s.seconds;
        }
      case ExerciseKind.cardio:
        if (s.distance > 0 && s.distance > maxDistance) {
          prIds.add(s.id);
          maxDistance = s.distance;
        } else if (s.distance == 0 && s.seconds > maxSeconds) {
          prIds.add(s.id);
        }
        maxSeconds = math.max(maxSeconds, s.seconds);
    }
    previous.add(s);

    if (epley1rm(s.weight, s.reps) > (bestE1rm == null ? 0 : epley1rm(bestE1rm.weight, bestE1rm.reps))) bestE1rm = s;
    if (s.weight > (heaviest?.weight ?? 0)) heaviest = s;
    if (s.reps > (mostReps?.reps ?? 0)) mostReps = s;
    if (s.seconds > (longest?.seconds ?? 0)) longest = s;
    if (s.distance > (farthest?.distance ?? 0)) farthest = s;
  }

  final repRecords = <int, WorkoutSet>{};
  if (ex.kind == ExerciseKind.weightReps) {
    for (var r = 1; r <= 12; r++) {
      for (final s in sets) {
        if (s.reps >= r && s.weight > 0 && s.weight > (repRecords[r]?.weight ?? 0)) repRecords[r] = s;
      }
    }
  }

  final byDay = <String, List<WorkoutSet>>{};
  for (final s in sets) {
    byDay.putIfAbsent(s.date, () => []).add(s);
  }

  return ExerciseStats(
    exercise: ex,
    sets: sets,
    days: [for (final e in byDay.entries) DaySummary(e.key, e.value)],
    prIds: prIds,
    repRecords: repRecords,
    bestE1rmSet: bestE1rm,
    heaviestSet: heaviest,
    mostRepsSet: mostReps,
    longestSet: longest,
    farthestSet: farthest,
  );
}

String formatSet(Exercise ex, WorkoutSet s) => switch (ex.kind) {
      ExerciseKind.weightReps => '${fmtNum(s.weight)} kg × ${s.reps}',
      ExerciseKind.bodyweight => s.weight > 0 ? '${s.reps} powt. (+${fmtNum(s.weight)} kg)' : '${s.reps} powt.',
      ExerciseKind.duration => fmtDuration(s.seconds),
      ExerciseKind.cardio => [
          if (s.distance > 0) '${fmtNum(s.distance)} km',
          if (s.seconds > 0) fmtDuration(s.seconds),
        ].join(' · '),
    };
