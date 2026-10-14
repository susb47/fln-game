import 'package:flutter_test/flutter_test.dart';
import 'package:fln_game/logic/profile.dart';
import 'package:fln_game/logic/progression.dart';

import 'helpers.dart';

void main() {
  final content = loadContent();
  Profile kid() => Profile(id: '1', name: 'রিয়া', avatar: '🐯', createdAt: DateTime(2026));

  test('stars follow the pass mark', () {
    expect(starsFor(0.5, 0.75), 0);
    expect(starsFor(0.75, 0.75), 1);
    expect(starsFor(0.875, 0.75), 2);
    expect(starsFor(1, 0.75), 3);
  });

  test('passing a level opens the next one and earns achievements', () {
    final prog = Progression(content, kid());
    final levels = content.levelsOf('counting');
    expect(prog.isLevelUnlocked(levels[0]), isTrue);
    expect(prog.isLevelUnlocked(levels[1]), isFalse);
    final r = prog.finishLevel(levels[0], levels[0].questions, 60, DateTime(2026, 10, 12));
    expect(r.stars, 3);
    expect(r.nextLevel, levels[1]);
    expect(r.newAchievements.map((a) => a.id), containsAll(['first_level', 'perfect_1']));
    // Earned once only.
    expect(prog.finishLevel(levels[0], levels[0].questions, 60).newAchievements, isEmpty);
  });

  test('islands unlock after their prerequisite levels', () {
    final prog = Progression(content, kid());
    final compare = content.island('compare');
    expect(prog.isIslandUnlocked(compare), isFalse);
    for (final l in content.levelsOf('counting').take(compare.unlockLevels)) {
      prog.finishLevel(l, l.questions, 30);
    }
    expect(prog.isIslandUnlocked(compare), isTrue);
  });

  test('failing twice suggests the easier level and shows as stuck', () {
    final prog = Progression(content, kid());
    final levels = content.levelsOf('counting');
    prog.finishLevel(levels[0], levels[0].questions, 30);
    expect(prog.finishLevel(levels[1], 1, 30).suggestEasier, isNull);
    expect(prog.finishLevel(levels[1], 1, 30).suggestEasier, levels[0]);
    expect(prog.stuckLevels(), [levels[1]]);
  });

  test('placement opens levels up to the last correct probe', () {
    final p = kid();
    final prog = Progression(content, p);
    final probes = prog.placementProbes();
    final counting = probes.where((l) => l.island == 'counting').toList();
    prog.finishPlacement({for (final l in probes) l: l == counting.first});
    expect(p.placementDone, isTrue);
    final opened = content.levelsOf('counting').where(prog.isLevelUnlocked).length;
    expect(opened, counting.first.order); // every level up to the probe
    expect(prog.nextLevelIn('counting'), counting.first); // starts at the probe level
  });

  test('streaks count days in a row', () {
    final p = kid();
    for (final d in ['2026-10-10', '2026-10-11', '2026-10-12', '2026-10-05']) {
      p.days[d] = Tally(answers: 1);
    }
    expect(p.streak(DateTime(2026, 10, 12)), 3);
    expect(p.bestStreak, 3);
  });

  test('profiles survive saving and loading', () {
    final p = kid()..trainer = 'mim';
    final prog = Progression(content, p);
    final l = content.levelsOf('pattern').first;
    prog.recordAnswer('pattern', true);
    prog.finishLevel(l, l.questions, 45);
    final back = Profile.fromJson(p.toJson());
    expect(back.levels[l.id]!.bestStars, 3);
    expect(back.totalCorrect, 1);
    expect(back.sessions.single.seconds, 45);
    expect(back.achievements.keys, p.achievements.keys);
    expect(back.trainer, 'mim');
    expect(Profile.fromJson((p..trainer = null).toJson()).trainer, isNull);
  });
}
