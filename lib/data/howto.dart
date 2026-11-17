import 'package:trainer_engine/trainer_engine.dart';

import 'models.dart';

class HowTo {
  final List<String> steps;
  final List<String> tips;
  final List<String> mistakes;
  final String breathing;
  const HowTo(this.steps, this.tips, this.mistakes, this.breathing);
}

/// Instruction template per movement pattern; exercise-specific [Exercise.steps]
/// and engine checkpoints/rules override parts of it.
HowTo howToFor(Exercise ex, ExerciseDefinition def) {
  final muscles = ex.muscles.isEmpty ? 'docelowych mięśni' : ex.muscles.join(', ');
  final eq = ex.equipment.isEmpty ? 'sprzęt' : ex.equipment.toLowerCase();
  final steps = ex.steps ?? switch (ex.kind) {
        ExerciseKind.duration => [
            'Przygotuj miejsce i przyjmij pozycję wyjściową zgodnie z opisem ćwiczenia.',
            'Napnij brzuch i pośladki, ustaw ciało w jednej linii.',
            'Utrzymuj pozycję przez zaplanowany czas, oddychając spokojnie.',
            'Zakończ, gdy nie jesteś w stanie utrzymać poprawnej pozycji.',
          ],
        ExerciseKind.cardio => [
            'Zacznij od 5 minut spokojnej rozgrzewki.',
            'Ustal tempo, przy którym możesz utrzymać wysiłek przez cały zaplanowany czas.',
            'Utrzymuj wyprostowaną sylwetkę i równy rytm oddechu.',
            'Na koniec zwolnij na 3–5 minut, żeby się schłodzić.',
          ],
        _ => _stepsFor(ex, eq, muscles),
      };
  final tips = def.keyCheckpoints.isNotEmpty
      ? def.keyCheckpoints
      : const [
          'Rozgrzej się i zrób 1–2 serie rozgrzewkowe z mniejszym ciężarem.',
          'Zwiększaj ciężar dopiero wtedy, gdy wszystkie serie są technicznie poprawne.',
          'Zapisuj każdą serię, żeby aplikacja mogła liczyć postępy i rekordy.',
        ];
  final mistakes = def.evaluationRules.isNotEmpty
      ? {for (final r in def.evaluationRules) r.label}.take(6).toList()
      : const [
          'Zbyt duży ciężar kosztem techniki',
          'Skracanie zakresu ruchu',
          'Szybkie, niekontrolowane opuszczanie',
          'Wstrzymywanie oddechu przez całą serię',
        ];
  return HowTo(steps, tips, mistakes, _breathingFor(ex.pattern));
}

List<String> _stepsFor(Exercise ex, String eq, String muscles) => switch (ex.pattern) {
      TechniquePattern.squat => [
          'Ustaw $eq — na stojakach sztanga na wysokości klatki.',
          'Rozstaw stopy na szerokość barków, palce lekko na zewnątrz; łopatki ściągnięte.',
          'Weź głęboki wdech, napnij brzuch i schodź w dół, odchylając biodra, aż uda będą równoległe lub niżej.',
          'Wjedź do góry przez środek stopy; kolana cały czas w linii palców. Pracuje: $muscles.',
        ],
      TechniquePattern.legPress => [
          'Usiądź na suwnicy — plecy i pośladki przylegają do oparcia.',
          'Ustaw stopy na platformie na szerokość barków, na jej środku lub nieco wyżej.',
          'Odblokuj prowadnicę i opuszczaj platformę kontrolując, aż kolana osiągną ok. 90°.',
          'Wypchnij platformę piętami — na górze nie blokuj gwałtownie kolan. Pracuje: $muscles.',
        ],
      TechniquePattern.lunge => [
          'Stań prosto ($eq w dłoniach lub na karku), stopy w rozkroku bioder.',
          'Zrób duży krok i zejdź nisko — tylne kolano tuż nad podłogą.',
          'Tułów pionowy, ciężar na przedniej nodze, przednie kolano nad stopą.',
          'Odepchnij się przednią stopą i wróć do pozycji wyjściowej. Pracuje: $muscles.',
        ],
      TechniquePattern.hinge => [
          'Chwyć $eq, stopy na szerokość barków, kolana lekko ugięte.',
          'Odepchnij biodra do tyłu z prostymi plecami — ciężar schodzi wzdłuż nóg.',
          'Zejdź, aż poczujesz mocne napięcie w tylnej stronie ud i pośladkach.',
          'Wróć do pionu, prostując biodra i zaciskając pośladki na górze. Pracuje: $muscles.',
        ],
      TechniquePattern.hipExtension => [
          'Ustaw się na ławeczce/maszynie tak, by ruch zaczynał się w biodrze.',
          'Opuszczaj tułów lub nogę kontrolując, utrzymując neutralną sylwetkę.',
          'Prostuj biodra mocno i ściśnij pośladki w najwyższym punkcie.',
          'Wracaj powoli przez ok. 2–3 s. Pracuje: $muscles.',
        ],
      TechniquePattern.kneeExtension => [
          'Usiądź na maszynie, plecy przy oparciu, rolka na przodzie kostek.',
          'Prostuj nogi w kolanach płynnie, aż do pełnego wyprostu.',
          'Przytrzymaj chwilę na górze, ściskając czworogłowe.',
          'Opuszczaj powoli, bez spadania stosu. Pracuje: $muscles.',
        ],
      TechniquePattern.kneeFlexion => [
          'Ustaw maszynę — kolana w linii z osią ruchu, rolka za kostkami.',
          'Ugnij nogi, przyciągając rolkę w stronę pośladków.',
          'Ściśnij tył uda na dole ruchu przez chwilę.',
          'Wracaj powoli do pełnego wyprostu. Pracuje: $muscles.',
        ],
      TechniquePattern.press => [
          'Ułóż się stabilnie — łopatki ściągnięte i wbite, stopy pewnie na podłodze.',
          'Chwyć $eq pewnie, nadgarstki proste, łokcie pod ciężarem.',
          'Wyciskaj płynnie w górę, wydech przy największym wysiłku.',
          'Opuszczaj pod kontrolą do pozycji startowej przez ok. 2–3 s. Pracuje: $muscles.',
        ],
      TechniquePattern.pull => [
          'Chwyć $eq — klatka wypchnięta, łopatki złożone, tułów stabilny.',
          'Przyciągaj prowadząc ruch łoktiami — zacznij od zejścia łopatek, nie od zgięcia ramion.',
          'Ściśnij łopatki w najwyższym punkcie przez chwilę.',
          'Wracaj powoli do pełnego wyprostu ramion. Pracuje: $muscles.',
        ],
      TechniquePattern.curl => [
          'Stań z $eq, łokcie przyklejone do tułowia, nadgarstki proste.',
          'Uginaj ramiona podciągając ciężar ku górze — bez bujania tułowiem.',
          'Ściśnij biceps w najwyższym punkcie przez chwilę.',
          'Opuszczaj powoli do pełnego wyprostu. Pracuje: $muscles.',
        ],
      TechniquePattern.elbowExtension => [
          'Ustaw $eq — łokcie blisko głowy lub tułowia i cały czas nieruchome.',
          'Prostuj ramiona w łokciach, ruch tylko w stawie łokciowym.',
          'Ściśnij triceps w pełnym wyproście.',
          'Wracaj powoli, nie pozwalając łokciom rozjechać się na boki. Pracuje: $muscles.',
        ],
      TechniquePattern.raise => [
          'Stań prosto z $eq, tułów napięty, łokcie lekko ugięte.',
          'Unieś ramię/ramiona do wysokości barków, prowadząc łoktiami.',
          'Przytrzymaj chwilę na górze z napięciem w barkach.',
          'Opuszczaj powoli, bez machania. Pracuje: $muscles.',
        ],
      TechniquePattern.pullover => [
          'Ułóż się z $eq, ręce proste nad klatką, lekkie ugięcie w łokciach.',
          'Opuszczaj ciężar łukiem za głowę, rozciągając plecy i klatkę.',
          'Wracaj nad klatkę, prowadząc ruch mięśniami, nie z samych ramion.',
          'Zachowaj stałe, powolne tempo w obu kierunkach. Pracuje: $muscles.',
        ],
      TechniquePattern.crunch => [
          'Połóż się, kolana zgięte, dłonie przy głowie lub skrzyżowane na klatce.',
          'Zepnij brzuch i unieś łopatki nad podłoże — lędźwia zostają na dole.',
          'Nie ciągnij za szyję; ruch krótki, ale z maksymalnym spięciem.',
          'Opuszczaj powoli. Pracuje: $muscles.',
        ],
      TechniquePattern.legRaise => [
          'Ustaw pozycję ($eq), plecy stabilne, brzuch napięty.',
          'Unieś nogi lub kolana ku górze pracując brzuchem, nie zamachem bioder.',
          'Opuść powoli — nie pozwól nogom spadać swobodnie.',
          'Utrzymuj napięcie brzucha przez całą serię. Pracuje: $muscles.',
        ],
      TechniquePattern.calf => [
          'Stań na brzegu platformy ($eq), pięty w powietrzu.',
          'Wspinaj się maksymalnie wysoko na palce — ściśnij łydki na górze.',
          'Opuść pięty nisko, rozciągając łydki w najniższym punkcie.',
          'Ruch pełny i kontrolowany, bez odbijania. Pracuje: $muscles.',
        ],
      TechniquePattern.hold => [
          'Przyjmij pozycję zgodnie z opisem — ciało ustawione w jednej linii.',
          'Napnij brzuch, pośladki i docelowe mięśnie: $muscles.',
          'Utrzymuj pozycję zaplanowany czas, oddychając równo.',
          'Przerwij, gdy technika zaczyna siadać.',
        ],
        // Generic fallback (tracking and unknown patterns)
        _ => [
            'Przygotuj stanowisko i dobierz ciężar, z którym wykonasz wszystkie powtórzenia poprawnie.',
            'Przyjmij stabilną pozycję wyjściową: napięty brzuch, łopatki ustawione.',
            'Wykonaj ruch płynnie w pełnym zakresie, skupiając się na pracy mięśni: $muscles.',
            'Opuszczaj ciężar pod kontrolą przez ok. 2–3 s, bez odbijania i szarpania.',
            'Powtórz zaplanowaną liczbę razy, utrzymując tę samą technikę.',
          ],
    };

String _breathingFor(TechniquePattern p) => switch (p) {
      TechniquePattern.hold => 'Oddychaj spokojnie i równo przez cały czas trzymania — nie wstrzymuj powietrza.',
      TechniquePattern.crunch ||
      TechniquePattern.legRaise =>
        'Wydech przy spięciu brzucha, wdech przy powrocie.',
      TechniquePattern.squat ||
      TechniquePattern.legPress ||
      TechniquePattern.hinge ||
      TechniquePattern.hipExtension ||
      TechniquePattern.lunge =>
        'Wdech przed zejściem w dół (napnij brzuch), wydech przy wstawaniu.',
      _ => 'Wdech przed fazą opuszczania, wydech w trakcie największego wysiłku.',
    };
