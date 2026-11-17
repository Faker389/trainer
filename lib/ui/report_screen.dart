import 'package:flutter/material.dart';
import 'package:trainer_engine/trainer_engine.dart';

import '../data/dates.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'widgets.dart';

/// Post-set summary built from [ExerciseAnalyzer.endSet].
class ReportScreen extends StatelessWidget {
  final ExerciseDefinition exercise;
  final TechniqueAnalysis report;
  final Exercise? logExercise;
  const ReportScreen({super.key, required this.exercise, required this.report, this.logExercise});

  bool get _canLog =>
      logExercise != null &&
      report.repetitionCount > 0 &&
      (logExercise!.kind == ExerciseKind.weightReps || logExercise!.kind == ExerciseKind.bodyweight);

  Future<void> _logSet(BuildContext context) async {
    final store = StoreScope.read(context);
    final ex = logExercise!;
    final last = store.lastSetFor(ex.id);
    final ctrl = TextEditingController(text: last != null && last.weight > 0 ? fmtNum(last.weight) : '');
    final weight = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ex.kind == ExerciseKind.bodyweight ? 'Dodatkowy ciężar (kg)' : 'Ciężar (kg)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(helperText: '${report.repetitionCount} powtórzeń z analizy'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(ctx, parseNum(ctrl.text) ?? 0), child: const Text('Zapisz')),
        ],
      ),
    );
    if (weight == null || !context.mounted) return;
    store.addSet(exerciseId: ex.id, date: dateKey(today()), weight: weight, reps: report.repetitionCount);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seria zapisana w dzisiejszym treningu')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Scaffold(
      appBar: AppBar(title: Text('Podsumowanie: ${exercise.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Stat('Powtórzenia', '${r.repetitionCount}'),
              if (r.partialRepetitions > 0) _Stat('Niepełne', '${r.partialRepetitions}'),
              if (exercise.evaluationRules.isNotEmpty) ...[
                _Stat('Ocena techniki', r.averageTechniqueScore?.toString() ?? '–'),
                _Stat('Pewność analizy', '${(r.analysisConfidence * 100).round()}%'),
              ],
              if (r.consistency != null) _Stat('Powtarzalność', '${r.consistency}'),
            ],
          ),
          if (_canLog) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: Text('Zapisz w treningu: ${r.repetitionCount} powt.'),
              onPressed: () => _logSet(context),
            ),
          ],
          if (r.detectedErrors.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Wykryte błędy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            for (final e in r.detectedErrors)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.warning_amber, color: e.maxSeverity == Severity.high ? Colors.red : Colors.orange),
                title: Text(e.label),
                subtitle: Text('${e.correction}\nPowtórzenia: ${e.repIndices.join(', ')}'),
              ),
          ],
          if (r.recommendations.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Zalecenia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            for (final s in r.recommendations) Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $s')),
          ],
          const SizedBox(height: 20),
          for (final s in r.safetyNotes)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(s, style: TextStyle(color: context.shade(0.54), fontSize: 12)),
            ),
          const SizedBox(height: 24),
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Wróć')),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: context.shade(0.7))),
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
}
