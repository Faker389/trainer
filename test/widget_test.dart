import 'package:flutter_test/flutter_test.dart';
import 'package:trainer/data/catalog.dart';
import 'package:trainer/data/codec.dart';
import 'package:trainer/data/models.dart';
import 'package:trainer/data/stats.dart';
import 'package:trainer/data/store.dart';
import 'package:trainer/main.dart';
import 'package:trainer/technique/patterns.dart';

void main() {
  testWidgets('App starts on the workout tab', (WidgetTester tester) async {
    await tester.pumpWidget(TrainerApp(offlineStore: AppStore.memory()));
    await tester.pumpAndSettle();

    expect(find.text('Dodaj ćwiczenie'), findsOneWidget);
    expect(find.text('Ćwiczenia'), findsOneWidget);
  });

  test('Every catalog exercise has a technique definition', () {
    final ids = <String>{};
    for (final e in exerciseCatalog) {
      expect(ids.add(e.id), isTrue, reason: 'duplicate id ${e.id}');
      expect(techniqueDefinitionFor(e).name, isNotEmpty);
    }
  });

  test('PRs and 1RM', () {
    final store = AppStore.memory();
    final bench = store.exercise('bench-press')!;
    final a = store.addSet(exerciseId: bench.id, date: '2026-11-01', weight: 100, reps: 5);
    final b = store.addSet(exerciseId: bench.id, date: '2026-11-03', weight: 100, reps: 3);
    final c = store.addSet(exerciseId: bench.id, date: '2026-11-05', weight: 105, reps: 3);
    final stats = store.stats(bench);
    expect(stats.prIds, containsAll([a.id, c.id]));
    expect(stats.prIds.contains(b.id), isFalse);
    expect(stats.bestE1rm, closeTo(epley1rm(100, 5), 1e-9));
    expect(stats.repRecords[3]!.weight, 105);
    expect(stats.days.length, 3);
    expect(bench.kind, ExerciseKind.weightReps);
  });

  test('Month codec round-trips sets and tombstones', () {
    final store = AppStore.memory();
    store.addSet(exerciseId: 'bench-press', date: '2026-11-01', weight: 102.5, reps: 5);
    store.addSet(exerciseId: 'plank', date: '2026-11-14', seconds: 90);
    final gone = store.addSet(exerciseId: 'bench-press', date: '2026-11-02', weight: 60, reps: 10);
    store.deleteSet(gone.id);

    final encoded = encodeMonth(store.monthSets('2026-11'), store.monthTombstones('2026-11'));
    final (sets, tomb) = decodeMonth('2026-11', encoded);
    expect(sets.length, 2);
    expect(sets.first.weight, 102.5);
    expect(sets.first.date, '2026-11-01');
    expect(sets.last.seconds, 90);
    expect(tomb.keys, [gone.id]);
    expect(encoded['d']!.length, lessThan(80));
  });

  test('Merge keeps newest edit and honours deletions', () {
    const base = WorkoutSet(id: 'a', exerciseId: 'x', date: '2026-11-01', createdAt: 1000, weight: 50, reps: 5);
    final edited = base.copyWith(weight: 55, updatedAt: 2000);
    const other = WorkoutSet(id: 'b', exerciseId: 'x', date: '2026-11-02', createdAt: 1500, reps: 8);
    final (sets, _) = mergeMonth([edited], {}, [base, other], {'b': 1600});
    expect(sets.map((s) => s.id), ['a']);
    expect(sets.single.weight, 55);

    final store = AppStore.memory();
    store.setSplitDay(1, const SplitDay('Push', ['bench-press']));
    final meta = decodeMeta(store.metaJson);
    expect(meta.split.first.exerciseIds, ['bench-press']);
  });
}
