import 'models.dart';

const _bb = 'Sztanga';
const _db = 'Hantle';
const _cable = 'Wyciąg';
const _machine = 'Maszyna';
const _bw = 'Masa ciała';
const _none = 'Bez sprzętu';

const _chest = MuscleCategory.chest;
const _back = MuscleCategory.back;
const _legs = MuscleCategory.legs;
const _glutes = MuscleCategory.glutes;
const _shoulders = MuscleCategory.shoulders;
const _biceps = MuscleCategory.biceps;
const _triceps = MuscleCategory.triceps;
const _forearms = MuscleCategory.forearms;
const _core = MuscleCategory.core;
const _calves = MuscleCategory.calves;
const _cardio = MuscleCategory.cardio;

const _wr = ExerciseKind.weightReps;
const _bwk = ExerciseKind.bodyweight;
const _time = ExerciseKind.duration;
const _dist = ExerciseKind.cardio;

const exerciseCatalog = <Exercise>[
  // Klatka piersiowa
  Exercise('bench-press', 'Wyciskanie sztangi na ławce płaskiej', _chest, _wr, _bb,
      ['klatka piersiowa', 'triceps', 'przedni akton barków'], TechniquePattern.press),
  Exercise('incline-bench-press', 'Wyciskanie sztangi na ławce skośnej', _chest, _wr, _bb,
      ['górna część klatki', 'przedni akton barków', 'triceps'], TechniquePattern.press),
  Exercise('decline-bench-press', 'Wyciskanie sztangi na ławce ujemnej', _chest, _wr, _bb,
      ['dolna część klatki', 'triceps'], TechniquePattern.press),
  Exercise('db-bench-press', 'Wyciskanie hantli na ławce płaskiej', _chest, _wr, _db,
      ['klatka piersiowa', 'triceps', 'przedni akton barków'], TechniquePattern.press),
  Exercise('incline-db-press', 'Wyciskanie hantli na ławce skośnej', _chest, _wr, _db,
      ['górna część klatki', 'przedni akton barków'], TechniquePattern.press),
  Exercise('db-fly', 'Rozpiętki z hantlami', _chest, _wr, _db, ['klatka piersiowa'], TechniquePattern.tracking),
  Exercise('cable-crossover', 'Rozpiętki na bramie', _chest, _wr, _cable, ['klatka piersiowa'],
      TechniquePattern.tracking),
  Exercise('pec-deck', 'Butterfly (maszyna)', _chest, _wr, _machine, ['klatka piersiowa'], TechniquePattern.tracking),
  Exercise('chest-press-machine', 'Wyciskanie na maszynie (klatka)', _chest, _wr, _machine,
      ['klatka piersiowa', 'triceps'], TechniquePattern.press),
  Exercise('push-up', 'Pompki', _chest, _bwk, _bw, ['klatka piersiowa', 'triceps', 'brzuch'], TechniquePattern.press),
  Exercise('chest-dips', 'Pompki na poręczach (dipy)', _chest, _bwk, _bw, ['dolna część klatki', 'triceps'],
      TechniquePattern.press),

  // Plecy
  Exercise('deadlift', 'Martwy ciąg klasyczny', _back, _wr, _bb,
      ['prostowniki grzbietu', 'pośladki', 'dwugłowe uda', 'czworogłowe uda'], TechniquePattern.hinge,
      engineId: 'conventional-deadlift'),
  Exercise('pull-up', 'Podciąganie nachwytem', _back, _bwk, 'Drążek', ['najszerszy grzbietu', 'biceps'],
      TechniquePattern.pull),
  Exercise('chin-up', 'Podciąganie podchwytem', _back, _bwk, 'Drążek', ['najszerszy grzbietu', 'biceps'],
      TechniquePattern.pull),
  Exercise('lat-pulldown', 'Ściąganie drążka wyciągu górnego', _back, _wr, _cable, ['najszerszy grzbietu', 'biceps'],
      TechniquePattern.pull),
  Exercise('barbell-row', 'Wiosłowanie sztangą w opadzie', _back, _wr, _bb,
      ['najszerszy grzbietu', 'czworoboczny', 'równoległoboczne', 'biceps'], TechniquePattern.pull),
  Exercise('db-row', 'Wiosłowanie hantlem jednorącz', _back, _wr, _db, ['najszerszy grzbietu', 'biceps'],
      TechniquePattern.pull),
  Exercise('seated-cable-row', 'Wiosłowanie na wyciągu dolnym', _back, _wr, _cable,
      ['najszerszy grzbietu', 'równoległoboczne'], TechniquePattern.pull),
  Exercise('t-bar-row', 'Wiosłowanie T-bar', _back, _wr, _bb, ['najszerszy grzbietu', 'czworoboczny'],
      TechniquePattern.pull),
  Exercise('straight-arm-pulldown', 'Ściąganie prostymi rękami na wyciągu', _back, _wr, _cable,
      ['najszerszy grzbietu'], TechniquePattern.pullover),
  Exercise('back-extension', 'Wyprosty tułowia (hiperekstensje)', _back, _bwk, 'Ławka rzymska',
      ['prostowniki grzbietu', 'pośladki'], TechniquePattern.hinge),
  Exercise('shrug', 'Szrugsy (wzruszanie barkami)', _back, _wr, _db, ['czworoboczny (góra)'],
      TechniquePattern.tracking),
  Exercise('face-pull', 'Face pull', _back, _wr, _cable, ['tylny akton barków', 'równoległoboczne'],
      TechniquePattern.pull),

  // Nogi
  Exercise('back-squat', 'Przysiad ze sztangą', _legs, _wr, _bb, ['czworogłowe uda', 'pośladki', 'przywodziciele'],
      TechniquePattern.squat,
      engineId: 'back-squat'),
  Exercise('front-squat', 'Przysiad przedni', _legs, _wr, _bb, ['czworogłowe uda', 'pośladki', 'brzuch'],
      TechniquePattern.squat),
  Exercise('goblet-squat', 'Przysiad goblet', _legs, _wr, _db, ['czworogłowe uda', 'pośladki'],
      TechniquePattern.squat),
  Exercise('hack-squat', 'Hack przysiad (maszyna)', _legs, _wr, _machine, ['czworogłowe uda'],
      TechniquePattern.legPress),
  Exercise('leg-press', 'Wypychanie nóg na suwnicy', _legs, _wr, _machine, ['czworogłowe uda', 'pośladki'],
      TechniquePattern.legPress),
  Exercise('bulgarian-split-squat', 'Przysiad bułgarski', _legs, _wr, _db, ['czworogłowe uda', 'pośladki'],
      TechniquePattern.lunge),
  Exercise('lunge', 'Wykroki', _legs, _wr, _db, ['czworogłowe uda', 'pośladki'], TechniquePattern.lunge),
  Exercise('walking-lunge', 'Wykroki chodzone', _legs, _wr, _db, ['czworogłowe uda', 'pośladki'],
      TechniquePattern.lunge),
  Exercise('step-up', 'Wejścia na skrzynię', _legs, _wr, _db, ['czworogłowe uda', 'pośladki'], TechniquePattern.lunge),
  Exercise('leg-extension', 'Prostowanie nóg na maszynie', _legs, _wr, _machine, ['czworogłowe uda'],
      TechniquePattern.kneeExtension),
  Exercise('lying-leg-curl', 'Uginanie nóg leżąc', _legs, _wr, _machine, ['dwugłowe uda'],
      TechniquePattern.kneeFlexion),
  Exercise('seated-leg-curl', 'Uginanie nóg siedząc', _legs, _wr, _machine, ['dwugłowe uda'],
      TechniquePattern.kneeFlexion),
  Exercise('sumo-deadlift', 'Martwy ciąg sumo', _legs, _wr, _bb, ['pośladki', 'przywodziciele', 'czworogłowe uda'],
      TechniquePattern.hinge),

  // Pośladki
  Exercise('romanian-deadlift', 'Rumuński martwy ciąg', _glutes, _wr, _bb,
      ['dwugłowe uda', 'pośladki', 'prostowniki grzbietu'], TechniquePattern.hinge,
      engineId: 'romanian-deadlift'),
  Exercise('hip-thrust', 'Hip thrust ze sztangą', _glutes, _wr, _bb, ['pośladki', 'dwugłowe uda'],
      TechniquePattern.hipExtension),
  Exercise('glute-bridge', 'Mostek biodrowy', _glutes, _bwk, _bw, ['pośladki'], TechniquePattern.hipExtension),
  Exercise('good-morning', 'Good morning (skłony ze sztangą)', _glutes, _wr, _bb,
      ['dwugłowe uda', 'prostowniki grzbietu'], TechniquePattern.hinge),
  Exercise('cable-kickback', 'Odwodzenie nogi w tył na wyciągu', _glutes, _wr, _cable, ['pośladki'],
      TechniquePattern.tracking),
  Exercise('hip-abduction', 'Odwodzenie nóg na maszynie', _glutes, _wr, _machine, ['pośladek średni'],
      TechniquePattern.tracking),

  // Barki
  Exercise('overhead-press', 'Wyciskanie żołnierskie (OHP)', _shoulders, _wr, _bb, ['barki', 'triceps', 'brzuch'],
      TechniquePattern.press),
  Exercise('db-shoulder-press', 'Wyciskanie hantli nad głowę', _shoulders, _wr, _db, ['barki', 'triceps'],
      TechniquePattern.press),
  Exercise('arnold-press', 'Wyciskanie Arnolda', _shoulders, _wr, _db, ['barki'], TechniquePattern.press),
  Exercise('machine-shoulder-press', 'Wyciskanie nad głowę na maszynie', _shoulders, _wr, _machine,
      ['barki', 'triceps'], TechniquePattern.press),
  Exercise('lateral-raise', 'Unoszenie hantli bokiem', _shoulders, _wr, _db, ['boczny akton barków'],
      TechniquePattern.raise),
  Exercise('cable-lateral-raise', 'Unoszenie ramienia bokiem na wyciągu', _shoulders, _wr, _cable,
      ['boczny akton barków'], TechniquePattern.raise),
  Exercise('front-raise', 'Unoszenie hantli przodem', _shoulders, _wr, _db, ['przedni akton barków'],
      TechniquePattern.raise),
  Exercise('rear-delt-fly', 'Odwrotne rozpiętki', _shoulders, _wr, _db, ['tylny akton barków'],
      TechniquePattern.tracking),
  Exercise('upright-row', 'Wiosłowanie sztangą wzdłuż tułowia', _shoulders, _wr, _bb, ['barki', 'czworoboczny'],
      TechniquePattern.pull),

  // Biceps
  Exercise('barbell-curl', 'Uginanie ramion ze sztangą', _biceps, _wr, _bb, ['biceps'], TechniquePattern.curl),
  Exercise('db-curl', 'Uginanie ramion z hantlami', _biceps, _wr, _db, ['biceps'], TechniquePattern.curl),
  Exercise('hammer-curl', 'Uginanie młotkowe', _biceps, _wr, _db, ['biceps', 'ramienny', 'przedramiona'],
      TechniquePattern.curl),
  Exercise('preacher-curl', 'Uginanie na modlitewniku', _biceps, _wr, _bb, ['biceps'], TechniquePattern.curl),
  Exercise('cable-curl', 'Uginanie ramion na wyciągu', _biceps, _wr, _cable, ['biceps'], TechniquePattern.curl),
  Exercise('concentration-curl', 'Uginanie w skupieniu', _biceps, _wr, _db, ['biceps'], TechniquePattern.curl),
  Exercise('incline-db-curl', 'Uginanie hantli na ławce skośnej', _biceps, _wr, _db, ['biceps (głowa długa)'],
      TechniquePattern.curl),

  // Triceps
  Exercise('close-grip-bench', 'Wyciskanie wąskim chwytem', _triceps, _wr, _bb, ['triceps', 'klatka piersiowa'],
      TechniquePattern.press),
  Exercise('skull-crusher', 'Wyciskanie francuskie leżąc', _triceps, _wr, _bb, ['triceps'], TechniquePattern.press),
  Exercise('triceps-pushdown', 'Prostowanie ramion na wyciągu', _triceps, _wr, _cable, ['triceps'],
      TechniquePattern.elbowExtension),
  Exercise('overhead-triceps-extension', 'Wyciskanie francuskie nad głową', _triceps, _wr, _db,
      ['triceps (głowa długa)'], TechniquePattern.press),
  Exercise('bench-dips', 'Dipy na ławce', _triceps, _bwk, _bw, ['triceps'], TechniquePattern.press),
  Exercise('triceps-kickback', 'Prostowanie ramienia w opadzie', _triceps, _wr, _db, ['triceps'],
      TechniquePattern.elbowExtension),

  // Przedramiona
  Exercise('wrist-curl', 'Uginanie nadgarstków', _forearms, _wr, _bb, ['zginacze przedramion'],
      TechniquePattern.tracking),
  Exercise('reverse-curl', 'Uginanie ramion nachwytem', _forearms, _wr, _bb, ['ramienny', 'przedramiona'],
      TechniquePattern.curl),
  Exercise('farmer-walk', 'Spacer farmera', _forearms, _time, _db, ['przedramiona', 'czworoboczny', 'brzuch'],
      TechniquePattern.tracking),
  Exercise('dead-hang', 'Zwis na drążku', _forearms, _time, 'Drążek', ['przedramiona', 'chwyt'],
      TechniquePattern.hold),

  // Brzuch
  Exercise('plank', 'Deska (plank)', _core, _time, _none, ['brzuch', 'mięśnie głębokie'], TechniquePattern.hold),
  Exercise('side-plank', 'Deska bokiem', _core, _time, _none, ['skośne brzucha'], TechniquePattern.hold),
  Exercise('crunch', 'Brzuszki', _core, _bwk, _none, ['prosty brzucha'], TechniquePattern.crunch),
  Exercise('sit-up', 'Siady z leżenia', _core, _bwk, _none, ['prosty brzucha', 'zginacze bioder'],
      TechniquePattern.crunch),
  Exercise('cable-crunch', 'Allahy (spięcia na wyciągu)', _core, _wr, _cable, ['prosty brzucha'],
      TechniquePattern.crunch),
  Exercise('hanging-leg-raise', 'Unoszenie nóg w zwisie', _core, _bwk, 'Drążek', ['prosty brzucha', 'zginacze bioder'],
      TechniquePattern.legRaise),
  Exercise('lying-leg-raise', 'Unoszenie nóg leżąc', _core, _bwk, _none, ['prosty brzucha (dół)'],
      TechniquePattern.legRaise),
  Exercise('russian-twist', 'Russian twist', _core, _bwk, _none, ['skośne brzucha'], TechniquePattern.tracking),
  Exercise('ab-wheel', 'Kółko do brzucha (ab wheel)', _core, _bwk, 'Kółko', ['brzuch', 'najszerszy grzbietu'],
      TechniquePattern.hipExtension),
  Exercise('mountain-climber', 'Wspinaczka (mountain climbers)', _core, _time, _none, ['brzuch', 'barki'],
      TechniquePattern.tracking),

  // Łydki
  Exercise('standing-calf-raise', 'Wspięcia na palce stojąc', _calves, _wr, _machine, ['łydki (brzuchaty)'],
      TechniquePattern.calf),
  Exercise('seated-calf-raise', 'Wspięcia na palce siedząc', _calves, _wr, _machine, ['łydki (płaszczkowaty)'],
      TechniquePattern.calf),
  Exercise('leg-press-calf-raise', 'Wspięcia na palce na suwnicy', _calves, _wr, _machine, ['łydki'],
      TechniquePattern.calf),

  // Cardio
  Exercise('running', 'Bieganie', _cardio, _dist, _none, ['całe ciało'], TechniquePattern.tracking),
  Exercise('treadmill', 'Bieżnia', _cardio, _dist, _machine, ['całe ciało'], TechniquePattern.tracking),
  Exercise('stationary-bike', 'Rower stacjonarny', _cardio, _dist, _machine, ['nogi'], TechniquePattern.tracking),
  Exercise('rowing-machine', 'Wioślarz (ergometr)', _cardio, _dist, _machine, ['całe ciało'],
      TechniquePattern.tracking),
  Exercise('elliptical', 'Orbitrek', _cardio, _dist, _machine, ['całe ciało'], TechniquePattern.tracking),
  Exercise('stair-climber', 'Schody (stepper)', _cardio, _dist, _machine, ['nogi', 'pośladki'],
      TechniquePattern.tracking),
  Exercise('jump-rope', 'Skakanka', _cardio, _time, 'Skakanka', ['łydki', 'kondycja'], TechniquePattern.tracking),
  Exercise('walking', 'Marsz', _cardio, _dist, _none, ['nogi'], TechniquePattern.tracking),
  Exercise('jumping-jack', 'Pajacyki', _cardio, _time, _none, ['całe ciało'], TechniquePattern.tracking),
  Exercise('burpee', 'Burpees', _cardio, _bwk, _none, ['całe ciało'], TechniquePattern.tracking),

  // Rozciąganie
  Exercise('cat-cow', 'Koci grzbiet (cat-cow)', _core, _time, _none, ['kręgosłup', 'brzuch'],
      TechniquePattern.tracking),
  Exercise('child-pose', 'Pozycja dziecka', _back, _time, _none, ['plecy', 'biodra'], TechniquePattern.hold),
  Exercise('hip-flexor-stretch', 'Klęk – rozciąganie bioder', _legs, _time, _none, ['zginacze bioder'],
      TechniquePattern.hold),
  Exercise('hamstring-stretch', 'Rozciąganie tyłu uda', _legs, _time, _none, ['dwugłowe uda'],
      TechniquePattern.hold),
  Exercise('quad-stretch', 'Rozciąganie czworogłowego stojąc', _legs, _time, _none, ['czworogłowe uda'],
      TechniquePattern.hold),
  Exercise('pigeon-stretch', 'Gołębia (rozciąganie pośladków)', _glutes, _time, _none, ['pośladki', 'biodra'],
      TechniquePattern.hold),
  Exercise('chest-stretch', 'Rozciąganie klatki w futrynie', _chest, _time, _none, ['klatka piersiowa'],
      TechniquePattern.hold),
  Exercise('shoulder-stretch', 'Przeciąganie ramienia przez klatkę', _shoulders, _time, _none,
      ['tylny akton barków'], TechniquePattern.hold),
  Exercise('triceps-stretch', 'Rozciąganie tricepsów za głową', _triceps, _time, _none, ['triceps'],
      TechniquePattern.hold),
];
