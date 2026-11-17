import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/dates.dart';
import '../data/models.dart';
import '../data/stats.dart';
import '../data/store.dart';
import 'exercise_screen.dart';
import 'widgets.dart';

class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final sets = store.allSets;
    if (sets.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Postępy')),
        body: const EmptyHint('Zapisz pierwszy trening, a tutaj pojawią się statystyki, rekordy i wykresy.',
            icon: Icons.insights),
      );
    }
    final now = today();
    final weekStart = startOfWeek(now);
    final weekKey = dateKey(weekStart);
    final monthKey = dateKey(DateTime(now.year, now.month));
    final dates = store.workoutDates;
    final setsPerDay = <String, int>{};
    for (final s in sets) {
      setsPerDay[s.date] = (setsPerDay[s.date] ?? 0) + 1;
    }

    final weekVolumes = <double>[];
    final weekLabels = <String>[];
    for (var i = 7; i >= 0; i--) {
      final start = DateTime(weekStart.year, weekStart.month, weekStart.day - 7 * i);
      final from = dateKey(start), to = dateKey(DateTime(start.year, start.month, start.day + 7));
      weekVolumes.add(sets
          .where((s) => s.date.compareTo(from) >= 0 && s.date.compareTo(to) < 0)
          .fold(0.0, (a, s) => a + s.volume));
      weekLabels.add(formatShortDate(start));
    }

    final exercisesUsed = [for (final id in {for (final s in sets) s.exerciseId}) store.exercise(id)].whereType<Exercise>();
    final cutoff = dateKey(now.subtract(const Duration(days: 30)));
    final recentPrs = <(Exercise, WorkoutSet, int)>[];
    final best1rm = <(Exercise, ExerciseStats)>[];
    for (final ex in exercisesUsed) {
      final st = store.stats(ex);
      if (st.bestE1rm > 0) best1rm.add((ex, st));
      if (st.days.isEmpty) continue;
      final firstDay = st.sets.first.date;
      final prs = [
        for (final s in st.sets)
          if (st.prIds.contains(s.id) && s.date.compareTo(cutoff) >= 0 && s.date != firstDay) s,
      ];
      if (prs.isEmpty) continue;
      final best = prs.reduce((a, b) => _prScore(ex, b) > _prScore(ex, a) ? b : a);
      recentPrs.add((ex, best, prs.length));
    }
    recentPrs.sort((a, b) => compareSets(b.$2, a.$2));
    best1rm.sort((a, b) => b.$2.bestE1rm.compareTo(a.$2.bestE1rm));

    return Scaffold(
      appBar: AppBar(title: const Text('Postępy')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.15,
            children: [
              StatCard('Treningi w tym tyg.', '${dates.where((d) => d.compareTo(weekKey) >= 0).length}'),
              StatCard('W tym miesiącu', '${dates.where((d) => d.compareTo(monthKey) >= 0).length}'),
              StatCard('Objętość (tydz.)', '${fmtNum(weekVolumes.last / 1000, 1)} t'),
            ],
          ),
        ),
        const SectionHeader('Objętość tygodniowa (kg)'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SimpleBarChart(
                  values: weekVolumes, labels: weekLabels, color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
        const SectionHeader('Aktywność (12 tygodni)'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _Heatmap(weekStart: weekStart, setsPerDay: setsPerDay),
            ),
          ),
        ),
        SectionHeader('Rekordy z ostatnich 30 dni (${recentPrs.length})'),
        if (recentPrs.isEmpty) const EmptyHint('Brak nowych rekordów w tym miesiącu. Do dzieła!', icon: Icons.emoji_events),
        for (final (ex, s, count) in recentPrs)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.emoji_events, color: Colors.amber, size: 21),
              ),
              title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  count > 1
                      ? '${formatDay(parseDateKey(s.date))} · $count ${count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 12 || count % 100 > 14) ? 'rekordy' : 'rekordów'} w 30 dni'
                      : formatDay(parseDateKey(s.date)),
                  style: TextStyle(color: context.shade(0.38), fontSize: 12)),
              trailing: Text(formatSet(ex, s), style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => openExercise(context, ex.id, tab: ExerciseTab.graph),
            ),
          ),
        const SectionHeader('Szacowany 1RM'),
        for (final (ex, st) in best1rm.take(12))
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: ListTile(
              leading: CategoryAvatar(ex.category),
              title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('najlepsza seria: ${formatSet(ex, st.bestE1rmSet!)}',
                  style: TextStyle(color: context.shade(0.38), fontSize: 12)),
              trailing: Text('${fmtNum(st.bestE1rm, 1)} kg',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              onTap: () => openExercise(context, ex.id, tab: ExerciseTab.graph),
            ),
          ),
      ]),
    );
  }
}

/// How impressive a record set is, comparable within one exercise.
double _prScore(Exercise ex, WorkoutSet s) => switch (ex.kind) {
      ExerciseKind.weightReps => epley1rm(s.weight, s.reps),
      ExerciseKind.bodyweight => s.reps + s.weight / 1000,
      ExerciseKind.duration => s.seconds.toDouble(),
      ExerciseKind.cardio => s.distance > 0 ? s.distance : s.seconds.toDouble(),
    };

class _Heatmap extends StatelessWidget {
  final DateTime weekStart;
  final Map<String, int> setsPerDay;
  const _Heatmap({required this.weekStart, required this.setsPerDay});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final now = today();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          for (final d in weekdayShort)
            SizedBox(height: 20, child: Text(d, style: TextStyle(fontSize: 10, color: context.shade(0.54)))),
        ]),
        const SizedBox(width: 6),
        for (var col = 0; col < 12; col++)
          Expanded(
            child: Column(children: [
              for (var row = 0; row < 7; row++)
                Builder(builder: (_) {
                  final day = DateTime(weekStart.year, weekStart.month, weekStart.day - 7 * (11 - col) + row);
                  final n = setsPerDay[dateKey(day)] ?? 0;
                  return Container(
                    height: 16,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: day.isAfter(now)
                          ? Colors.transparent
                          : n == 0
                              ? context.faintFill(0.08)
                              : color.withValues(alpha: math.min(1, 0.35 + n / 25)),
                    ),
                  );
                }),
            ]),
          ),
    ]);
  }
}
