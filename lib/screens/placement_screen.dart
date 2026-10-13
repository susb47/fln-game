import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import '../bn.dart';
import '../data/content.dart';
import '../game_scope.dart';
import '../logic/puzzle_factory.dart';
import '../logic/question.dart';
import '../widgets/sound_widgets.dart';
import '../widgets/visuals.dart';

/// A short, game-like check for a new player, so they start at their own
/// level, not their grade. Two questions per island, taken from the level files.
/// No hints and no "wrong": every answer moves on.
class PlacementScreen extends StatefulWidget {
  final PuzzleFactory? factory;

  const PlacementScreen({super.key, this.factory});

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  late final PuzzleFactory _factory = widget.factory ?? PuzzleFactory();
  late final List<LevelDef> _probes = GameScope.of(context).progression.placementProbes();
  final Map<LevelDef, bool> _results = {};
  Question? _q;
  int? _picked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_q == null && _probes.isNotEmpty) {
      _q = _factory.forLevel(_probes.first);
      final coach = GameScope.of(context).coach;
      final first = _q!;
      WidgetsBinding.instance.addPostFrameCallback((_) => coach.placementStart(first));
    }
  }

  void _finish() {
    final scope = GameScope.of(context);
    scope.progression.finishPlacement(_results);
    scope.store.save(); // Rebuilds the app into the island map.
  }

  void _onTap(int i) {
    if (_picked != null) return;
    GameScope.of(context).audio.sfx(Sfx.tap);
    setState(() => _picked = i);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _results[_probes[_results.length]] = i == _q!.correctIndex;
      if (_results.length == _probes.length) return _finish();
      setState(() {
        _picked = null;
        _q = _factory.forLevel(_probes[_results.length]);
      });
      GameScope.of(context).coach.question(_q!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    if (q == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return const Scaffold();
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4D6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF4D6),
        title: const Text('চলো শুরু করি!'),
        actions: [
          const SoundButton(),
          TextButton(onPressed: _finish, child: const Text('শুরু থেকে খেলো')),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: LinearProgressIndicator(value: _results.length / _probes.length, minHeight: 8),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${bn(_results.length + 1)} / ${bn(_probes.length)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              const CaptionBubble(),
              const SizedBox(height: 12),
              Text(
                q.prompt,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              VisualsView(q.visuals),
              const SizedBox(height: 32),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (var i = 0; i < q.options.length; i++)
                    AnswerButton(
                      key: ValueKey('answer_$i'),
                      option: q.options[i],
                      // Neutral highlight: placement never marks an answer wrong.
                      state: _picked == i ? AnswerState.correct : AnswerState.idle,
                      onTap: () => _onTap(i),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
