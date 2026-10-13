// Run `flutter test` after adding or editing a level file: this checks them all.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fln_game/data/content.dart';
import 'package:fln_game/logic/puzzle_factory.dart';
import 'package:fln_game/logic/question.dart';

import 'helpers.dart';

void main() {
  final content = loadContent();

  testWidgets('the app finds every level file in the assets folder', (t) async {
    final loaded = await t.runAsync(Content.load);
    expect(loaded!.errors, isEmpty);
    expect(loaded.allLevels.length, content.allLevels.length);
  });

  test('every level file and config file is valid', () {
    expect(content.errors, isEmpty, reason: content.errors.join('\n'));
    expect(content.allLevels, isNotEmpty);
  });

  test('every level makes solvable questions with distinct options', () {
    final factory = PuzzleFactory(Random(1));
    for (final level in content.allLevels) {
      for (final spec in level.puzzles) {
        for (var i = 0; i < 200; i++) {
          final q = factory.make(spec);
          final where = '${level.source} (${spec.type})';
          expect(q.options.length, greaterThanOrEqualTo(2), reason: where);
          expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1), reason: where);
          final keys = q.options.map((o) => o.label ?? '${o.group!.count}').toSet();
          expect(keys.length, q.options.length, reason: '$where duplicate options');
          for (final v in q.visuals) {
            if (v is ObjectGroup) expect(v.count, inInclusiveRange(1, 20), reason: where);
          }
        }
      }
    }
  });

  test('the level template is a valid level', () {
    final c = Content.parse(
      islandsJson: File('assets/config/islands.json').readAsStringSync(),
      achievementsJson: '{"achievements":[]}',
      levelFiles: {'_template.json': File('assets/levels/_template.json').readAsStringSync()},
    );
    expect(c.errors, isEmpty, reason: c.errors.join('\n'));
  });

  test('bad level files are reported, not loaded', () {
    final c = Content.parse(
      islandsJson: '{"islands":[{"id":"counting","title":"t","emoji":"x","color":"#000000"}]}',
      achievementsJson: '{"achievements":[]}',
      levelFiles: {
        'a.json':
            '{"id":"a","island":"counting","order":1,"title":"A",'
            '"puzzles":[{"type":"count","min":1,"max":5}]}',
        'b.json':
            '{"id":"b","island":"nowhere","order":2,"title":"B",'
            '"puzzles":[{"type":"count","min":1,"max":5}]}',
        'c.json':
            '{"id":"c","island":"counting","order":3,"title":"C",'
            '"puzzles":[{"type":"count","min":9,"max":5}]}',
        'd.json': 'not json',
        'e.json':
            '{"id":"a","island":"counting","order":4,"title":"dup",'
            '"puzzles":[{"type":"teleport"}]}',
      },
    );
    expect(c.allLevels.map((l) => l.id), ['a']);
    expect(c.errors.length, greaterThanOrEqualTo(4));
  });
}
