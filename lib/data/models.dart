import 'package:flutter/painting.dart';

enum ExerciseKind {
  weightReps('Ciężar i powtórzenia'),
  bodyweight('Masa ciała + powtórzenia'),
  duration('Czas'),
  cardio('Dystans i czas');

  final String label;
  const ExerciseKind(this.label);
}

enum MuscleCategory {
  chest('Klatka piersiowa', Color(0xFFEF4444)),
  back('Plecy', Color(0xFF3B82F6)),
  legs('Nogi', Color(0xFF22C55E)),
  glutes('Pośladki', Color(0xFFEC4899)),
  shoulders('Barki', Color(0xFFF59E0B)),
  biceps('Biceps', Color(0xFF8B5CF6)),
  triceps('Triceps', Color(0xFF06B6D4)),
  forearms('Przedramiona', Color(0xFFA8A29E)),
  core('Brzuch', Color(0xFFEAB308)),
  calves('Łydki', Color(0xFF14B8A6)),
  cardio('Cardio', Color(0xFFF97316));

  final String label;
  final Color color;
  const MuscleCategory(this.label, this.color);
}

/// Movement pattern used by the camera technique check when the engine has no dedicated definition.
enum TechniquePattern {
  squat('Przysiad (kąt kolana)'),
  legPress('Wypychanie nogami (kąt kolana)'),
  lunge('Wykrok (kąt kolana)'),
  hinge('Skłon w biodrach (kąt biodra)'),
  hipExtension('Wyprost bioder (kąt biodra)'),
  kneeExtension('Prostowanie kolan'),
  kneeFlexion('Uginanie kolan'),
  press('Wyciskanie (kąt łokcia)'),
  pull('Przyciąganie (kąt łokcia)'),
  curl('Uginanie ramion (kąt łokcia)'),
  elbowExtension('Prostowanie ramion (kąt łokcia)'),
  raise('Unoszenie ramion (kąt barku)'),
  pullover('Ściąganie prostymi rękami (kąt barku)'),
  crunch('Spięcie brzucha (kąt biodra)'),
  legRaise('Unoszenie nóg (kąt biodra)'),
  calf('Wspięcia na palce (kąt skokowy)'),
  hold('Pozycja statyczna (linia ciała)'),
  tracking('Tylko śledzenie sylwetki');

  final String label;
  const TechniquePattern(this.label);
}

T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

class Exercise {
  final String id;
  final String name;
  final MuscleCategory category;
  final ExerciseKind kind;
  final String equipment;
  final List<String> muscles;
  final TechniquePattern pattern;

  /// Id of a full engine definition (technique rules), when one exists.
  final String? engineId;
  final String? videoUrl;

  /// Exercise-specific instructions; the shared template is used when null.
  final List<String>? steps;
  final bool custom;

  const Exercise(
    this.id,
    this.name,
    this.category,
    this.kind,
    this.equipment,
    this.muscles,
    this.pattern, {
    this.engineId,
    this.videoUrl,
    this.steps,
    this.custom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'kind': kind.name,
        'equipment': equipment,
        'muscles': muscles,
        'pattern': pattern.name,
      };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        j['id'] as String,
        j['name'] as String,
        enumByName(MuscleCategory.values, j['category'], MuscleCategory.chest),
        enumByName(ExerciseKind.values, j['kind'], ExerciseKind.weightReps),
        j['equipment'] as String? ?? '',
        List<String>.from(j['muscles'] as List? ?? const []),
        enumByName(TechniquePattern.values, j['pattern'], TechniquePattern.tracking),
        custom: true,
      );
}

class WorkoutSet {
  final String id;
  final String exerciseId;

  /// Day key, `yyyy-MM-dd`.
  final String date;
  final int createdAt;

  /// Last edit time; decides which copy wins when devices merge.
  final int updatedAt;
  final double weight;
  final int reps;
  final int seconds;
  final double distance;

  /// Optional note, e.g. RPE or 'pauza skrócona'.
  final String note;

  const WorkoutSet({
    required this.id,
    required this.exerciseId,
    required this.date,
    required this.createdAt,
    int? updatedAt,
    this.weight = 0,
    this.reps = 0,
    this.seconds = 0,
    this.distance = 0,
    this.note = '',
  }) : updatedAt = updatedAt ?? createdAt;

  double get volume => weight * reps;

  WorkoutSet copyWith({double? weight, int? reps, int? seconds, double? distance, int? updatedAt, String? note}) =>
      WorkoutSet(
        id: id,
        exerciseId: exerciseId,
        date: date,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        weight: weight ?? this.weight,
        reps: reps ?? this.reps,
        seconds: seconds ?? this.seconds,
        distance: distance ?? this.distance,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'date': date,
        'createdAt': createdAt,
        if (weight != 0) 'weight': weight,
        if (reps != 0) 'reps': reps,
        if (seconds != 0) 'seconds': seconds,
        if (distance != 0) 'distance': distance,
        if (note.isNotEmpty) 'note': note,
      };

  factory WorkoutSet.fromJson(Map<String, dynamic> j) => WorkoutSet(
        id: j['id'] as String,
        exerciseId: j['exerciseId'] as String,
        date: j['date'] as String,
        createdAt: (j['createdAt'] as num).toInt(),
        weight: (j['weight'] as num?)?.toDouble() ?? 0,
        reps: (j['reps'] as num?)?.toInt() ?? 0,
        seconds: (j['seconds'] as num?)?.toInt() ?? 0,
        distance: (j['distance'] as num?)?.toDouble() ?? 0,
        note: j['note'] as String? ?? '',
      );
}

int compareSets(WorkoutSet a, WorkoutSet b) {
  final d = a.date.compareTo(b.date);
  return d != 0 ? d : a.createdAt.compareTo(b.createdAt);
}

/// One weekday of the training split; no exercises means a rest day.
class SplitDay {
  final String name;
  final List<String> exerciseIds;

  /// Suggested prescription per exercise id, e.g. '4×8' or '30 s'.
  final Map<String, String> targets;

  /// Exercise ids from [exerciseIds] that belong to the warm-up section.
  final Set<String> warmupIds;

  /// Exercise ids that continue the superset started by the previous exercise (A2, A3, ...).
  final Set<String> supersetIds;
  const SplitDay(this.name, this.exerciseIds,
      {this.targets = const {}, this.warmupIds = const {}, this.supersetIds = const {}});

  bool get isRest => exerciseIds.isEmpty;

  /// Planned exercises in order, split into warm-up and main work.
  List<String> get warmup => exerciseIds.where(warmupIds.contains).toList();
  List<String> get main => exerciseIds.where((id) => !warmupIds.contains(id)).toList();

  /// Superset badge for [id] in the given ordered list: 'A1', 'A2', 'B1'... or null.
  /// A group leader is an unflagged exercise followed by a flagged one; flagged ids are its members.
  static String? supersetBadge(List<String> ordered, String id, Set<String> supersetIds) {
    const letters = 'ABCDEFGH';
    var group = 0, pos = 0;
    for (var i = 0; i < ordered.length; i++) {
      final cur = ordered[i];
      final flagged = supersetIds.contains(cur);
      final startsGroup = !flagged && i + 1 < ordered.length && supersetIds.contains(ordered[i + 1]);
      if (!flagged && !startsGroup) {
        if (cur == id) return null;
        pos = 0;
        continue;
      }
      if (startsGroup || pos == 0) {
        group++;
        pos = 1;
      } else {
        pos++;
      }
      if (cur == id) return '${letters[group - 1]}$pos';
    }
    return null;
  }

  /// Prescription for [exercise]; template value or a sensible default for the kind.
  String targetFor(Exercise ex) =>
      targets[ex.id] ??
      switch (ex.kind) {
        ExerciseKind.weightReps => '4×10',
        ExerciseKind.bodyweight => '3×12',
        ExerciseKind.duration => '3×30 s',
        ExerciseKind.cardio => '20 min',
      };

  Map<String, dynamic> toJson() => {
        'name': name,
        'exerciseIds': exerciseIds,
        if (targets.isNotEmpty) 'targets': targets,
        if (warmupIds.isNotEmpty) 'warmupIds': warmupIds.toList(),
        if (supersetIds.isNotEmpty) 'supersetIds': supersetIds.toList(),
      };

  factory SplitDay.fromJson(Map<String, dynamic> j) => SplitDay(
        j['name'] as String? ?? '',
        List<String>.from(j['exerciseIds'] as List? ?? const []),
        targets: Map<String, String>.from(j['targets'] as Map? ?? const {}),
        warmupIds: {for (final id in j['warmupIds'] as List? ?? const []) id as String},
        supersetIds: {for (final id in j['supersetIds'] as List? ?? const []) id as String},
      );
}
