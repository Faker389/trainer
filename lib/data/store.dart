import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'catalog.dart';
import 'codec.dart';
import 'models.dart';
import 'stats.dart';

/// All user data, local-first. Persisted as one compact file per account and synced by `SyncService`.
class AppStore extends ChangeNotifier {
  AppStore._(this._file);
  AppStore.memory() : _file = null;

  final File? _file;
  final _custom = <Exercise>[];
  final _sets = <WorkoutSet>[];
  var _split = List<SplitDay>.filled(7, const SplitDay('', []));
  int _metaUpdatedAt = 0;
  bool _metaDirty = false;

  /// Months with local changes not yet uploaded.
  final _dirty = <String>{};
  final _tombstones = <String, Map<String, int>>{};

  /// Remote version of each month last merged.
  final _synced = <String, int>{};
  final _editSeq = <String, int>{};

  final _statsCache = <String, ExerciseStats>{};
  Map<String, Exercise>? _byId;

  /// 'system', 'light' or 'dark'; kept only in the local file (not synced).
  String themeMode = 'system';
  Future<void> _saving = Future.value();
  int _seq = 0;

  static Future<AppStore> load(String uid) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/fitlog_$uid.json');
    final store = AppStore._(file);
    final legacy = File('${dir.path}/fitlog.json');
    try {
      if (await file.exists()) {
        store._read(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
      } else if (await legacy.exists()) {
        // Data logged before accounts existed goes to the first account that signs in.
        store._read(jsonDecode(await legacy.readAsString()) as Map<String, dynamic>);
        store._save();
        await store._saving;
        await legacy.delete();
      }
    } catch (e) {
      debugPrint('Could not read saved data: $e');
    }
    return store;
  }

  void _read(Map<String, dynamic> j) {
    if (j['theme'] is String) themeMode = j['theme'] as String;
    if (j['v'] == 2) {
      (j['m'] as Map? ?? const {}).forEach((m, data) {
        final (sets, tomb) = decodeMonth(m as String, Map<String, dynamic>.from(data as Map));
        _sets.addAll(sets);
        if (tomb.isNotEmpty) _tombstones[m] = tomb;
      });
      (j['sync'] as Map? ?? const {}).forEach((k, v) => _synced[k as String] = (v as num).toInt());
      _dirty.addAll(List<String>.from(j['dirty'] as List? ?? const []));
      if (j['meta'] is Map) _applyMeta(decodeMeta(Map<String, dynamic>.from(j['meta'] as Map)));
      _metaDirty = j['metaDirty'] == true;
      return;
    }
    _custom.addAll([for (final e in j['customExercises'] as List? ?? const []) Exercise.fromJson(e)]);
    _sets.addAll([for (final s in j['sets'] as List? ?? const []) WorkoutSet.fromJson(s)]);
    final split = j['split'] as List?;
    if (split != null && split.length == 7) _split = [for (final d in split) SplitDay.fromJson(d)];
    _dirty.addAll({for (final s in _sets) monthOf(s.date)});
    _metaDirty = _custom.isNotEmpty || _split.any((d) => !d.isRest);
    if (_metaDirty) _metaUpdatedAt = DateTime.now().millisecondsSinceEpoch;
  }

  Map<String, dynamic> _toJson() {
    final byMonth = <String, List<WorkoutSet>>{};
    for (final s in _sets) {
      byMonth.putIfAbsent(monthOf(s.date), () => []).add(s);
    }
    return {
      'v': 2,
      'm': {
        for (final m in {...byMonth.keys, ..._tombstones.keys})
          m: encodeMonth(byMonth[m] ?? const [], _tombstones[m] ?? const {}),
      },
      'sync': _synced,
      'dirty': _dirty.toList(),
      'meta': metaJson,
      'metaDirty': _metaDirty,
      'theme': themeMode,
    };
  }

  void setThemeMode(String mode) {
    if (themeMode == mode) return;
    themeMode = mode;
    notifyListeners();
    _save();
  }

  /* ---------------- Queries ---------------- */

  List<Exercise> get exercises => [...exerciseCatalog, ..._custom];

  Exercise? exercise(String id) => (_byId ??= {for (final e in exercises) e.id: e})[id];

  List<WorkoutSet> get allSets => List.unmodifiable(_sets);

  List<WorkoutSet> setsOn(String date, {String? exerciseId}) =>
      _sets.where((s) => s.date == date && (exerciseId == null || s.exerciseId == exerciseId)).toList()
        ..sort(compareSets);

  List<WorkoutSet> setsFor(String exerciseId) => _sets.where((s) => s.exerciseId == exerciseId).toList()
    ..sort(compareSets);

  /// Exercises done on [date], in the order they were started.
  List<String> exerciseIdsOn(String date) => {for (final s in setsOn(date)) s.exerciseId}.toList();

  Set<String> get workoutDates => {for (final s in _sets) s.date};

  Set<String> get months => {for (final s in _sets) monthOf(s.date), ..._tombstones.keys};

  WorkoutSet? lastSetFor(String exerciseId) {
    final sets = setsFor(exerciseId);
    return sets.isEmpty ? null : sets.last;
  }

  List<SplitDay> get split => List.unmodifiable(_split);

  SplitDay splitFor(int weekday) => _split[weekday - 1];

  ExerciseStats stats(Exercise ex) => _statsCache[ex.id] ??= computeStats(ex, setsFor(ex.id));

  Future<int> localFileSize() async {
    final f = _file;
    return f != null && await f.exists() ? f.length() : 0;
  }

  /* ---------------- Mutations ---------------- */

  int get _now => DateTime.now().millisecondsSinceEpoch;

  String _newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++ % 36).toRadixString(36)}';

  WorkoutSet addSet({
    required String exerciseId,
    required String date,
    double weight = 0,
    int reps = 0,
    int seconds = 0,
    double distance = 0,
    String note = '',
  }) {
    final s = WorkoutSet(
      id: _newId(),
      exerciseId: exerciseId,
      date: date,
      createdAt: _now,
      weight: weight,
      reps: reps,
      seconds: seconds,
      distance: distance,
      note: note,
    );
    _sets.add(s);
    _touchMonth(monthOf(date), exerciseId);
    return s;
  }

  void updateSet(WorkoutSet s) {
    final i = _sets.indexWhere((x) => x.id == s.id);
    if (i < 0) return;
    _sets[i] = s.copyWith(updatedAt: _now);
    _touchMonth(monthOf(s.date), s.exerciseId);
  }

  void deleteSet(String id) {
    final i = _sets.indexWhere((x) => x.id == id);
    if (i < 0) return;
    final s = _sets.removeAt(i);
    final m = monthOf(s.date);
    _tombstones.putIfAbsent(m, () => {})[id] = _now;
    _touchMonth(m, s.exerciseId);
  }

  Exercise addCustomExercise({
    required String name,
    required MuscleCategory category,
    required ExerciseKind kind,
    required TechniquePattern pattern,
    String equipment = '',
  }) {
    final e = Exercise('c-${_newId()}', name, category, kind, equipment, const [], pattern, custom: true);
    _custom.add(e);
    _touchMeta();
    return e;
  }

  void deleteCustomExercise(String id) {
    _custom.removeWhere((e) => e.id == id);
    final removed = _sets.where((s) => s.exerciseId == id).toList();
    _sets.removeWhere((s) => s.exerciseId == id);
    for (final s in removed) {
      final m = monthOf(s.date);
      _tombstones.putIfAbsent(m, () => {})[s.id] = _now;
      _editSeq[m] = (_editSeq[m] ?? 0) + 1;
      _dirty.add(m);
    }
    _split = [
      for (final d in _split)
        SplitDay(
          d.name,
          d.exerciseIds.where((x) => x != id).toList(),
          targets: {for (final e in d.targets.entries) if (e.key != id) e.key: e.value},
          warmupIds: {...d.warmupIds}..remove(id),
          supersetIds: {...d.supersetIds}..remove(id),
        ),
    ];
    _touchMeta();
  }

  void setSplitDay(int weekday, SplitDay day) {
    _split = [..._split]..[weekday - 1] = day;
    _touchMeta();
  }

  void setSplit(List<SplitDay> days) {
    _split = List.of(days);
    _touchMeta();
  }

  void _touchMonth(String month, String exerciseId) {
    _editSeq[month] = (_editSeq[month] ?? 0) + 1;
    _dirty.add(month);
    _statsCache.remove(exerciseId);
    notifyListeners();
    _save();
  }

  void _touchMeta() {
    _metaUpdatedAt = _now;
    _metaDirty = true;
    _byId = null;
    _statsCache.clear();
    notifyListeners();
    _save();
  }

  /* ---------------- Sync API ---------------- */

  bool get hasPendingSync => _dirty.isNotEmpty || _metaDirty;
  List<String> get dirtyMonths => _dirty.toList();
  int syncedVersion(String month) => _synced[month] ?? 0;
  int editSeq(String month) => _editSeq[month] ?? 0;
  List<WorkoutSet> monthSets(String month) => _sets.where((s) => monthOf(s.date) == month).toList();
  Map<String, int> monthTombstones(String month) => Map.of(_tombstones[month] ?? const {});

  /// Stores the merged month from the cloud. When [pushedSeq] matches the current edit counter the
  /// upload covered every local change and the month is clean; otherwise newer local edits are kept.
  void applyMerged(String month, List<WorkoutSet> sets, Map<String, int> tomb, int version, {int? pushedSeq}) {
    var finalSets = sets, finalTomb = tomb;
    final clean = pushedSeq != null && pushedSeq == editSeq(month);
    if (!clean) (finalSets, finalTomb) = mergeMonth(monthSets(month), monthTombstones(month), sets, tomb);
    _sets
      ..removeWhere((s) => monthOf(s.date) == month)
      ..addAll(finalSets);
    if (finalTomb.isEmpty) {
      _tombstones.remove(month);
    } else {
      _tombstones[month] = finalTomb;
    }
    if (clean) _dirty.remove(month);
    _synced[month] = version;
    _statsCache.clear();
    notifyListeners();
    _save();
  }

  int get metaUpdatedAt => _metaUpdatedAt;
  bool get metaDirty => _metaDirty;
  Map<String, dynamic> get metaJson => encodeMeta(_split, _custom, _metaUpdatedAt);

  void applyRemoteMeta(Map<String, dynamic> meta) {
    _applyMeta(decodeMeta(meta));
    _metaDirty = false;
    notifyListeners();
    _save();
  }

  void _applyMeta(({List<SplitDay> split, List<Exercise> custom, int updatedAt}) m) {
    _split = m.split;
    _custom
      ..clear()
      ..addAll(m.custom);
    _metaUpdatedAt = m.updatedAt;
    _byId = null;
    _statsCache.clear();
  }

  void markMetaSynced(int uploadedVersion) {
    if (uploadedVersion != _metaUpdatedAt) return;
    _metaDirty = false;
    _save();
  }

  Future<void> deleteLocalData() async {
    await _saving;
    final f = _file;
    if (f != null && await f.exists()) await f.delete();
  }

  void _save() {
    final f = _file;
    if (f == null) return;
    final data = jsonEncode(_toJson());
    _saving = _saving.then((_) async {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(data, flush: true);
      await tmp.rename(f.path);
    }).catchError((Object e) {
      debugPrint('Saving failed: $e');
    });
  }
}

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  /// Rebuilds the caller when data changes.
  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// For callbacks; does not subscribe.
  static AppStore read(BuildContext context) => context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
