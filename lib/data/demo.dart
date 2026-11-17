import 'dates.dart';
import 'models.dart';
import 'store.dart';

/// In-memory store with sample data so the demo/offline mode (platforms without
/// Firebase, e.g. Windows, or the "Wypróbuj demo" button) shows a realistic app
/// instead of empty screens.
AppStore demoStore() {
  final store = AppStore.memory();
  final today_ = today();
  String key(int daysAgo) {
    final d = DateTime(today_.year, today_.month, today_.day - daysAgo);
    return dateKey(d);
  }

  for (final (days, kg, reps) in [
    (14, 80.0, 5),
    (11, 82.5, 5),
    (7, 85.0, 4),
    (3, 87.5, 3),
    (0, 90.0, 3),
  ]) {
    store.addSet(exerciseId: 'bench-press', date: key(days), weight: kg, reps: reps);
    store.addSet(exerciseId: 'bench-press', date: key(days), weight: kg - 5, reps: reps + 2);
  }
  for (final (days, kg, reps) in [(13, 60.0, 8), (6, 65.0, 8), (1, 70.0, 6)]) {
    store.addSet(exerciseId: 'back-squat', date: key(days), weight: kg, reps: reps);
  }
  for (final (days, s) in [(10, 45), (4, 60), (2, 75)]) {
    store.addSet(exerciseId: 'plank', date: key(days), seconds: s);
  }
  store.setSplit([
    SplitDay('Push', const ['bench-press', 'overhead-press']),
    SplitDay('Pull', const ['pull-up', 'barbell-row']),
    const SplitDay('', []),
    SplitDay('Nogi', const ['back-squat', 'plank']),
    const SplitDay('', []),
    const SplitDay('', []),
    const SplitDay('', []),
  ]);
  return store;
}
