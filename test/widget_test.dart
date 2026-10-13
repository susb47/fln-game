import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fln_game/logic/progress.dart';
import 'package:fln_game/logic/skills.dart';
import 'package:fln_game/main.dart';
import 'package:fln_game/screens/placement_screen.dart';

void main() {
  testWidgets('placement then a full session on the counting island', (tester) async {
    final progress = Progress.fresh();
    await tester.pumpWidget(FlnApp(progress: progress));
    expect(find.text('চলো শুরু করি!'), findsOneWidget);

    for (var i = 0; i < placementItems.length; i++) {
      await tester.tap(find.byKey(const ValueKey('answer_0')));
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.pumpAndSettle();
    expect(progress.placementDone, isTrue);
    expect(find.text('সংখ্যার দ্বীপ'), findsOneWidget);

    await tester.tap(find.text(Skill.counting.title));
    await tester.pumpAndSettle();

    // Tap every option until the right one: each question must be solvable.
    for (var q = 0; q < 10; q++) {
      for (var i = 0; i < 3; i++) {
        final f = find.byKey(ValueKey('answer_$i'));
        if (f.evaluate().isEmpty) break;
        await tester.tap(f);
        await tester.pump();
        if (find.textContaining('!').evaluate().isNotEmpty) break;
      }
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
    }
    expect(find.text('খেলা শেষ!'), findsOneWidget);
  });
}
