import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/dates.dart';
import '../data/howto.dart';
import '../data/models.dart';
import '../data/stats.dart';
import '../data/store.dart';
import '../technique/patterns.dart';
import 'technique_setup_screen.dart';
import 'widgets.dart';

abstract final class ExerciseTab {
  static const howTo = 0, track = 1, history = 2, graph = 3;
}

void openExercise(BuildContext context, String exerciseId, {int tab = ExerciseTab.howTo, String? date}) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExerciseScreen(exerciseId: exerciseId, initialTab: tab, date: date),
    ));

class ExerciseScreen extends StatelessWidget {
  final String exerciseId;
  final int initialTab;

  /// Day the "Zapisz" tab logs into; today when null.
  final String? date;
  const ExerciseScreen({super.key, required this.exerciseId, this.initialTab = ExerciseTab.howTo, this.date});

  @override
  Widget build(BuildContext context) {
    final ex = StoreScope.of(context).exercise(exerciseId);
    if (ex == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyHint('To ćwiczenie zostało usunięte.'));
    }
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(ex.name),
          actions: [
            IconButton(
              tooltip: 'Sprawdź technikę',
              icon: const Icon(Icons.videocam),
              onPressed: () => openTechniqueCheck(context, ex),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Jak wykonać'),
            Tab(text: 'Zapisz'),
            Tab(text: 'Historia'),
            Tab(text: 'Wykres'),
          ]),
        ),
        body: TabBarView(children: [
          _HowToTab(ex),
          _TrackTab(ex, date ?? dateKey(today())),
          _HistoryTab(ex),
          _GraphTab(ex),
        ]),
      ),
    );
  }
}

/* ---------------- Jak wykonać ---------------- */

class _HowToTab extends StatelessWidget {
  final Exercise ex;
  const _HowToTab(this.ex);

  @override
  Widget build(BuildContext context) {
    final def = techniqueDefinitionFor(ex);
    final howTo = howToFor(ex, def);
    final full = hasFullAnalysis(ex);
    final scheme = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      AspectRatio(
        aspectRatio: 16 / 9,
        child: InkWell(
          onTap: () => launchUrl(
            Uri.parse(ex.videoUrl ??
                'https://www.youtube.com/results?search_query=${Uri.encodeComponent('${ex.name} technika')}'),
            mode: LaunchMode.externalApplication,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ex.category.color.withValues(alpha: 0.28),
                  scheme.surfaceContainer,
                ],
              ),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.play_circle_outline, size: 64, color: context.shade(0.7)),
              const SizedBox(height: 8),
              Text('Obejrzyj wideo na YouTube', style: TextStyle(color: context.shade())),
            ]),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            [ex.category.label, if (ex.equipment.isNotEmpty) ex.equipment].join('  ·  '),
            style: TextStyle(color: ex.category.color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          if (ex.muscles.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(ex.muscles.join(', '), style: TextStyle(color: context.shade(), fontSize: 13)),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Card(
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(full ? Icons.verified : Icons.accessibility_new, color: full ? scheme.primary : Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(full ? 'Pełna analiza techniki AI' : 'Śledzenie sylwetki kamerą',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(full
                  ? 'Kamera liczy powtórzenia, wykrywa błędy techniki i podpowiada głosowo.'
                  : countsReps(ex)
                      ? 'Kamera rysuje szkielet, pokazuje kąty stawów i liczy powtórzenia.'
                      : 'Kamera rysuje szkielet i pokazuje kąty stawów.'),
              const SizedBox(height: 10),
              FilledButton.icon(
                icon: const Icon(Icons.videocam),
                label: const Text('Sprawdź technikę'),
                onPressed: () => openTechniqueCheck(context, ex),
              ),
            ]),
          ),
        ),
      ),
      const SectionHeader('Wykonanie'),
      for (var i = 0; i < howTo.steps.length; i++)
        ListTile(
          dense: true,
          leading: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ex.category.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${i + 1}',
                style: TextStyle(color: ex.category.color, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          title: Text(howTo.steps[i], style: const TextStyle(height: 1.35)),
        ),
      const SectionHeader('Kluczowe punkty'),
      for (final t in howTo.tips)
        ListTile(dense: true, leading: const Icon(Icons.check_circle_outline, color: Colors.green), title: Text(t)),
      const SectionHeader('Najczęstsze błędy'),
      for (final m in howTo.mistakes)
        ListTile(dense: true, leading: const Icon(Icons.close, color: Colors.redAccent), title: Text(m)),
      const SectionHeader('Oddychanie'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(howTo.breathing)),
    ]);
  }
}

/* ---------------- Zapisz ---------------- */

class _TrackTab extends StatefulWidget {
  final Exercise ex;
  final String date;
  const _TrackTab(this.ex, this.date);

  @override
  State<_TrackTab> createState() => _TrackTabState();
}

class _TrackTabState extends State<_TrackTab> with AutomaticKeepAliveClientMixin {
  /// Weight (kg) or distance (km).
  final _a = TextEditingController();

  /// Reps, seconds or minutes.
  final _b = TextEditingController();

  /// Optional note saved with the set (RPE, tempo, ...).
  final _note = TextEditingController();
  String? _editing;
  bool _prefilled = false;

  ExerciseKind get _kind => widget.ex.kind;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final last = StoreScope.read(context).lastSetFor(widget.ex.id);
    if (last != null) _fill(last);
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _note.dispose();
    super.dispose();
  }

  void _fill(WorkoutSet s) {
    _note.text = s.note;
    switch (_kind) {
      case ExerciseKind.weightReps || ExerciseKind.bodyweight:
        _a.text = fmtNum(s.weight);
        _b.text = '${s.reps}';
      case ExerciseKind.duration:
        _b.text = '${s.seconds}';
      case ExerciseKind.cardio:
        _a.text = fmtNum(s.distance);
        _b.text = fmtNum(s.seconds / 60);
    }
  }

  ({double weight, int reps, int seconds, double distance})? _values() {
    final a = parseNum(_a.text) ?? 0, b = parseNum(_b.text) ?? 0;
    return switch (_kind) {
      ExerciseKind.weightReps || ExerciseKind.bodyweight =>
        b >= 1 ? (weight: a, reps: b.round(), seconds: 0, distance: 0.0) : null,
      ExerciseKind.duration => b >= 1 ? (weight: 0.0, reps: 0, seconds: b.round(), distance: 0.0) : null,
      ExerciseKind.cardio =>
        a > 0 || b > 0 ? (weight: 0.0, reps: 0, seconds: (b * 60).round(), distance: a) : null,
    };
  }

  void _save() {
    final v = _values();
    final messenger = ScaffoldMessenger.of(context);
    if (v == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Uzupełnij wartości serii')));
      return;
    }
    final store = StoreScope.read(context);
    if (_editing != null) {
      final old = store.setsFor(widget.ex.id).where((s) => s.id == _editing).firstOrNull;
      if (old != null) {
        store.updateSet(old.copyWith(
            weight: v.weight, reps: v.reps, seconds: v.seconds, distance: v.distance, note: _note.text.trim()));
      }
      setState(() => _editing = null);
      return;
    }
    final s = store.addSet(
      exerciseId: widget.ex.id,
      date: widget.date,
      weight: v.weight,
      reps: v.reps,
      seconds: v.seconds,
      distance: v.distance,
      note: _note.text.trim(),
    );
    if (store.stats(widget.ex).prIds.contains(s.id)) {
      messenger.showSnackBar(const SnackBar(content: Text('Nowy rekord osobisty!')));
    }
  }

  void _duplicate(WorkoutSet s) {
    StoreScope.read(context).addSet(
      exerciseId: widget.ex.id,
      date: widget.date,
      weight: s.weight,
      reps: s.reps,
      seconds: s.seconds,
      distance: s.distance,
      note: s.note,
    );
  }

  /// Weight suggestion from the plan's target reps and the estimated 1RM.
  String? _weightHint(AppStore store, ExerciseStats stats) {
    if (_kind != ExerciseKind.weightReps || stats.bestE1rm <= 0) return null;
    final day = store.splitFor(parseDateKey(widget.date).weekday);
    final reps = int.tryParse(RegExp(r'×\s*(\d+)').firstMatch(day.targetFor(widget.ex))?.group(1) ?? '');
    if (reps == null || reps <= 0) return null;
    final suggested = stats.bestE1rm / (1 + reps / 30);
    return 'Sugerowane ≈ ${fmtNum((suggested / 2.5).round() * 2.5, 1)} kg przy $reps powt.';
  }

  void _clearOrDelete() {
    if (_editing != null) {
      StoreScope.read(context).deleteSet(_editing!);
      setState(() => _editing = null);
    } else {
      _a.clear();
      _b.clear();
    }
  }

  List<Widget> _inputs() => switch (_kind) {
        ExerciseKind.weightReps => [
            NumberStepper(label: 'Ciężar (kg)', controller: _a, step: 2.5, decimal: true),
            NumberStepper(label: 'Powtórzenia', controller: _b, step: 1),
          ],
        ExerciseKind.bodyweight => [
            NumberStepper(label: 'Powtórzenia', controller: _b, step: 1),
            NumberStepper(label: 'Dodatkowy ciężar (kg)', controller: _a, step: 2.5, decimal: true),
          ],
        ExerciseKind.duration => [NumberStepper(label: 'Czas (sekundy)', controller: _b, step: 5)],
        ExerciseKind.cardio => [
            NumberStepper(label: 'Dystans (km)', controller: _a, step: 0.5, decimal: true),
            NumberStepper(label: 'Czas (minuty)', controller: _b, step: 1, decimal: true),
          ],
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final store = StoreScope.of(context);
    final sets = store.setsOn(widget.date, exerciseId: widget.ex.id);
    final stats = store.stats(widget.ex);
    final isToday = widget.date == dateKey(today());
    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(isToday ? 'Dziś, ${formatDay(parseDateKey(widget.date))}' : formatDay(parseDateKey(widget.date)),
            style: TextStyle(color: context.shade(0.7))),
      ),
      ..._inputs(),
      if (_weightHint(store, stats) case final hint?)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(children: [
            Icon(Icons.lightbulb_outline, size: 16, color: context.shade()),
            const SizedBox(width: 6),
            Expanded(child: Text(hint, style: TextStyle(color: context.shade(), fontSize: 12.5))),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: TextField(
          controller: _note,
          decoration: const InputDecoration(
            labelText: 'Notatka (opcjonalnie)',
            hintText: 'np. RPE 8, tempo 3-1-1',
            prefixIcon: Icon(Icons.notes),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          Expanded(
            child: FilledButton(onPressed: _save, child: Text(_editing == null ? 'Zapisz' : 'Aktualizuj')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: _clearOrDelete,
              child: Text(_editing == null ? 'Wyczyść' : 'Usuń'),
            ),
          ),
        ]),
      ),
      const Divider(height: 32),
      if (sets.isEmpty) const EmptyHint('Brak serii w tym dniu.', icon: Icons.playlist_add),
      for (var i = 0; i < sets.length; i++)
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          color: sets[i].id == _editing
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : null,
          child: ListTile(
            leading: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.faintFill(),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('${i + 1}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.shade(0.7))),
            ),
            title: Text(formatSet(widget.ex, sets[i]),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            subtitle: Text(
              [
                if (_kind == ExerciseKind.weightReps && sets[i].reps > 0)
                  '1RM ≈ ${fmtNum(epley1rm(sets[i].weight, sets[i].reps), 1)} kg',
                if (sets[i].note.isNotEmpty) sets[i].note,
              ].join(' · '),
              style: TextStyle(color: context.shade(0.38), fontSize: 12),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (stats.prIds.contains(sets[i].id)) const Icon(Icons.emoji_events, color: Colors.amber),
              IconButton(
                tooltip: 'Powtórz serię',
                icon: Icon(Icons.replay, size: 20, color: context.shade()),
                onPressed: () => _duplicate(sets[i]),
              ),
            ]),
            onTap: () => setState(() {
              if (_editing == sets[i].id) {
                _editing = null;
              } else {
                _editing = sets[i].id;
                _fill(sets[i]);
              }
            }),
          ),
        ),
    ]);
  }
}

/* ---------------- Historia ---------------- */

class _HistoryTab extends StatelessWidget {
  final Exercise ex;
  const _HistoryTab(this.ex);

  @override
  Widget build(BuildContext context) {
    final stats = StoreScope.of(context).stats(ex);
    if (stats.days.isEmpty) return const EmptyHint('Brak historii. Zapisz pierwszą serię.', icon: Icons.history);
    final days = stats.days.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final d = days[i];
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(formatDay(d.day), style: const TextStyle(fontWeight: FontWeight.bold))),
                if (ex.kind == ExerciseKind.weightReps)
                  Text('${fmtNum(d.volume, 0)} kg', style: TextStyle(color: context.shade())),
              ]),
              const SizedBox(height: 6),
              for (final s in d.sets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(formatSet(ex, s))),
                      if (stats.prIds.contains(s.id)) const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                    ]),
                    if (s.note.isNotEmpty)
                      Text(s.note, style: TextStyle(color: context.shade(0.54), fontSize: 12)),
                  ]),
                ),
            ]),
          ),
        );
      },
    );
  }
}

/* ---------------- Wykres + rekordy ---------------- */

enum _Metric {
  e1rm('Szacowany 1RM (kg)'),
  maxWeight('Maks. ciężar (kg)'),
  volume('Objętość (kg)'),
  maxReps('Maks. powtórzenia'),
  totalReps('Suma powtórzeń'),
  maxTime('Najdłuższy czas (s)'),
  distance('Dystans (km)'),
  time('Czas (min)'),
  pace('Tempo (min/km)');

  final String label;
  const _Metric(this.label);

  static List<_Metric> forKind(ExerciseKind k) => switch (k) {
        ExerciseKind.weightReps => [e1rm, maxWeight, volume, maxReps],
        ExerciseKind.bodyweight => [maxReps, totalReps],
        ExerciseKind.duration => [maxTime],
        ExerciseKind.cardio => [distance, time, pace],
      };

  double? of(DaySummary d) => switch (this) {
        e1rm => d.bestE1rm,
        maxWeight => d.maxWeight,
        volume => d.volume,
        maxReps => d.maxReps.toDouble(),
        totalReps => d.totalReps.toDouble(),
        maxTime => d.maxSeconds.toDouble(),
        distance => d.distance,
        time => d.totalSeconds / 60,
        pace => d.distance > 0 && d.totalSeconds > 0 ? d.totalSeconds / 60 / d.distance : null,
      };
}

class _GraphTab extends StatefulWidget {
  final Exercise ex;
  const _GraphTab(this.ex);

  @override
  State<_GraphTab> createState() => _GraphTabState();
}

class _GraphTabState extends State<_GraphTab> {
  static const _ranges = {'1 mies.': 30, '3 mies.': 91, '6 mies.': 182, '1 rok': 365, 'Wszystko': 0};
  late _Metric _metric = _Metric.forKind(widget.ex.kind).first;
  String _range = '3 mies.';

  @override
  Widget build(BuildContext context) {
    final stats = StoreScope.of(context).stats(widget.ex);
    if (stats.days.isEmpty) return const EmptyHint('Wykres pojawi się po zapisaniu pierwszych serii.', icon: Icons.show_chart);
    final days = _ranges[_range]!;
    final cutoff = days == 0 ? null : today().subtract(Duration(days: days));
    final points = <(DateTime, double)>[
      for (final d in stats.days)
        if (cutoff == null || !d.day.isBefore(cutoff))
          if (_metric.of(d) case final v? when v > 0) (d.day, v),
    ];
    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: DropdownButtonFormField<_Metric>(
          value: _metric,
          decoration: const InputDecoration(labelText: 'Wskaźnik'),
          items: [for (final m in _Metric.forKind(widget.ex.kind)) DropdownMenuItem(value: m, child: Text(m.label))],
          onChanged: (m) => setState(() => _metric = m!),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final r in _ranges.keys)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(label: Text(r), selected: _range == r, onSelected: (_) => setState(() => _range = r)),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: points.isEmpty
            ? const EmptyHint('Brak danych w tym okresie.')
            : SimpleLineChart(points: points, color: widget.ex.category.color),
      ),
      ..._records(stats),
    ]);
  }

  List<Widget> _records(ExerciseStats s) {
    String when(WorkoutSet? x) => x == null ? '' : formatDay(parseDateKey(x.date));
    final ex = widget.ex;
    final cards = <Widget>[
      if (ex.kind == ExerciseKind.weightReps && s.bestE1rmSet != null) ...[
        StatCard('Szacowany 1RM (Epley)', '${fmtNum(s.bestE1rm, 1)} kg',
            caption: '${formatSet(ex, s.bestE1rmSet!)} · ${when(s.bestE1rmSet)}'),
        StatCard('Najcięższa seria', formatSet(ex, s.heaviestSet!), caption: when(s.heaviestSet)),
        StatCard('Łączna objętość', '${fmtNum(s.totalVolume, 0)} kg'),
      ],
      if (ex.kind == ExerciseKind.bodyweight && s.mostRepsSet != null) ...[
        StatCard('Najwięcej powtórzeń', '${s.mostRepsSet!.reps}', caption: when(s.mostRepsSet)),
        StatCard('Suma powtórzeń', '${s.totalReps}'),
      ],
      if (ex.kind == ExerciseKind.duration && s.longestSet != null)
        StatCard('Najdłuższy czas', fmtDuration(s.longestSet!.seconds), caption: when(s.longestSet)),
      if (ex.kind == ExerciseKind.cardio) ...[
        if (s.farthestSet != null)
          StatCard('Najdłuższy dystans', '${fmtNum(s.farthestSet!.distance)} km', caption: when(s.farthestSet)),
        if (s.longestSet != null)
          StatCard('Najdłuższy trening', fmtDuration(s.longestSet!.seconds), caption: when(s.longestSet)),
      ],
      StatCard('Treningi', '${s.days.length}', caption: '${s.sets.length} serii'),
    ];
    return [
      const SectionHeader('Rekordy'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: cards,
        ),
      ),
      if (s.repRecords.isNotEmpty) ...[
        const SectionHeader('Rekordy dla liczby powtórzeń'),
        for (final e in s.repRecords.entries)
          ListTile(
            dense: true,
            leading: Text('${e.key} RM', style: const TextStyle(fontWeight: FontWeight.bold)),
            title: Text('${fmtNum(e.value.weight)} kg'),
            trailing: Text(when(e.value), style: TextStyle(color: context.shade())),
          ),
      ],
      if (s.bestE1rm > 0) ...[
        const SectionHeader('Kalkulator ciężarów z 1RM'),
        for (final p in const [100, 95, 90, 85, 80, 75, 70, 65, 60])
          ListTile(
            dense: true,
            leading: Text('$p%', style: const TextStyle(fontWeight: FontWeight.bold)),
            title: Text('${fmtNum(s.bestE1rm * p / 100, 1)} kg'),
            trailing: Text(p == 100 ? '1 powt.' : '~${(30 * (100 / p - 1)).round()} powt.',
                style: TextStyle(color: context.shade())),
          ),
      ],
    ];
  }
}
