import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'exercise_browser.dart';
import 'exercise_screen.dart';
import 'technique_setup_screen.dart';
import 'widgets.dart';

class ExercisesTab extends StatelessWidget {
  const ExercisesTab({super.key});

  Future<void> _delete(BuildContext context, Exercise e) async {
    if (!e.custom) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Usunąć „${e.name}”?'),
        content: const Text('Zostaną usunięte także wszystkie zapisane serie tego ćwiczenia.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Usuń')),
        ],
      ),
    );
    if (ok == true && context.mounted) StoreScope.read(context).deleteCustomExercise(e.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ćwiczenia')),
        body: ExerciseBrowser(
          onTap: (e) => openExercise(context, e.id),
          onLongPress: (e) => _delete(context, e),
          trailing: (e) => IconButton(
            tooltip: 'Sprawdź technikę',
            icon: Icon(Icons.videocam_outlined, color: context.shade(0.45)),
            onPressed: () => openTechniqueCheck(context, e),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab-exercises',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomExerciseScreen())),
          icon: const Icon(Icons.add),
          label: const Text('Własne ćwiczenie'),
        ),
      );
}
