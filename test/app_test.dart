import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fln_game/dashboards/teacher_dashboard.dart';
import 'package:fln_game/game_scope.dart';
import 'package:fln_game/logic/profile_store.dart';
import 'package:fln_game/main.dart';

import 'helpers.dart';

/// Taps answers until the question is solved, then waits for the next one.
Future<void> answerAll(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    final f = find.byKey(ValueKey('answer_$i'));
    if (f.evaluate().isEmpty) break;
    await t.tap(f);
    await t.pump();
    if (find.byKey(const ValueKey('praise')).evaluate().isNotEmpty) break;
  }
  await t.pump(const Duration(milliseconds: 1500));
  await t.pumpAndSettle();
}

void main() {
  final content = loadContent();

  testWidgets('new player: profile, placement, a level, achievements, dashboard', (t) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.7;
    addTearDown(t.view.reset);
    final store = ProfileStore.memory();
    await t.pumpWidget(FlnApp(content: content, store: store));
    expect(find.text('কে খেলবে?'), findsOneWidget);

    // Create a profile.
    await t.tap(find.byKey(const ValueKey('new_player')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('name')), 'রিয়া');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('create')));
    await t.pumpAndSettle();
    expect(store.profiles.single.name, 'রিয়া');

    // Skip placement.
    await t.tap(find.text('শুরু থেকে খেলো'));
    await t.pumpAndSettle();
    expect(find.text('রিয়া'), findsOneWidget);

    // Play counting level 1 to the end.
    await t.tap(find.byKey(const ValueKey('island_counting')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('level_counting_01')));
    await t.pumpAndSettle();
    final level = content.levelsOf('counting').first;
    for (var q = 0; q < level.questions; q++) {
      await answerAll(t);
    }
    expect(find.byKey(const ValueKey('replay')), findsOneWidget);
    expect(store.profiles.single.levels[level.id]!.attempts, 1);
    expect(store.profiles.single.sessions, hasLength(1));

    // Back to the island, then the map, then achievements and progress screens.
    await t.tap(find.byKey(const ValueKey('back_to_island')));
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('achievements')));
    await t.pumpAndSettle();
    expect(find.textContaining('পুরস্কার ('), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('my_progress')));
    await t.pumpAndSettle();
    expect(find.text('📊 আমার অগ্রগতি'), findsOneWidget);
  });

  testWidgets('guest plays without saving, then saves', (t) async {
    final store = ProfileStore.memory();
    await t.pumpWidget(FlnApp(content: content, store: store));
    await t.tap(find.byKey(const ValueKey('guest')));
    await t.pumpAndSettle();
    expect(store.current!.isGuest, isTrue);

    // Placement check: answer every probe.
    while (find.text('চলো শুরু করি!').evaluate().isNotEmpty) {
      await t.tap(find.byKey(const ValueKey('answer_0')));
      await t.pump(const Duration(milliseconds: 600));
      await t.pumpAndSettle();
    }
    expect(store.profiles, isEmpty);
    expect(find.text('সেভ করো'), findsOneWidget);

    await t.tap(find.text('সেভ করো'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('name')), 'অতিথি থেকে');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('create')));
    await t.pumpAndSettle();
    expect(store.profiles.single.placementDone, isTrue);
    expect(store.current!.isGuest, isFalse);
  });

  testWidgets('teacher dashboard lists players', (t) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.7;
    addTearDown(t.view.reset);
    final store = ProfileStore.memory()..create('রাহিম', '🐘');
    await t.pumpWidget(
      GameScope(
        content: content,
        store: store,
        child: const MaterialApp(home: TeacherDashboard()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('রাহিম'), findsWidgets);
  });
}
