import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:trainer_engine/trainer_engine.dart';

import '../data/models.dart';
import '../technique/patterns.dart';
import 'live_screen.dart';
import 'widgets.dart';

void openTechniqueCheck(BuildContext context, Exercise exercise) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TechniqueSetupScreen(exercise: exercise)));

/// Camera choice before a technique-check set.
class TechniqueSetupScreen extends StatefulWidget {
  final Exercise exercise;
  const TechniqueSetupScreen({super.key, required this.exercise});

  @override
  State<TechniqueSetupScreen> createState() => _TechniqueSetupScreenState();
}

class _TechniqueSetupScreenState extends State<TechniqueSetupScreen> {
  List<CameraDescription>? _cameras;
  String? _cameraError;
  CameraDescription? _camera;
  ResolutionPreset _resolution = ResolutionPreset.medium;
  bool _accurate = false;
  bool _voice = true;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    var cams = <CameraDescription>[];
    String? error;
    try {
      cams = await availableCameras();
    } on CameraException catch (e) {
      error = e.description ?? e.code;
    }
    if (!mounted) return;
    setState(() {
      _cameras = cams;
      _cameraError = error;
      _camera = cams.where((c) => c.lensDirection == CameraLensDirection.front).firstOrNull ?? cams.firstOrNull;
    });
  }

  String _camLabel(CameraDescription c) => switch (c.lensDirection) {
        CameraLensDirection.front => 'Przednia (widzisz ekran)',
        CameraLensDirection.back => 'Tylna (lepsza jakość)',
        CameraLensDirection.external => 'Zewnętrzna',
      };

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final def = techniqueDefinitionFor(ex);
    final full = hasFullAnalysis(ex);
    final cameras = _cameras;
    return Scaffold(
      appBar: AppBar(title: const Text('Sprawdź technikę')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(ex.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(full ? Icons.verified : Icons.accessibility_new,
                  color: full ? Theme.of(context).colorScheme.primary : Colors.amber),
              title: Text(full ? 'Pełna analiza techniki' : 'Śledzenie sylwetki i liczenie powtórzeń'),
              subtitle: Text(full
                  ? 'Liczenie powtórzeń, wykrywanie błędów, podpowiedzi głosowe i ocena serii.'
                  : countsReps(ex)
                      ? 'Szkielet na żywo, fazy ruchu i liczenie powtórzeń (${ex.pattern.label.toLowerCase()}). '
                          'Szczegółowe reguły techniki dla tego ćwiczenia pojawią się później.'
                      : 'Szkielet na żywo i kąty stawów. Liczenie powtórzeń nie dotyczy tego ćwiczenia.'),
            ),
          ),
          if (_cameraError != null)
            Card(
              color: Colors.red.shade900,
              child: Padding(padding: const EdgeInsets.all(12), child: Text('Kamera niedostępna: $_cameraError')),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Ustawienie kamery: ${def.cameraSetup}'),
            ),
          ),
          const SizedBox(height: 12),
          if (cameras == null)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else
            DropdownButtonFormField<CameraDescription>(
              value: _camera,
              decoration: const InputDecoration(labelText: 'Kamera'),
              items: [for (final c in cameras) DropdownMenuItem(value: c, child: Text(_camLabel(c)))],
              onChanged: (c) => setState(() => _camera = c),
            ),
          DropdownButtonFormField<ResolutionPreset>(
            value: _resolution,
            decoration: const InputDecoration(labelText: 'Rozdzielczość'),
            items: const [
              DropdownMenuItem(value: ResolutionPreset.low, child: Text('Niska (słabszy telefon)')),
              DropdownMenuItem(value: ResolutionPreset.medium, child: Text('Średnia (zalecana)')),
              DropdownMenuItem(value: ResolutionPreset.high, child: Text('Wysoka 720p')),
            ],
            onChanged: (r) => setState(() => _resolution = r!),
          ),
          SwitchListTile(
            title: const Text('Dokładny model pozy'),
            subtitle: const Text('Wolniejszy, lepszy przy zasłoniętych nogach'),
            value: _accurate,
            onChanged: (v) => setState(() => _accurate = v),
          ),
          SwitchListTile(
            title: const Text('Podpowiedzi głosowe po polsku'),
            value: _voice,
            onChanged: (v) => setState(() => _voice = v),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.videocam),
            label: const Padding(padding: EdgeInsets.all(12), child: Text('Start', style: TextStyle(fontSize: 20))),
            onPressed: _camera == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LiveScreen(
                        exercise: def,
                        camera: _camera!,
                        resolution: _resolution,
                        accurateModel: _accurate,
                        voice: _voice,
                        logExercise: ex,
                      ),
                    )),
          ),
          const SizedBox(height: 16),
          Text(Msg.disclaimer, style: TextStyle(color: context.shade(0.54), fontSize: 12)),
        ],
      ),
    );
  }
}
