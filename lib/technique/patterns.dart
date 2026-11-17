import 'package:trainer_engine/trainer_engine.dart';

import '../data/models.dart';

/// Engine definition used by the camera check: the dedicated one (with technique rules) when the engine has it,
/// otherwise a movement-pattern definition that calibrates, tracks the skeleton and counts reps.
ExerciseDefinition techniqueDefinitionFor(Exercise ex) =>
    (ex.engineId != null ? exercises[ex.engineId] : null) ?? patternDefinition(ex.pattern, ex.name);

bool hasFullAnalysis(Exercise ex) => ex.engineId != null && exercises.containsKey(ex.engineId);

bool countsReps(Exercise ex) =>
    hasFullAnalysis(ex) || (ex.pattern != TechniquePattern.hold && ex.pattern != TechniquePattern.tracking);

const _legs = ['leftShoulder', 'rightShoulder', 'leftHip', 'rightHip', 'leftKnee', 'rightKnee', 'leftAnkle', 'rightAnkle'];
const _arms = ['leftElbow', 'rightElbow', 'leftWrist', 'rightWrist'];
const _feet = ['leftFootIndex', 'rightFootIndex'];
const _occludable = ['leftHeel', 'rightHeel', 'leftFootIndex', 'rightFootIndex'];

const _fullBody = 'Całe ciało (razem ze stopami) musi być w kadrze, bo z niego liczona jest kalibracja.';
const _sideSetup = 'Postaw telefon bokiem do siebie, ok. 2,5–3 m dalej, na wysokości bioder. $_fullBody';
const _benchSetup =
    'Postaw telefon z boku ławki/maszyny, na wysokości tułowia, ok. 2–3 m dalej. $_fullBody Zacznij od kilku sekund bez ruchu.';
const _frontSetup = 'Postaw telefon przodem do siebie, ok. 2,5–3 m dalej, na wysokości klatki. $_fullBody';

/// Unreachable thresholds: the detector never starts a cycle, so only the skeleton and live metrics are shown.
const _noReps = (-1e9, 1e9);

class _Spec {
  final String signal;
  final String start;
  final (double, double) range;
  final double hysteresis, minRange;
  final String calibration;
  final CameraView view;
  final List<String> extra;
  final String setup;
  final List<String> metrics;

  /// Labels for the low / rising / high / falling states.
  final (String, String, String, String) labels;

  const _Spec({
    required this.signal,
    required this.start,
    required this.range,
    this.hysteresis = 5,
    this.minRange = 25,
    required this.calibration,
    this.view = CameraView.side,
    this.extra = const [],
    required this.setup,
    this.metrics = const [],
    required this.labels,
  });
}

const _specs = <TechniquePattern, _Spec>{
  TechniquePattern.squat: _Spec(
      signal: 'kneeAngle',
      start: 'high',
      range: (110, 155),
      minRange: 35,
      calibration: 'standing',
      setup: _sideSetup,
      metrics: ['hipAngle', 'trunkInclination'],
      labels: ('Dół', 'Wstawanie', 'Pozycja stojąca', 'Zejście')),
  TechniquePattern.legPress: _Spec(
      signal: 'kneeAngle',
      start: 'high',
      range: (110, 155),
      minRange: 35,
      calibration: 'any',
      setup: _benchSetup,
      labels: ('Dół', 'Wypychanie', 'Wyprost', 'Opuszczanie')),
  TechniquePattern.lunge: _Spec(
      signal: 'kneeAngle',
      start: 'high',
      range: (115, 155),
      minRange: 30,
      calibration: 'standing',
      setup: _sideSetup,
      metrics: ['trunkInclination'],
      labels: ('Dół', 'Wstawanie', 'Pozycja stojąca', 'Zejście')),
  TechniquePattern.hinge: _Spec(
      signal: 'hipAngle',
      start: 'high',
      range: (125, 160),
      calibration: 'standing',
      setup: _sideSetup,
      metrics: ['kneeAngle', 'trunkInclination'],
      labels: ('Skłon', 'Prostowanie', 'Wyprost', 'Pochylanie')),
  TechniquePattern.hipExtension: _Spec(
      signal: 'hipAngle',
      start: 'low',
      range: (125, 160),
      calibration: 'any',
      setup: _benchSetup,
      labels: ('Dół', 'Unoszenie bioder', 'Pełny wyprost', 'Opuszczanie')),
  TechniquePattern.kneeExtension: _Spec(
      signal: 'kneeAngle',
      start: 'low',
      range: (110, 155),
      calibration: 'any',
      setup: _benchSetup,
      labels: ('Ugięcie', 'Prostowanie', 'Wyprost', 'Opuszczanie')),
  TechniquePattern.kneeFlexion: _Spec(
      signal: 'kneeAngle',
      start: 'high',
      range: (105, 150),
      calibration: 'any',
      setup: _benchSetup,
      labels: ('Pełne ugięcie', 'Powrót', 'Wyprost', 'Uginanie')),
  TechniquePattern.press: _Spec(
      signal: 'elbowAngle',
      start: 'high',
      range: (100, 150),
      calibration: 'any',
      extra: _arms,
      setup: _benchSetup,
      metrics: ['shoulderAngle'],
      labels: ('Dół', 'Wyciskanie', 'Wyprost ramion', 'Opuszczanie')),
  TechniquePattern.pull: _Spec(
      signal: 'elbowAngle',
      start: 'high',
      range: (90, 145),
      calibration: 'any',
      extra: _arms,
      setup: _benchSetup,
      metrics: ['trunkInclination'],
      labels: ('Pełne przyciągnięcie', 'Powrót', 'Ramiona wyprostowane', 'Przyciąganie')),
  TechniquePattern.curl: _Spec(
      signal: 'elbowAngle',
      start: 'high',
      range: (75, 140),
      calibration: 'any',
      extra: _arms,
      setup: _sideSetup,
      metrics: ['shoulderAngle'],
      labels: ('Pełne ugięcie', 'Opuszczanie', 'Ramiona wyprostowane', 'Uginanie')),
  TechniquePattern.elbowExtension: _Spec(
      signal: 'elbowAngle',
      start: 'low',
      range: (95, 150),
      calibration: 'any',
      extra: _arms,
      setup: _sideSetup,
      labels: ('Ugięcie', 'Prostowanie', 'Wyprost', 'Powrót')),
  TechniquePattern.raise: _Spec(
      signal: 'shoulderAngle',
      start: 'low',
      range: (30, 70),
      calibration: 'standing',
      view: CameraView.front,
      extra: _arms,
      setup: _frontSetup,
      metrics: ['elbowAngle'],
      labels: ('Ramiona w dole', 'Unoszenie', 'Ramiona w górze', 'Opuszczanie')),
  TechniquePattern.pullover: _Spec(
      signal: 'shoulderAngle',
      start: 'high',
      range: (45, 110),
      calibration: 'any',
      extra: _arms,
      setup: _sideSetup,
      labels: ('Ramiona przy tułowiu', 'Powrót', 'Ramiona w górze', 'Ściąganie')),
  TechniquePattern.crunch: _Spec(
      signal: 'hipAngle',
      start: 'high',
      range: (95, 120),
      hysteresis: 4,
      minRange: 15,
      calibration: 'any',
      setup: _benchSetup,
      labels: ('Spięcie', 'Powrót', 'Pozycja wyjściowa', 'Unoszenie tułowia')),
  TechniquePattern.legRaise: _Spec(
      signal: 'hipAngle',
      start: 'high',
      range: (115, 155),
      calibration: 'any',
      setup: _benchSetup,
      labels: ('Nogi w górze', 'Opuszczanie', 'Nogi w dole', 'Unoszenie')),
  TechniquePattern.calf: _Spec(
      signal: 'ankleAngle',
      start: 'low',
      range: (118, 132),
      hysteresis: 3,
      minRange: 10,
      calibration: 'standing',
      extra: _feet,
      setup: '$_sideSetup Stopy muszą być dobrze widoczne.',
      labels: ('Pięty w dole', 'Wspięcie', 'Na palcach', 'Opuszczanie')),
  TechniquePattern.hold: _Spec(
      signal: 'bodyLineAngle',
      start: 'high',
      range: _noReps,
      calibration: 'any',
      setup: _benchSetup,
      metrics: ['hipAngle'],
      labels: ('', '', 'Pozycja', '')),
  TechniquePattern.tracking: _Spec(
      signal: 'trunkInclination',
      start: 'high',
      range: _noReps,
      calibration: 'any',
      setup: _sideSetup,
      metrics: ['kneeAngle', 'elbowAngle'],
      labels: ('', '', 'Ruch', '')),
};

ExerciseDefinition patternDefinition(TechniquePattern pattern, String name) {
  final s = _specs[pattern]!;
  final (lowL, risingL, highL, fallingL) = s.labels;
  final fromLow = s.start == 'low';
  return ExerciseDefinition(
    id: 'pattern-${pattern.name}',
    name: name,
    family: pattern.name,
    requiredLandmarks: [..._legs, ...s.extra],
    requireSides: 'near',
    preferredCameraAngle: s.view,
    allowedCameraAngles: const [CameraView.side, CameraView.frontSide, CameraView.front, CameraView.rear],
    cameraSetup: s.setup,
    calibrationPose: s.calibration,
    occludableLandmarks: s.extra.contains('leftFootIndex') ? const ['leftHeel', 'rightHeel'] : _occludable,
    movementPhases: [
      PhaseDefinition('LOW', fromLow ? PhaseKind.start : PhaseKind.end, lowL),
      PhaseDefinition('RISING', PhaseKind.concentric, risingL),
      PhaseDefinition('HIGH', fromLow ? PhaseKind.end : PhaseKind.start, highL),
      PhaseDefinition('FALLING', PhaseKind.eccentric, fallingL),
    ],
    repetition: RepetitionConfig(
      signal: s.signal,
      startPosition: s.start,
      lowThreshold: s.range.$1,
      highThreshold: s.range.$2,
      hysteresis: s.hysteresis,
      minPhaseMs: 150,
      minRepMs: 700,
      maxRepMs: 20000,
      minRange: s.minRange,
      phases: const RepPhases(low: 'LOW', rising: 'RISING', high: 'HIGH', falling: 'FALLING'),
      countAt: fromLow ? 'high' : 'low',
      requireReturn: true,
    ),
    evaluationRules: const [],
    scoringConfiguration: const {},
    recognition: const [],
    comparisonFeatures: s.metrics,
    keyCheckpoints: const [],
  );
}
