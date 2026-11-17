import 'models.dart';

class SplitTemplate {
  final String name;
  final String description;
  final String emoji;

  /// Monday..Sunday. For [weekly] == false this is a single workout
  /// ([days].length == 1) that can be dropped into any weekday.
  final List<SplitDay> days;
  final bool weekly;
  const SplitTemplate(this.name, this.description, this.emoji, this.days, {this.weekly = true});
}

const _rest = SplitDay('', []);

const _push = SplitDay('Push', [
  'bench-press',
  'incline-db-press',
  'overhead-press',
  'lateral-raise',
  'triceps-pushdown',
  'overhead-triceps-extension',
], targets: {
  'bench-press': '4×8',
  'incline-db-press': '3×10',
  'overhead-press': '3×10',
  'lateral-raise': '3×15',
  'triceps-pushdown': '3×12',
  'overhead-triceps-extension': '3×12',
});
const _pull = SplitDay('Pull', ['deadlift', 'pull-up', 'barbell-row', 'lat-pulldown', 'face-pull', 'barbell-curl', 'hammer-curl'], targets: {
  'deadlift': '3×5',
  'pull-up': '4×8',
  'barbell-row': '4×10',
  'lat-pulldown': '3×10',
  'face-pull': '3×15',
  'barbell-curl': '3×10',
  'hammer-curl': '3×12',
});
const _legs = SplitDay('Nogi', ['back-squat', 'romanian-deadlift', 'leg-press', 'lying-leg-curl', 'standing-calf-raise'], targets: {
  'back-squat': '4×8',
  'romanian-deadlift': '3×10',
  'leg-press': '3×12',
  'lying-leg-curl': '3×12',
  'standing-calf-raise': '4×15',
});
const _upper = SplitDay('Góra', ['bench-press', 'barbell-row', 'overhead-press', 'lat-pulldown', 'db-curl', 'triceps-pushdown'], targets: {
  'bench-press': '4×8',
  'barbell-row': '4×8',
  'overhead-press': '3×10',
  'lat-pulldown': '3×10',
  'db-curl': '3×12',
  'triceps-pushdown': '3×12',
});
const _lower = SplitDay('Dół', ['back-squat', 'romanian-deadlift', 'leg-press', 'seated-leg-curl', 'standing-calf-raise', 'plank'], targets: {
  'back-squat': '4×8',
  'romanian-deadlift': '3×10',
  'leg-press': '3×12',
  'seated-leg-curl': '3×12',
  'standing-calf-raise': '4×15',
  'plank': '3×45 s',
});
const _fbw = SplitDay('FBW', ['back-squat', 'bench-press', 'barbell-row', 'overhead-press', 'romanian-deadlift', 'plank'], targets: {
  'back-squat': '4×8',
  'bench-press': '4×8',
  'barbell-row': '3×10',
  'overhead-press': '3×10',
  'romanian-deadlift': '3×10',
  'plank': '3×45 s',
});

const _cardioRun = SplitDay('Bieg + brzuch', ['running', 'plank', 'lying-leg-raise'], targets: {
  'running': '25 min',
  'plank': '3×45 s',
  'lying-leg-raise': '3×12',
});
const _cardioBike = SplitDay('Rower + core', ['stationary-bike', 'crunch', 'side-plank'], targets: {
  'stationary-bike': '30 min',
  'crunch': '3×15',
  'side-plank': '3×30 s',
});
const _cardioMix = SplitDay('Wioślarz + skakanka', ['rowing-machine', 'jump-rope', 'russian-twist'], targets: {
  'rowing-machine': '20 min',
  'jump-rope': '5×1 min',
  'russian-twist': '3×20',
});

const splitTemplates = <SplitTemplate>[
  SplitTemplate('FBW (całe ciało)', '3 dni, idealne na start', '🏋️', [_fbw, _rest, _fbw, _rest, _fbw, _rest, _rest]),
  SplitTemplate('Push / Pull / Nogi', '6 dni, każda partia 2× w tygodniu', '🔁',
      [_push, _pull, _legs, _push, _pull, _legs, _rest]),
  SplitTemplate('Góra / Dół', '4 dni treningowe', '⚖️', [_upper, _lower, _rest, _upper, _lower, _rest, _rest]),
  SplitTemplate('Split klasyczny', '5 dni, jedna partia dziennie', '📅', [
    SplitDay('Klatka', ['bench-press', 'incline-db-press', 'db-fly', 'chest-dips', 'cable-crossover'], targets: {
      'bench-press': '4×8',
      'incline-db-press': '3×10',
      'db-fly': '3×12',
      'chest-dips': '3×10',
      'cable-crossover': '3×15',
    }),
    SplitDay('Plecy', ['deadlift', 'pull-up', 'barbell-row', 'seated-cable-row', 'straight-arm-pulldown'], targets: {
      'deadlift': '3×5',
      'pull-up': '4×8',
      'barbell-row': '4×10',
      'seated-cable-row': '3×10',
      'straight-arm-pulldown': '3×12',
    }),
    SplitDay('Nogi', ['back-squat', 'leg-press', 'romanian-deadlift', 'leg-extension', 'lying-leg-curl', 'standing-calf-raise'], targets: {
      'back-squat': '4×8',
      'leg-press': '3×12',
      'romanian-deadlift': '3×10',
      'leg-extension': '3×12',
      'lying-leg-curl': '3×12',
      'standing-calf-raise': '4×15',
    }),
    SplitDay('Barki', ['overhead-press', 'lateral-raise', 'front-raise', 'rear-delt-fly', 'shrug'], targets: {
      'overhead-press': '4×8',
      'lateral-raise': '3×15',
      'front-raise': '3×12',
      'rear-delt-fly': '3×15',
      'shrug': '4×12',
    }),
    SplitDay('Ramiona', ['barbell-curl', 'close-grip-bench', 'hammer-curl', 'skull-crusher', 'cable-curl', 'triceps-pushdown'], targets: {
      'barbell-curl': '3×10',
      'close-grip-bench': '3×10',
      'hammer-curl': '3×12',
      'skull-crusher': '3×10',
      'cable-curl': '3×12',
      'triceps-pushdown': '3×12',
    }),
    _rest,
    _rest,
  ]),
  SplitTemplate('Cardio', '3× cardio w tygodniu + spacer', '🏃', [
    _cardioRun,
    _rest,
    _cardioBike,
    _rest,
    _cardioMix,
    SplitDay('Spacer regeneracyjny', ['walking'], targets: {'walking': '30 min'}),
    _rest,
  ]),
  SplitTemplate('Trening 30 min', 'Szybki obwód całego ciała — minimum sprzętu', '⏱️', [
    SplitDay('Trening 30 min',
        ['jumping-jack', 'goblet-squat', 'push-up', 'db-row', 'glute-bridge', 'mountain-climber', 'plank'],
        targets: {
          'jumping-jack': '3×60 s',
          'goblet-squat': '3×12',
          'push-up': '3×12',
          'db-row': '3×12',
          'glute-bridge': '3×15',
          'mountain-climber': '3×40 s',
          'plank': '3×45 s',
        }),
  ], weekly: false),
  SplitTemplate('Szybkie rozciąganie', '10–15 min na całe ciało — po treningu lub na rozluźnienie', '🧘', [
    SplitDay('Rozciąganie', [
      'cat-cow',
      'hip-flexor-stretch',
      'hamstring-stretch',
      'quad-stretch',
      'pigeon-stretch',
      'chest-stretch',
      'shoulder-stretch',
      'child-pose',
    ], targets: {
      'cat-cow': '8 powt.',
      'hip-flexor-stretch': '60 s / stronę',
      'hamstring-stretch': '60 s / stronę',
      'quad-stretch': '45 s / stronę',
      'pigeon-stretch': '60 s / stronę',
      'chest-stretch': '45 s / stronę',
      'shoulder-stretch': '45 s / stronę',
      'child-pose': '90 s',
    }),
  ], weekly: false),
];
