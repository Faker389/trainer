import 'package:flutter/material.dart';

import '../data/codec.dart';
import '../data/dates.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'widgets.dart';

/// Month heatmap of logged workouts + current streak + this week's volume per muscle group.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(today().year, today().month);

  void _shift(int months) => setState(() => _month = DateTime(_month.year, _month.month + months));

  /// Consecutive workout days ending today (or yesterday if today is still empty).
  int _streak(AppStore store) {
    final dates = store.workoutDates;
    var d = today();
    if (!dates.contains(dateKey(d))) d = d.subtract(const Duration(days: 1));
    var streak = 0;
    while (dates.contains(dateKey(d))) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final dates = store.workoutDates;
    final counts = <String, int>{};
    var monthMax = 0;
    for (final s in store.monthSets(monthOf(dateKey(_month)))) {
      counts[s.date] = (counts[s.date] ?? 0) + 1;
      if (counts[s.date]! > monthMax) monthMax = counts[s.date]!;
    }
    final streak = _streak(store);
    final scheme = Theme.of(context).colorScheme;

    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday-first grid

    return Scaffold(
      appBar: AppBar(title: const Text('Kalendarz treningów')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
          Expanded(
            child: Text(
              '${_monthNames[_month.month - 1]} ${_month.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _month.year == today().year && _month.month == today().month ? null : () => _shift(1),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(Icons.local_fire_department, color: streak > 0 ? Colors.deepOrangeAccent : context.shade(0.38)),
            const SizedBox(width: 8),
            Text(
              streak > 0 ? 'Passa: $streak ${streak == 1 ? 'dzień' : 'dni'} z rzędu' : 'Brak aktywnej passy',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text('${dates.length} treningów ogółem', style: TextStyle(color: context.shade(0.54), fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          for (final d in weekdayShort)
            Expanded(
              child: Text(d, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.shade(0.38))),
            ),
        ]),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1.1,
          children: [
            for (var i = 0; i < leading; i++) const SizedBox(),
            for (var day = 1; day <= daysInMonth; day++)
              _DayCell(
                day: day,
                sets: counts[dateKey(DateTime(_month.year, _month.month, day))] ?? 0,
                max: monthMax == 0 ? 1 : monthMax,
                isToday: DateTime(_month.year, _month.month, day) == today(),
                isFuture: DateTime(_month.year, _month.month, day).isAfter(today()),
                planned: !store.splitFor(DateTime(_month.year, _month.month, day).weekday).isRest,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.circle, size: 10, color: scheme.primary.withValues(alpha: 0.15)),
          Text('  mniej serii', style: TextStyle(fontSize: 11, color: context.shade(0.54))),
          const SizedBox(width: 16),
          Icon(Icons.circle, size: 10, color: scheme.primary),
          Text('  więcej serii', style: TextStyle(fontSize: 11, color: context.shade(0.54))),
          const SizedBox(width: 16),
          Icon(Icons.circle_outlined, size: 10, color: context.shade(0.38)),
          Text('  planowany', style: TextStyle(fontSize: 11, color: context.shade(0.54))),
        ]),
        const Divider(height: 36),
        const SectionHeader('Ten tydzień — partie mięśniowe'),
        _WeekMuscles(),
      ]),
    );
  }

  static const _monthNames = [
    'Styczeń', 'Luty', 'Marzec', 'Kwiecień', 'Maj', 'Czerwiec',
    'Lipiec', 'Sierpień', 'Wrzesień', 'Październik', 'Listopad', 'Grudzień',
  ];
}

class _DayCell extends StatelessWidget {
  final int day;
  final int sets;
  final int max;
  final bool isToday;
  final bool isFuture;
  final bool planned;
  const _DayCell(
      {required this.day, required this.sets, required this.max, required this.isToday, required this.isFuture, required this.planned});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final intensity = sets == 0 ? 0.0 : (0.25 + 0.75 * sets / max);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: sets > 0 ? scheme.primary.withValues(alpha: intensity.clamp(0.0, 1.0)) : context.faintFill(0.04),
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: scheme.primary, width: 2)
            : planned && sets == 0
                ? Border.all(color: context.shade(0.25))
                : null,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: sets > 0
                  ? (intensity > 0.55 ? scheme.onPrimary : scheme.onSurface)
                  : context.shade(isFuture ? 0.25 : 0.7),
            )),
        if (sets > 0)
          Text('$sets', style: TextStyle(fontSize: 9, color: intensity > 0.55 ? scheme.onPrimary : context.shade(0.54))),
      ]),
    );
  }
}

/// This week's sets/volume grouped by muscle category.
class _WeekMuscles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final start = startOfWeek(today());
    final end = start.add(const Duration(days: 7));
    final perCat = <MuscleCategory, ({int sets, double volume})>{};
    for (final s in store.allSets) {
      final d = parseDateKey(s.date);
      if (d.isBefore(start) || !d.isBefore(end)) continue;
      final ex = store.exercise(s.exerciseId);
      if (ex == null) continue;
      final cur = perCat[ex.category] ?? (sets: 0, volume: 0.0);
      perCat[ex.category] = (sets: cur.sets + 1, volume: cur.volume + s.volume);
    }
    if (perCat.isEmpty) {
      return const EmptyHint('Brak serii w tym tygodniu.', icon: Icons.show_chart);
    }
    final total = perCat.values.fold(0.0, (a, c) => a + c.sets);
    final rows = perCat.entries.toList()..sort((a, b) => b.value.sets.compareTo(a.value.sets));
    return Column(children: [
      for (final e in rows)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(children: [
            CircleAvatar(radius: 8, backgroundColor: e.key.color),
            const SizedBox(width: 10),
            SizedBox(width: 110, child: Text(e.key.label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: e.value.sets / total,
                  minHeight: 8,
                  color: e.key.color,
                  backgroundColor: context.faintFill(0.06),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('${e.value.sets} serii${e.value.volume > 0 ? ' · ${fmtNum(e.value.volume, 0)} kg' : ''}',
                style: TextStyle(fontSize: 12, color: context.shade(0.54))),
          ]),
        ),
    ]);
  }
}
