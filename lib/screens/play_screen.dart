import 'dart:math';

import 'package:flutter/material.dart';

import '../bn.dart';
import '../data/content.dart';
import '../game_scope.dart';
import '../logic/puzzle_factory.dart';
import '../logic/question.dart';
import '../audio/audio_manager.dart';
import '../widgets/anim.dart';
import '../widgets/celebration.dart';
import '../widgets/sound_widgets.dart';
import '../widgets/visuals.dart';
import 'result_screen.dart';

/// One play of one level.
class PlayScreen extends StatefulWidget {
  final LevelDef level;
  final PuzzleFactory? factory;

  const PlayScreen({super.key, required this.level, this.factory});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final PuzzleFactory _factory = widget.factory ?? PuzzleFactory();
  final _rng = Random();
  final _clock = Stopwatch()..start();
  late Question _q = _factory.forLevel(widget.level);
  int _index = 0;
  int _firstTryCorrect = 0;
  final Set<int> _wrongPicks = {};
  bool _solved = false;
  Line? _cheer;

  int get _total => widget.level.questions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GameScope.of(context).audio.sfx(Sfx.whoosh);
      GameScope.of(context).coach.levelStart(_q);
    });
  }

  void _onTap(int i) {
    if (_solved || _wrongPicks.contains(i)) return;
    final firstTry = _wrongPicks.isEmpty;
    final correct = i == _q.correctIndex;
    if (firstTry) GameScope.of(context).progression.recordAnswer(widget.level.island, correct);
    final coach = GameScope.of(context).coach;
    if (correct) {
      if (firstTry) _firstTryCorrect++;
      final scope = GameScope.of(context);
      final line =
          coach.correct(afterRetry: !firstTry) ??
          Line(scope.cast.speaker('correct'), praise[_rng.nextInt(praise.length)]);
      setState(() {
        _solved = true;
        _cheer = line;
      });
      Future.delayed(const Duration(milliseconds: 1400), _next);
    } else {
      setState(() => _wrongPicks.add(i));
      coach.wrong(_q, _wrongPicks.length);
    }
  }

  void _next() {
    if (!mounted) return;
    if (_index + 1 >= _total) return _finish();
    setState(() {
      _index++;
      _wrongPicks.clear();
      _solved = false;
      _cheer = null;
      _q = _factory.forLevel(widget.level);
    });
    GameScope.of(context).audio.sfx(Sfx.whoosh);
    GameScope.of(context).coach.question(_q);
  }

  void _finish() {
    final scope = GameScope.of(context);
    final result = scope.progression.finishLevel(
      widget.level,
      _firstTryCorrect,
      _clock.elapsed.inSeconds,
    );
    scope.store.save();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(level: widget.level, result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final island = GameScope.of(context).content.island(widget.level.island);
    final showHint = _wrongPicks.isNotEmpty && !_solved;
    final audio = GameScope.of(context).audio;
    return PopScope(
      // Leaving mid-level stops any speech.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) audio.stop();
      },
      child: Scaffold(
        backgroundColor: island.background,
        appBar: AppBar(
          backgroundColor: island.color,
          foregroundColor: Colors.white,
          title: Text('${island.emoji}  ${widget.level.title}'),
          actions: const [SoundButton()],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(8),
            child: LinearProgressIndicator(
              value: _index / _total,
              backgroundColor: Colors.white24,
              color: Colors.amber,
              minHeight: 8,
            ),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight - 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const CaptionBubble(),
                        const SizedBox(height: 12),
                        // Each question plays its entrance: the prompt drops in,
                        // the objects pop in, then the answers rise up.
                        PopIn(
                          key: ValueKey('prompt_$_index'),
                          from: const Offset(0, -0.5),
                          curve: Curves.easeOutBack,
                          duration: const Duration(milliseconds: 450),
                          child: Text(
                            _q.prompt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        VisualsView(
                          _q.visuals,
                          key: ValueKey('visuals_$_index'),
                          numbered: showHint && _q.hintNumbersObjects,
                          onPop: () => audio.sfx(Sfx.pop),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 64,
                          child: Center(
                            child: showHint
                                ? Text(
                                    '$tryAgain। ${_q.hint}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 20, color: Colors.brown.shade700),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (var i = 0; i < _q.options.length; i++)
                              PopIn(
                                key: ValueKey('answer_in_${_index}_$i'),
                                delay:
                                    VisualsView.entranceTime(_q.visuals) +
                                    Duration(milliseconds: 110 * i),
                                from: const Offset(0, 0.6),
                                child: AnswerButton(
                                  key: ValueKey('answer_$i'),
                                  option: _q.options[i],
                                  state: _solved && i == _q.correctIndex
                                      ? AnswerState.correct
                                      : _wrongPicks.contains(i)
                                      ? AnswerState.wrong
                                      : AnswerState.idle,
                                  onTap: () => _onTap(i),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_cheer != null)
                Positioned.fill(
                  child: Celebration(
                    key: ValueKey('cheer_$_index'),
                    line: _cheer!,
                    afterRetry: _wrongPicks.isNotEmpty,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
