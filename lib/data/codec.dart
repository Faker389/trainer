import 'dart:math' as math;

import 'models.dart';

/// Compact storage format shared by the local file and Firestore.
///
/// One bucket per month: `e` is the exercise-id dictionary, `d` the packed sets
/// (`;`-separated rows of `,`-separated base-36 fields, zeros left empty) and `x`
/// deletion tombstones (`id:time`). A typical set takes ~30 bytes.

String monthOf(String date) => date.substring(0, 7);

String _b(int v) => v == 0 ? '' : v.toRadixString(36);
int _i(String s) => s.isEmpty ? 0 : int.parse(s, radix: 36);
String _clean(String s) => s.replaceAll(RegExp('[|;,:]'), ' ');

const _tombstoneTtl = Duration(days: 180);

Map<String, String> encodeMonth(List<WorkoutSet> sets, Map<String, int> tombstones) {
  final dict = <String, int>{};
  final rows = <String>[];
  for (final s in sets) {
    final idx = dict.putIfAbsent(s.exerciseId, () => dict.length);
    rows.add([
      s.id,
      _b(idx),
      _b(int.parse(s.date.substring(8, 10))),
      _b((s.weight * 100).round()),
      _b(s.reps),
      _b(s.seconds),
      _b((s.distance * 1000).round()),
      _b(s.createdAt),
      _b(math.max(0, s.updatedAt - s.createdAt)),
    ].join(','));
  }
  final cutoff = DateTime.now().millisecondsSinceEpoch - _tombstoneTtl.inMilliseconds;
  return {
    'e': dict.keys.join(','),
    'd': rows.join(';'),
    'x': [
      for (final t in tombstones.entries)
        if (t.value >= cutoff) '${t.key}:${_b(t.value)}',
    ].join(';'),
  };
}

(List<WorkoutSet>, Map<String, int>) decodeMonth(String month, Map<String, dynamic> m) {
  final dict = (m['e'] as String? ?? '').split(',');
  final sets = <WorkoutSet>[];
  final d = m['d'] as String? ?? '';
  if (d.isNotEmpty) {
    for (final row in d.split(';')) {
      final f = row.split(',');
      if (f.length < 9) continue;
      final idx = _i(f[1]);
      if (idx >= dict.length) continue;
      final created = _i(f[7]);
      sets.add(WorkoutSet(
        id: f[0],
        exerciseId: dict[idx],
        date: '$month-${_i(f[2]).toString().padLeft(2, '0')}',
        createdAt: created,
        updatedAt: created + _i(f[8]),
        weight: _i(f[3]) / 100,
        reps: _i(f[4]),
        seconds: _i(f[5]),
        distance: _i(f[6]) / 1000,
      ));
    }
  }
  final tombstones = <String, int>{};
  final x = m['x'] as String? ?? '';
  if (x.isNotEmpty) {
    for (final t in x.split(';')) {
      final i = t.lastIndexOf(':');
      if (i > 0) tombstones[t.substring(0, i)] = _i(t.substring(i + 1));
    }
  }
  return (sets, tombstones);
}

/// Union by id (newest edit wins), minus sets deleted after their last edit.
(List<WorkoutSet>, Map<String, int>) mergeMonth(
  List<WorkoutSet> aSets,
  Map<String, int> aTomb,
  List<WorkoutSet> bSets,
  Map<String, int> bTomb,
) {
  final tomb = {...aTomb};
  bTomb.forEach((id, t) => tomb[id] = math.max(tomb[id] ?? 0, t));
  final byId = <String, WorkoutSet>{};
  for (final s in [...aSets, ...bSets]) {
    final cur = byId[s.id];
    if (cur == null || s.updatedAt > cur.updatedAt) byId[s.id] = s;
  }
  byId.removeWhere((id, s) => (tomb[id] ?? -1) >= s.updatedAt);
  return (byId.values.toList()..sort(compareSets), tomb);
}

Map<String, dynamic> encodeMeta(List<SplitDay> split, List<Exercise> custom, int updatedAt) => {
      's': [for (final d in split) '${_clean(d.name)}|${d.exerciseIds.join(',')}'],
      'c': [
        for (final e in custom)
          [e.id, _clean(e.name), e.category.name, e.kind.name, _clean(e.equipment), e.pattern.name].join('|'),
      ],
      'u': updatedAt,
    };

({List<SplitDay> split, List<Exercise> custom, int updatedAt}) decodeMeta(Map<String, dynamic> m) {
  final split = <SplitDay>[];
  for (final s in List<String>.from(m['s'] as List? ?? const [])) {
    final i = s.indexOf('|');
    final ids = i < 0 ? '' : s.substring(i + 1);
    split.add(SplitDay(i < 0 ? s : s.substring(0, i), ids.isEmpty ? [] : ids.split(',')));
  }
  final custom = <Exercise>[];
  for (final c in List<String>.from(m['c'] as List? ?? const [])) {
    final f = c.split('|');
    if (f.length < 6) continue;
    custom.add(Exercise(
      f[0],
      f[1],
      enumByName(MuscleCategory.values, f[2], MuscleCategory.chest),
      enumByName(ExerciseKind.values, f[3], ExerciseKind.weightReps),
      f[4],
      const [],
      enumByName(TechniquePattern.values, f[5], TechniquePattern.tracking),
      custom: true,
    ));
  }
  return (
    split: split.length == 7 ? split : List.filled(7, const SplitDay('', [])),
    custom: custom,
    updatedAt: (m['u'] as num?)?.toInt() ?? 0,
  );
}
