import 'dart:math';

import '../bn.dart';
import '../data/cast.dart';
import '../logic/progression.dart';
import '../logic/question.dart';
import 'audio_manager.dart';

/// Decides which character says what when something happens in the game.
///
/// Screens call these methods; they never pick lines or voices themselves.
/// Who speaks for each event, and the lines, come from assets/config/dialogue.json.
class Coach {
  final Cast cast;
  final AudioManager audio;
  final Random _rng;

  Coach(this.cast, this.audio, [Random? rng]) : _rng = rng ?? Random();

  /// A line for [event], with {placeholders} filled in. Null when the event has no lines.
  Line? line(String event, [Map<String, String> fill = const {}]) {
    final e = cast.events[event];
    if (e == null || e.lines.isEmpty) return null;
    var text = e.lines[_rng.nextInt(e.lines.length)];
    for (final MapEntry(:key, :value) in fill.entries) {
      text = text.replaceAll('{$key}', value);
    }
    return Line(cast.speaker(event), text.trim());
  }

  Line questionLine(Question q) => Line(cast.speaker('question'), q.spoken);

  void _say(List<Line?> lines) => audio.say([for (final l in lines) ?l]);

  void welcome(String name) => _say([
    line('welcome', {'name': name}),
  ]);

  void placementStart(Question first) => _say([line('placement_start'), questionLine(first)]);

  void levelStart(Question first) => _say([line('level_start'), questionLine(first)]);

  void question(Question q) => _say([questionLine(q)]);

  void correct() {
    audio.sfx(Sfx.correct);
    _say([line('correct')]);
  }

  /// [wrongTries] counts wrong taps on this question so far (1 = first mistake).
  void wrong(Question q, int wrongTries) {
    audio.sfx(Sfx.wrong);
    _say([
      line(wrongTries >= 2 ? 'wrong_again' : 'wrong_first', {'hint': q.hint}),
    ]);
  }

  void levelEnd(LevelResult r) {
    audio.sfx(r.stars > 0 ? Sfx.levelUp : Sfx.tryAgain);
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
