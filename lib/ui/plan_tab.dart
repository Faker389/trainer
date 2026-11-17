import 'package:flutter/material.dart';

import '../data/dates.dart';
import '../data/models.dart';
import '../data/split_templates.dart';
import '../data/store.dart';
import 'exercise_browser.dart';
import 'exercise_screen.dart';
import 'widgets.dart';

/// Weekly training split: one routine (or rest) per weekday.
class PlanTab extends StatelessWidget {
  const PlanTab({super.key});

  /// Preview + apply. Templates can MERGE with the existing plan or replace it:
  /// single-day templates ([SplitTemplate.weekly] == false) fill one chosen weekday,
  /// weekly templates touch every non-rest day.
  Future<void> _applyTemplate(BuildContext context, SplitTemplate t) async {
    final store = StoreScope.read(context);
    if (!t.weekly) {
      final wd = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('„${t.name}” — wybierz dzień'),
          children: [
            for (var i = 0; i < 7; i++)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, i + 1),
                child: Text(weekdayNames[i]),
              ),
          ],
        ),
      );
      if (wd == null) return;
      final day = store.splitFor(wd);
      var target = t.days.first;
      if (day.exerciseIds.isNotEmpty) {
        final merge = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('${weekdayNames[wd - 1]} — „${day.name.isEmpty ? 'Trening' : day.name}"'),
            content: const Text('W tym dniu są już ćwiczenia. Dołączyć nowe na końcu treningu, czy zastąpić cały dzień?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zastąp')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Dołącz')),
            ],
          ),
        );
        if (merge == null) return;
        if (merge) {
          // A single-workout template (e.g. stretching) goes in front as the warm-up block.
          final added = target.exerciseIds.where((id) => !day.exerciseIds.contains(id)).toList();
          target = SplitDay(
            day.name.isEmpty ? target.name : day.name,
            [...added, ...day.exerciseIds],
            targets: {...target.targets, ...day.targets},
            warmupIds: {...added, ...target.warmupIds, ...day.warmupIds},
            supersetIds: {...day.supersetIds},
          );
        }
      }
      store.setSplitDay(wd, target);
      return;
    }
    if (store.split.any((d) => !d.isRest)) {
      final merge = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Wczytać „${t.name}”?'),
          content: const Text('Dołączyć ćwiczenia do obecnych treningów, czy zastąpić cały plan tygodniowy?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zastąp')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Dołącz')),
          ],
        ),
      );
      if (merge == null) return;
      if (merge) {
        store.setSplit([
          for (var i = 0; i < 7; i++)
            if (t.days[i].isRest)
              store.splitFor(i + 1)
            else if (store.splitFor(i + 1).isRest)
              t.days[i]
            else
              SplitDay(
                store.splitFor(i + 1).name.isEmpty ? t.days[i].name : store.splitFor(i + 1).name,
                [
                  ...store.splitFor(i + 1).exerciseIds,
                  ...t.days[i].exerciseIds.where((id) => !store.splitFor(i + 1).exerciseIds.contains(id)),
                ],
                targets: {...t.days[i].targets, ...store.splitFor(i + 1).targets},
                warmupIds: {...t.days[i].warmupIds, ...store.splitFor(i + 1).warmupIds},
                supersetIds: {...t.days[i].supersetIds, ...store.splitFor(i + 1).supersetIds},
              ),
        ]);
        return;
      }
    }
    store.setSplit(t.days);
  }

  void _previewTemplate(BuildContext context, SplitTemplate t) {
    final store = StoreScope.read(context);
    // Mutable copy — exercises can be swapped for alternatives before applying.
    final days = [
      for (final d in t.days)
        SplitDay(d.name, List.of(d.exerciseIds),
            targets: Map.of(d.targets), warmupIds: {...d.warmupIds}, supersetIds: {...d.supersetIds}),
    ];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
            Text('${t.emoji}  ${t.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(t.description, style: TextStyle(color: ctx.shade(0.54))),
            const SizedBox(height: 12),
            for (var i = 0; i < days.length; i++)
              if (!days[i].isRest)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.weekly ? '${weekdayNames[i]} — ${days[i].name}' : days[i].name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    for (final id in days[i].exerciseIds)
                      if (store.exercise(id) case final ex?)
                        Row(children: [
                          Expanded(
                            child: Text('${ex.name} ${days[i].targetFor(ex)}',
                                style: TextStyle(color: ctx.shade(0.54), fontSize: 12.5)),
                          ),
                          InkWell(
                            onTap: () async {
                              final alt = await _pickAlternative(ctx, store, ex, days[i].exerciseIds);
                              if (alt == null) return;
                              setSheet(() {
                                final j = days[i].exerciseIds.indexOf(id);
                                days[i].exerciseIds[j] = alt.id;
                                final d = days[i];
                                days[i] = SplitDay(d.name, d.exerciseIds,
                                    targets: {
                                      for (final e in d.targets.entries) (e.key == id ? alt.id : e.key): e.value
                                    },
                                    warmupIds: {...d.warmupIds}..remove(id)..addAll({if (d.warmupIds.contains(id)) alt.id}),
                                    supersetIds: {...d.supersetIds}..remove(id)..addAll({if (d.supersetIds.contains(id)) alt.id}));
                              });
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(Icons.swap_horiz, size: 16, color: ctx.shade(0.38)),
                            ),
                          ),
                        ]),
                  ]),
                ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _applyTemplate(context,
                    SplitTemplate(t.name, t.description, t.emoji, days, weekly: t.weekly));
              },
              icon: const Icon(Icons.check),
              label: Text(t.weekly ? 'Zastosuj do całego tygodnia' : 'Dodaj do wybranego dnia'),
            ),
          ]),
        ),
      ),
    );
  }

  /// Alternative exercise for swapping — same category and kind, not already in the day.
  Future<Exercise?> _pickAlternative(BuildContext ctx, AppStore store, Exercise ex, List<String> taken) async {
    final alts = store.exercises
        .where((e) => e.id != ex.id && !taken.contains(e.id) && e.category == ex.category && e.kind == ex.kind)
        .toList();
    if (alts.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Brak alternatyw tego samego typu')));
      return null;
    }
    return showDialog<Exercise>(
      context: ctx,
      builder: (d) => SimpleDialog(
        title: Text('Zamień „${ex.name}”'),
        children: [
          for (final a in alts)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(d, a),
              child: Text('${a.name}  (${a.equipment.isEmpty ? a.kind.label : a.equipment})'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final todayWd = today().weekday;
    return Scaffold(
      appBar: AppBar(title: const Text('Plan tygodniowy')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: 8,
        itemBuilder: (context, i) {
          if (i == 0) return _TemplateRail(onTap: (t) => _previewTemplate(context, t));
          final wd = i;
          final day = store.splitFor(wd);
          final names = [
            for (final id in day.exerciseIds)
              if (store.exercise(id) != null) '${store.exercise(id)!.name} ${day.targetFor(store.exercise(id)!)}'
          ];
          final isToday = wd == todayWd;
          final scheme = Theme.of(context).colorScheme;
          return FadeSlide(
            index: i,
            child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: isToday ? scheme.primary.withValues(alpha: 0.10) : null,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              title: Row(children: [
                Expanded(
                  child: Text(weekdayNames[wd - 1], style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('DZIŚ',
                        style: TextStyle(color: scheme.primary, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
              ]),
              subtitle: Text(
                day.isRest
                    ? 'Odpoczynek'
                    : '${day.name.isEmpty ? 'Trening' : day.name} · ${names.length} ćw.\n${names.join(', ')}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.shade(0.54), height: 1.4),
              ),
              isThreeLine: !day.isRest,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: day.isRest
                      ? context.faintFill(0.05)
                      : scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  day.isRest ? Icons.bedtime_outlined : Icons.fitness_center,
                  color: day.isRest ? context.shade(0.38) : scheme.primary,
                  size: 20,
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: context.shade(0.38)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SplitDayEditor(weekday: wd))),
            ),
            ),
          );
        },
      ),
    );
  }
}

/// Horizontal „Gotowe plany” carousel shown above the weekday list.
class _TemplateRail extends StatelessWidget {
  final void Function(SplitTemplate) onTap;
  const _TemplateRail({required this.onTap});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(children: [
            Icon(Icons.auto_awesome, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            const Text('Gotowe plany', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: splitTemplates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final t = splitTemplates[i];
              return SizedBox(
                width: 190,
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onTap(t),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Expanded(
                          child: Text(t.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: context.shade(0.54), fontSize: 11, height: 1.3)),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 32, indent: 4, endIndent: 4),
        const SizedBox(height: 4),
      ]);
}

class SplitDayEditor extends StatefulWidget {
  final int weekday;
  const SplitDayEditor({super.key, required this.weekday});

  @override
  State<SplitDayEditor> createState() => _SplitDayEditorState();
}

class _SplitDayEditorState extends State<SplitDayEditor> {
  late final TextEditingController _name;
  late List<String> _ids;
  late Set<String> _warmup;
  late Set<String> _superset;

  @override
  void initState() {
    super.initState();
    final day = StoreScope.read(context).splitFor(widget.weekday);
    _name = TextEditingController(text: day.name);
    _ids = List.of(day.exerciseIds);
    _warmup = {...day.warmupIds};
    _superset = {...day.supersetIds};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _commit() {
    final day = StoreScope.read(context).splitFor(widget.weekday);
    StoreScope.read(context).setSplitDay(
      widget.weekday,
      SplitDay(
        _name.text.trim(),
        List.of(_ids),
        targets: {for (final e in day.targets.entries) if (_ids.contains(e.key)) e.key: e.value},
        warmupIds: _warmup.where(_ids.contains).toSet(),
        supersetIds: _superset.where(_ids.contains).toSet(),
      ),
    );
  }

  Future<void> _add() async {
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => ExercisePickerScreen(multi: true, initial: _ids)),
    );
    if (picked == null) return;
    setState(() => _ids = [..._ids.where(picked.contains), ...picked.where((id) => !_ids.contains(id))]);
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(weekdayNames[widget.weekday - 1]),
        actions: [
          if (_ids.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() => _ids = []);
                _commit();
              },
              child: const Text('Dzień wolny'),
            ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nazwa treningu (np. Push, Nogi, Góra)'),
            onChanged: (_) => _commit(),
          ),
        ),
        Expanded(
          child: _ids.isEmpty
              ? const EmptyHint('Dzień wolny. Dodaj ćwiczenia, żeby zaplanować trening.', icon: Icons.bedtime_outlined)
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: _ids.length,
                  onReorder: (from, to) {
                    setState(() {
                      if (to > from) to--;
                      _ids.insert(to, _ids.removeAt(from));
                    });
                    _commit();
                  },
                  itemBuilder: (context, i) {
                    final ex = store.exercise(_ids[i]);
                    final id = _ids[i];
                    final isWarmup = _warmup.contains(id);
                    final isSuperset = _superset.contains(id);
                    final badge = SplitDay.supersetBadge(_ids, id, _superset);
                    return Card(
                      key: ValueKey(id),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      child: ListTile(
                        leading: ex == null ? const Icon(Icons.help_outline) : CategoryAvatar(ex.category),
                        title: Row(children: [
                          Flexible(
                            child: Text(ex?.name ?? 'Usunięte ćwiczenie',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (badge != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(badge,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(context).colorScheme.secondary)),
                            ),
                        ]),
                        subtitle: ex == null
                            ? null
                            : Text(
                                [
                                  if (isWarmup) 'rozgrzewka',
                                  ex.category.label,
                                  store.splitFor(widget.weekday).targetFor(ex),
                                ].join(' · '),
                                style: TextStyle(color: context.shade(0.38), fontSize: 12)),
                        onTap: ex == null ? null : () => openExercise(context, ex.id),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: isWarmup ? 'Przenieś do treningu głównego' : 'Oznacz jako rozgrzewka',
                            icon: Icon(Icons.local_fire_department,
                                size: 20,
                                color: isWarmup ? Colors.deepOrangeAccent : context.shade(0.38)),
                            onPressed: () {
                              setState(() => isWarmup ? _warmup.remove(id) : _warmup.add(id));
                              _commit();
                            },
                          ),
                          IconButton(
                            tooltip: isSuperset ? 'Odepnij z superserii' : 'Połącz z poprzednim w superserię',
                            icon: Icon(Icons.link,
                                size: 20,
                                color: isSuperset ? Theme.of(context).colorScheme.secondary : context.shade(0.38)),
                            onPressed: i == 0
                                ? null
                                : () {
                                    setState(() =>
                                        isSuperset ? _superset.remove(id) : _superset.add(id));
                                    _commit();
                                  },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: context.shade(0.38)),
                            onPressed: () {
                              setState(() => _ids.removeAt(i));
                              _commit();
                            },
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: Icon(Icons.drag_handle, color: context.shade(0.38)),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-split-day',
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Dodaj ćwiczenia'),
      ),
    );
  }
}
