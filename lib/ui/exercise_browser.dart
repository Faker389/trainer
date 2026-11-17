import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../technique/patterns.dart';
import 'widgets.dart';

/// Searchable exercise list grouped by category; shared by the library tab and pickers.
class ExerciseBrowser extends StatefulWidget {
  final void Function(Exercise) onTap;
  final void Function(Exercise)? onLongPress;
  final Widget Function(Exercise)? trailing;

  /// Enables checkbox mode.
  final Set<String>? selected;
  const ExerciseBrowser({super.key, required this.onTap, this.onLongPress, this.trailing, this.selected});

  @override
  State<ExerciseBrowser> createState() => _ExerciseBrowserState();
}

class _ExerciseBrowserState extends State<ExerciseBrowser> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  MuscleCategory? _category;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(Exercise e, String q) =>
      q.isEmpty ||
      e.name.toLowerCase().contains(q) ||
      e.equipment.toLowerCase().contains(q) ||
      e.muscles.any((m) => m.contains(q));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = _query.trim().toLowerCase();
    final rows = <Object>[];
    for (final c in MuscleCategory.values) {
      if (_category != null && c != _category) continue;
      final list = store.exercises.where((e) => e.category == c && _matches(e, q)).toList();
      if (list.isEmpty) continue;
      rows
        ..add(c)
        ..addAll(list);
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search, color: context.shade(0.38)),
            hintText: 'Szukaj ćwiczenia, sprzętu lub mięśnia',
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            isDense: true,
          ),
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: const Text('Wszystkie'),
                selected: _category == null,
                onSelected: (_) => setState(() => _category = null),
              ),
            ),
            for (final c in MuscleCategory.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(c.label),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = _category == c ? null : c),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: rows.isEmpty
            ? const EmptyHint('Brak ćwiczeń pasujących do wyszukiwania.', icon: Icons.search_off)
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final row = rows[i];
                  if (row is MuscleCategory) return SectionHeader(row.label, color: row.color);
                  final e = row as Exercise;
                  final selected = widget.selected;
                  return FadeSlide(
                    index: i,
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: selected != null
                          ? Checkbox(value: selected.contains(e.id), onChanged: (_) => widget.onTap(e))
                          : Container(
                              width: 4,
                              height: 32,
                              decoration: BoxDecoration(
                                color: e.category.color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                      minLeadingWidth: 4,
                      title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        [
                          if (e.equipment.isNotEmpty) e.equipment,
                          if (hasFullAnalysis(e)) 'analiza techniki',
                          if (e.custom) 'własne',
                        ].join(' · '),
                        style: TextStyle(color: context.shade(0.38), fontSize: 12),
                      ),
                      trailing: widget.trailing?.call(e),
                      onTap: () => widget.onTap(e),
                      onLongPress: widget.onLongPress == null ? null : () => widget.onLongPress!(e),
                    ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

/// Returns an [Exercise] (single mode) or the selected ids as `List<String>` (multi mode).
class ExercisePickerScreen extends StatefulWidget {
  final bool multi;
  final List<String> initial;
  const ExercisePickerScreen({super.key, this.multi = false, this.initial = const []});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.multi ? 'Wybierz ćwiczenia (${_selected.length})' : 'Wybierz ćwiczenie'),
          actions: [
            if (widget.multi)
              TextButton(
                onPressed: () => Navigator.pop(context, _selected.toList()),
                child: const Text('Gotowe'),
              ),
          ],
        ),
        body: ExerciseBrowser(
          selected: widget.multi ? _selected : null,
          onTap: (e) {
            if (!widget.multi) {
              Navigator.pop(context, e);
              return;
            }
            setState(() {
              if (!_selected.remove(e.id)) _selected.add(e.id);
            });
          },
        ),
      );
}

class CustomExerciseScreen extends StatefulWidget {
  const CustomExerciseScreen({super.key});

  @override
  State<CustomExerciseScreen> createState() => _CustomExerciseScreenState();
}

class _CustomExerciseScreenState extends State<CustomExerciseScreen> {
  final _name = TextEditingController();
  final _equipment = TextEditingController();
  MuscleCategory _category = MuscleCategory.chest;
  ExerciseKind _kind = ExerciseKind.weightReps;
  TechniquePattern _pattern = TechniquePattern.tracking;

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Podaj nazwę ćwiczenia')));
      return;
    }
    final e = StoreScope.read(context).addCustomExercise(
      name: name,
      category: _category,
      kind: _kind,
      pattern: _pattern,
      equipment: _equipment.text.trim(),
    );
    Navigator.pop(context, e);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nowe ćwiczenie'), actions: [
          TextButton(onPressed: _save, child: const Text('Zapisz')),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nazwa'), autofocus: true),
          const SizedBox(height: 12),
          TextField(controller: _equipment, decoration: const InputDecoration(labelText: 'Sprzęt (opcjonalnie)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<MuscleCategory>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Kategoria'),
            items: [for (final c in MuscleCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ExerciseKind>(
            value: _kind,
            decoration: const InputDecoration(labelText: 'Co zapisujesz'),
            items: [for (final k in ExerciseKind.values) DropdownMenuItem(value: k, child: Text(k.label))],
            onChanged: (v) => setState(() => _kind = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TechniquePattern>(
            value: _pattern,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Wzorzec ruchu (analiza kamerą)',
              helperText: 'Decyduje, który kąt stawu liczy powtórzenia przy sprawdzaniu techniki',
            ),
            items: [for (final p in TechniquePattern.values) DropdownMenuItem(value: p, child: Text(p.label))],
            onChanged: (v) => setState(() => _pattern = v!),
          ),
        ]),
      );
}
