import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/dates.dart';
import '../data/models.dart';
import '../data/stats.dart';
import '../data/store.dart';
import 'widgets.dart';

/// Guided workout: walks through the day's planned exercises one by one
/// and runs a rest timer between sets.
class WorkoutSessionScreen extends StatefulWidget {
  final int weekday;

  /// Day key `yyyy-MM-dd` the sets are logged into.
  final String date;
  const WorkoutSessionScreen({super.key, required this.weekday, required this.date});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  final _page = PageController();
  int _index = 0;
  bool _finished = false;

  /* rest timer */
  Timer? _timer;
  int _restLeft = 0;
  int _restChoice = 90;

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  List<String> get _ordered => StoreScope.read(context).splitFor(widget.weekday).exerciseIds;

  SplitDay get _plan => StoreScope.read(context).splitFor(widget.weekday);

  void _startRest() {
    _timer?.cancel();
    setState(() => _restLeft = _restChoice);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restLeft <= 1) {
        t.cancel();
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.vibrate();
        setState(() => _restLeft = 0);
      } else {
        setState(() => _restLeft--);
      }
    });
  }

  void _next() {
    _timer?.cancel();
    setState(() => _restLeft = 0);
    if (_index >= _ordered.length - 1) {
      setState(() => _finished = true);
      return;
    }
    _page.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _onSetSaved() {
    if (_restChoice > 0) _startRest();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ids = _ordered.where((id) => store.exercise(id) != null).toList();
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name.isEmpty ? 'Trening' : plan.name),
        actions: [
          if (!_finished)
            TextButton(
              onPressed: () => setState(() => _finished = true),
              child: const Text('Zakończ'),
            ),
        ],
      ),
      body: ids.isEmpty
          ? const EmptyHint('Brak ćwiczeń w tym dniu.', icon: Icons.fitness_center)
          : _finished
              ? _Summary(date: widget.date, total: ids.length)
              : Column(children: [
                  LinearProgressIndicator(
                    value: (_index + 1) / ids.length,
                    minHeight: 4,
                    backgroundColor: context.faintFill(),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _page,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _index = i),
                      itemCount: ids.length,
                      itemBuilder: (context, i) => _ExercisePage(
                        ex: store.exercise(ids[i])!,
                        date: widget.date,
                        index: i,
                        total: ids.length,
                        isWarmup: plan.warmupIds.contains(ids[i]),
                        target: plan.targetFor(store.exercise(ids[i])!),
                        superset: SplitDay.supersetBadge(
                            plan.warmupIds.contains(ids[i]) ? plan.warmup : plan.main, ids[i], plan.supersetIds),
                        onSaved: _onSetSaved,
                      ),
                    ),
                  ),
                  _RestBar(
                    left: _restLeft,
                    total: _restChoice,
                    choice: _restChoice,
                    onChoice: (s) => setState(() => _restChoice = s),
                    onSkip: () {
                      _timer?.cancel();
                      setState(() => _restLeft = 0);
                    },
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: FilledButton.icon(
                        onPressed: _next,
                        icon: Icon(_index >= ids.length - 1 ? Icons.flag : Icons.skip_next),
                        label: Text(_index >= ids.length - 1 ? 'Zakończ trening' : 'Następne ćwiczenie'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      ),
                    ),
                  ),
                ]),
    );
  }
}

/* ---------------- rest bar ---------------- */

class _RestBar extends StatelessWidget {
  final int left;
  final int total;
  final int choice;
  final ValueChanged<int> onChoice;
  final VoidCallback onSkip;
  const _RestBar({required this.left, required this.total, required this.choice, required this.onChoice, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: left > 0
          ? Row(children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(value: left / total, strokeWidth: 3),
                  Text('$left', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Przerwa — ${left}s', style: TextStyle(color: context.shade(0.7)))),
              TextButton(onPressed: onSkip, child: const Text('Pomiń')),
            ])
          : Row(children: [
              Icon(Icons.timer_outlined, size: 18, color: context.shade(0.54)),
              const SizedBox(width: 8),
              Text('Przerwa:', style: TextStyle(color: context.shade(0.54), fontSize: 13)),
              const SizedBox(width: 8),
              for (final s in const [60, 90, 120])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${s}s'),
                    selected: choice == s,
                    onSelected: (_) => onChoice(s),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const Spacer(),
              Text('wył.', style: TextStyle(color: choice == 0 ? scheme.primary : context.shade(0.38), fontSize: 12)),
              Switch(
                value: choice > 0,
                onChanged: (v) => onChoice(v ? 90 : 0),
              ),
            ]),
    );
  }
}

/* ---------------- exercise page ---------------- */

class _ExercisePage extends StatefulWidget {
  final Exercise ex;
  final String date;
  final int index;
  final int total;
  final bool isWarmup;
  final String target;
  final String? superset;
  final VoidCallback onSaved;
  const _ExercisePage({
    required this.ex,
    required this.date,
    required this.index,
    required this.total,
    required this.isWarmup,
    required this.target,
    required this.superset,
    required this.onSaved,
  });

  @override
  State<_ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<_ExercisePage> with AutomaticKeepAliveClientMixin {
  final _a = TextEditingController();
  final _b = TextEditingController();
  bool _prefilled = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final last = StoreScope.read(context).lastSetFor(widget.ex.id);
    if (last != null) {
      switch (widget.ex.kind) {
        case ExerciseKind.weightReps || ExerciseKind.bodyweight:
          _a.text = fmtNum(last.weight);
          _b.text = '${last.reps}';
        case ExerciseKind.duration:
          _b.text = '${last.seconds}';
        case ExerciseKind.cardio:
          _a.text = fmtNum(last.distance);
          _b.text = fmtNum(last.seconds / 60);
      }
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _save() {
    final a = parseNum(_a.text) ?? 0, b = parseNum(_b.text) ?? 0;
    final messenger = ScaffoldMessenger.of(context);
    final store = StoreScope.read(context);
    switch (widget.ex.kind) {
      case ExerciseKind.weightReps || ExerciseKind.bodyweight:
        if (b < 1) {
          messenger.showSnackBar(const SnackBar(content: Text('Podaj powtórzenia')));
          return;
        }
        store.addSet(exerciseId: widget.ex.id, date: widget.date, weight: a, reps: b.round());
      case ExerciseKind.duration:
        if (b < 1) {
          messenger.showSnackBar(const SnackBar(content: Text('Podaj czas')));
          return;
        }
        store.addSet(exerciseId: widget.ex.id, date: widget.date, seconds: b.round());
      case ExerciseKind.cardio:
        if (a <= 0 && b <= 0) {
          messenger.showSnackBar(const SnackBar(content: Text('Podaj dystans lub czas')));
          return;
        }
        store.addSet(exerciseId: widget.ex.id, date: widget.date, distance: a, seconds: (b * 60).round());
    }
    widget.onSaved();
  }

  List<Widget> _inputs() => switch (widget.ex.kind) {
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
    final scheme = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
      Row(children: [
        Text('Ćwiczenie ${widget.index + 1}/${widget.total}',
            style: TextStyle(color: context.shade(0.54), fontSize: 12, fontWeight: FontWeight.w600)),
        if (widget.isWarmup) ...[
          const SizedBox(width: 8),
          Text('ROZGRZEWKA', style: TextStyle(color: scheme.secondary, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ]),
      const SizedBox(height: 8),
      Row(children: [
        CategoryAvatar(widget.ex.category),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(widget.ex.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
              ),
              if (widget.superset != null) ...[
                const SizedBox(width: 8),
                Text('superseria ${widget.superset}',
                    style: TextStyle(color: scheme.secondary, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ]),
            Text('Cel: ${widget.target}', style: TextStyle(color: context.shade(0.54), fontSize: 13)),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      ..._inputs(),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('Zapisz serię'),
      ),
      const Divider(height: 32),
      if (sets.isEmpty)
        Text('Brak serii — zapisz pierwszą.', style: TextStyle(color: context.shade(0.54)))
      else
        for (var i = 0; i < sets.length; i++)
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: context.faintFill(),
              child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            title: Text(formatSet(widget.ex, sets[i]), style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: stats.prIds.contains(sets[i].id) ? const Icon(Icons.emoji_events, color: Colors.amber) : null,
          ),
    ]);
  }
}

/* ---------------- summary ---------------- */

class _Summary extends StatelessWidget {
  final String date;
  final int total;
  const _Summary({required this.date, required this.total});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final sets = store.setsOn(date);
    final volume = sets.fold(0.0, (a, s) => a + s.volume);
    final done = store.exerciseIdsOn(date).length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.emoji_events, size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('Trening ukończony!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text('$done z $total ćwiczeń · ${sets.length} serii'
              '${volume > 0 ? ' · ${fmtNum(volume, 0)} kg' : ''}',
              style: TextStyle(color: context.shade(0.7))),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Gotowe')),
        ]),
      ),
    );
  }
}
