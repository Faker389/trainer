import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/dates.dart';
import '../data/models.dart';
import '../data/stats.dart';
import '../data/store.dart';
import 'calendar_screen.dart';
import 'exercise_browser.dart';
import 'exercise_screen.dart';
import 'widgets.dart';
import 'workout_session.dart';

/// Day log: today's plan from the weekly split plus everything logged on the selected day.
class WorkoutTab extends StatefulWidget {
  const WorkoutTab({super.key});

  @override
  State<WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends State<WorkoutTab> {
  DateTime _date = today();

  void _shift(int days) => setState(() => _date = DateTime(_date.year, _date.month, _date.day + days));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime(today().year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addExercise() async {
    final ex = await Navigator.of(context).push<Exercise>(MaterialPageRoute(builder: (_) => const ExercisePickerScreen()));
    if (ex != null && mounted) openExercise(context, ex.id, tab: ExerciseTab.track, date: dateKey(_date));
  }

  void _exportDay() {
    final store = StoreScope.read(context);
    final key = dateKey(_date);
    final plan = store.splitFor(_date.weekday);
    final buf = StringBuffer()
      ..writeln('${plan.name.isEmpty ? weekdayNames[_date.weekday - 1] : plan.name} — ${formatDay(_date)}');
    for (final id in store.exerciseIdsOn(key)) {
      final ex = store.exercise(id);
      if (ex == null) continue;
      final sets = store.setsOn(key, exerciseId: id);
      final note = sets.where((s) => s.note.isNotEmpty).map((s) => ' (${s.note})').join();
      buf.writeln('${ex.name}: ${sets.map((s) => formatSet(ex, s)).join(', ')}$note');
    }
    Clipboard.setData(ClipboardData(text: buf.toString().trim()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trening skopiowany do schowka')));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final key = dateKey(_date);
    final plan = store.splitFor(_date.weekday);
    final warmups = plan.warmup.where((id) => store.exercise(id) != null).toList();
    final mains = plan.main.where((id) => store.exercise(id) != null).toList();
    final planned = [...warmups, ...mains];
    final logged = store.exerciseIdsOn(key);
    final extra = logged.where((id) => !planned.contains(id) && store.exercise(id) != null).toList();
    final daySets = store.setsOn(key);
    final volume = daySets.fold(0.0, (a, s) => a + s.volume);
    final isToday = key == dateKey(today());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trening'),
        actions: [
          if (!isToday)
            IconButton(tooltip: 'Dziś', icon: const Icon(Icons.today), onPressed: () => setState(() => _date = today())),
          IconButton(tooltip: 'Wybierz dzień', icon: const Icon(Icons.calendar_month), onPressed: _pickDate),
          IconButton(
            tooltip: 'Kalendarz treningów',
            icon: const Icon(Icons.event_available),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
          ),
          if (daySets.isNotEmpty)
            IconButton(tooltip: 'Kopiuj trening', icon: const Icon(Icons.copy), onPressed: _exportDay),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Card(
            color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      isToday ? 'Dziś, ${formatDay(_date)}' : formatDay(_date),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
            ]),
          ),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
            if (daySets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  _StatChip(Icons.fitness_center, '${logged.length} ćw.'),
                  _StatChip(Icons.format_list_numbered, '${daySets.length} serii'),
                  if (volume > 0) _StatChip(Icons.scale_outlined, '${fmtNum(volume, 0)} kg'),
                ]),
              ),
            if (planned.isNotEmpty) ...[
              SectionHeader('Plan: ${plan.name.isEmpty ? weekdayNames[_date.weekday - 1] : plan.name}'),
              if (warmups.isNotEmpty) ...[
                const _SubHeader('Rozgrzewka'),
                for (final (i, id) in warmups.indexed)
                  FadeSlide(
                    index: i,
                    child: _ExerciseDayTile(
                      store.exercise(id)!,
                      key,
                      planned: true,
                      target: plan.targetFor(store.exercise(id)!),
                      superset: SplitDay.supersetBadge(warmups, id, plan.supersetIds),
                    ),
                  ),
                if (mains.isNotEmpty) const _SubHeader('Trening główny'),
              ],
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: mains.length,
                onReorder: (from, to) {
                  final ids = List.of(mains);
                  if (to > from) to--;
                  ids.insert(to, ids.removeAt(from));
                  final others = plan.exerciseIds.where((id) => !warmups.contains(id) && !mains.contains(id));
                  store.setSplitDay(
                    _date.weekday,
                    SplitDay(plan.name, [...warmups, ...ids, ...others],
                        targets: plan.targets, warmupIds: plan.warmupIds, supersetIds: plan.supersetIds),
                  );
                },
                itemBuilder: (context, i) {
                  final id = mains[i];
                  final ex = store.exercise(id)!;
                  return FadeSlide(
                    key: ValueKey(id),
                    index: i,
                    child: _ExerciseDayTile(ex, key,
                        planned: true,
                        reorderIndex: i,
                        target: plan.targetFor(ex),
                        superset: SplitDay.supersetBadge(mains, id, plan.supersetIds)),
                  );
                },
              ),
            ],
            if (extra.isNotEmpty) ...[
              SectionHeader(planned.isEmpty ? 'Wykonane ćwiczenia' : 'Poza planem'),
              for (final (i, id) in extra.indexed)
                FadeSlide(index: i, child: _ExerciseDayTile(store.exercise(id)!, key)),
            ],
            if (planned.isEmpty && extra.isEmpty)
              const EmptyHint(
                'Brak ćwiczeń w tym dniu.\nDodaj ćwiczenie przyciskiem poniżej albo ustaw plan tygodniowy w zakładce Plan.',
                icon: Icons.fitness_center,
              ),
          ]),
        ),
      ]),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (planned.isNotEmpty && isToday)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FloatingActionButton.extended(
              heroTag: 'fab-session',
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WorkoutSessionScreen(weekday: _date.weekday, date: key))),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Rozpocznij trening'),
            ),
          ),
        FloatingActionButton.extended(
          heroTag: 'fab-workout',
          onPressed: _addExercise,
          icon: const Icon(Icons.add),
          label: const Text('Dodaj ćwiczenie'),
        ),
      ]),
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String text;
  const _SubHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 16, 2),
        child: Text(text,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.shade(0.54))),
      );
}

class _ExerciseDayTile extends StatelessWidget {
  final Exercise ex;
  final String date;
  final bool planned;
  final int? reorderIndex;

  /// Suggested prescription, e.g. '4×8' — shown for planned exercises.
  final String? target;

  /// Superset badge, e.g. 'A1'.
  final String? superset;
  const _ExerciseDayTile(this.ex, this.date, {this.planned = false, this.reorderIndex, this.target, this.superset});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final sets = store.setsOn(date, exerciseId: ex.id);
    final prs = sets.where((s) => store.stats(ex).prIds.contains(s.id)).length;
    final done = sets.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    final targetSets =
        target == null ? null : int.tryParse(RegExp(r'^\s*(\d+)').firstMatch(target!)?.group(1) ?? '');
    final progress = planned && targetSets != null ? '${sets.length}/$targetSets serii' : null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: done
            ? Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.check, color: scheme.primary),
              )
            : CategoryAvatar(ex.category),
        title: Row(children: [
          Flexible(child: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          if (superset != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.secondary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(superset!,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.secondary)),
            ),
          ],
        ]),
        subtitle: Text(
          done
              ? '${sets.map((s) => formatSet(ex, s)).join(', ')}${progress != null ? ' · $progress' : ''}'
              : (planned ? '${target ?? ''} · do zrobienia'.trim() : ''),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.shade(done ? 0.54 : 0.38)),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (prs > 0)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.emoji_events, color: Colors.amber),
              if (prs > 1) Text('×$prs'),
            ])
          else
            Icon(Icons.chevron_right, color: context.shade(0.38)),
          if (reorderIndex != null)
            ReorderableDragStartListener(
              index: reorderIndex!,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.drag_handle, color: context.shade(0.38)),
              ),
            ),
        ]),
        onTap: () => openExercise(context, ex.id, tab: ExerciseTab.track, date: date),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: scheme.primary),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}
