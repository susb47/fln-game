import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fln_game/logic/progress.dart';
import 'package:fln_game/logic/question.dart';
import 'package:fln_game/logic/question_generator.dart';
import 'package:fln_game/logic/skills.dart';
import 'package:fln_game/screens/placement_screen.dart';

void main() {
  group('QuestionGenerator', () {
    test('every question has distinct options and a valid answer', () {
      final gen = QuestionGenerator(Random(1));
      for (final skill in Skill.values) {
        for (var level = 1; level <= maxLevel; level++) {
          for (var i = 0; i < 300; i++) {
            final q = gen.make(skill, level);
            expect(q.options.length, greaterThanOrEqualTo(2), reason: '$skill L$level');
            expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1));
            final keys = q.options.map((o) => o.label ?? '${o.group!.count}').toSet();
            expect(keys.length, q.options.length, reason: '$skill L$level duplicate options');
            for (final o in q.options) {
              if (o.group != null) expect(o.group!.count, greaterThan(0));
            }
            for (final v in q.visuals) {
              if (v is ObjectGroup) expect(v.count, inInclusiveRange(1, 20));
            }
          }
        }
      }
    });
  });

  group('Progress rules', () {
    test('8 of 10 correct moves up a level', () {
      final p = Progress.fresh();
      for (var i = 0; i < 9; i++) {
        expect(p.record(Skill.counting, i != 3 && i != 6), LevelChange.none);
      }
      expect(p.record(Skill.counting, true), LevelChange.up);
      expect(p.skills[Skill.counting]!.level, 2);
    });

    test('3 wrong in a row drops a level, never below 1', () {
      final p = Progress.fresh()..finishPlacement({Skill.compare: 2});
      p.record(Skill.compare, false);
      p.record(Skill.compare, false);
      expect(p.record(Skill.compare, false), LevelChange.down);
      expect(p.skills[Skill.compare]!.level, 1);
      for (var i = 0; i < 3; i++) {
        p.record(Skill.compare, false);
      }
      expect(p.skills[Skill.compare]!.level, 1);
    });

    test('islands unlock when the prerequisite reaches level 2', () {
      final p = Progress.fresh();
      expect(p.isUnlocked(Skill.counting), isTrue);
      expect(p.isUnlocked(Skill.pattern), isTrue);
      expect(p.isUnlocked(Skill.compare), isFalse);
      p.finishPlacement({Skill.counting: 2});
      expect(p.isUnlocked(Skill.compare), isTrue);
      expect(p.isUnlocked(Skill.addition), isFalse);
    });
  });

  test('placement start levels stop at the first miss', () {
    final levels = startLevels([
      ((Skill.counting, 1), true),
      ((Skill.counting, 2), true),
      ((Skill.counting, 3), false),
      ((Skill.compare, 1), false),
      ((Skill.compare, 2), true),
    ]);
    expect(levels[Skill.counting], 2);
    expect(levels[Skill.compare], 1);
    expect(levels[Skill.addition], 1);
  });
}
