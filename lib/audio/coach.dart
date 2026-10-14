import 'dart:math';

import 'package:flutter/foundation.dart';

import '../bn.dart';
import '../data/cast.dart';
import '../logic/progression.dart';
import '../logic/question.dart';
import 'audio_manager.dart';

/// A move the trainer makes on screen.
enum TrainerMove { wave, hop, jump, cheer, think, nod }

/// The latest move asked for. [count] goes up every time, so the same move can repeat.
class TrainerCue {
  final TrainerMove move;
  final int count;
  const TrainerCue(this.move, this.count);
}

/// Decides which character says what when something happens in the game.
///
/// Screens call these methods; they never pick lines or voices themselves.
/// Who speaks for each event, and the lines, come from assets/config/dialogue.json.
class Coach {
  final Cast cast;
  final AudioManager audio;
  final Random _rng;

  /// The current player's trainer id (null: the first trainer).
  final String? Function() trainerId;

  Coach(this.cast, this.audio, {Random? rng, String? Function()? trainerId})
    : _rng = rng ?? Random(),
      trainerId = trainerId ?? (() => null);

  /// What the trainer should do now. Trainer pictures on screen follow it.
  final cue = ValueNotifier<TrainerCue?>(null);
  int _cues = 0;

  /// Makes the trainer on screen do [move].
  void act(TrainerMove move) => cue.value = TrainerCue(move, ++_cues);

  /// The character who guides the current player.
  CharacterDef get trainer => cast.trainer(trainerId());

  /// A line for [event], with {placeholders} filled in. Null when the event has no lines.
  Line? line(String event, [Map<String, String> fill = const {}]) {
    final e = cast.events[event];
    if (e == null || e.lines.isEmpty) return null;
    var text = e.lines[_rng.nextInt(e.lines.length)];
    for (final MapEntry(:key, :value) in fill.entries) {
      text = text.replaceAll('{$key}', value);
    }
    return Line(cast.speaker(event, trainerId()), text.trim());
  }

  Line questionLine(Question q) => Line(cast.speaker('question', trainerId()), q.spoken);

  void _say(List<Line?> lines) => audio.say([for (final l in lines) ?l]);

  void welcome(String name) {
    act(TrainerMove.wave);
    _say([
      line('welcome', {'name': name}),
    ]);
  }

  void placementStart(Question first) {
    act(TrainerMove.wave);
    _say([line('placement_start'), questionLine(first)]);
  }

  void levelStart(Question first) {
    act(TrainerMove.wave);
    _say([line('level_start'), questionLine(first)]);
  }

  void question(Question q) {
    act(TrainerMove.hop);
    _say([questionLine(q)]);
  }

  /// Cheers a right answer and returns the line, so the screen can show the same words.
  /// [afterRetry]: the child got there after a mistake.
  Line? correct({bool afterRetry = false}) {
    audio.sfx(Sfx.correct);
    act(afterRetry ? TrainerMove.jump : TrainerMove.cheer);
    final l = (afterRetry ? line('correct_retry') : null) ?? line('correct');
    _say([l]);
    return l;
  }

  /// [wrongTries] counts wrong taps on this question so far (1 = first mistake).
  void wrong(Question q, int wrongTries) {
    audio.sfx(Sfx.wrong);
    act(wrongTries >= 2 ? TrainerMove.nod : TrainerMove.think);
    _say([
      line(wrongTries >= 2 ? 'wrong_again' : 'wrong_first', {'hint': q.hint}),
    ]);
  }

  void levelEnd(LevelResult r) {
    audio.sfx(r.stars > 0 ? Sfx.levelUp : Sfx.tryAgain);
    act(r.stars > 0 ? TrainerMove.cheer : TrainerMove.nod);
    _say([
      if (r.stars == 0)
        line('level_fail')
      else if (r.stars >= 3)
        line('level_perfect')
      else
        line('level_pass', {'stars': bn(r.stars)}),
      for (final a in r.newAchievements) line('achievement', {'title': a.title}),
    ]);
  }
}
