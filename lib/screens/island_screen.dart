import 'package:flutter/material.dart';

import '../bn.dart';
import '../game_scope.dart';
import '../widgets/visuals.dart';
import 'play_screen.dart';

/// The path of levels on one island. Finishing a level opens the next one.
class IslandScreen extends StatelessWidget {
  final String islandId;

  const IslandScreen({super.key, required this.islandId});

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final island = scope.content.island(islandId);
    final levels = scope.content.levelsOf(islandId);
    return ListenableBuilder(
      listenable: scope.store,
      builder: (context, _) {
        final prog = scope.progression;
        final next = prog.nextLevelIn(islandId);
        return Scaffold(
          backgroundColor: island.background,
          appBar: AppBar(
            backgroundColor: island.color,
            foregroundColor: Colors.white,
            title: Text('${island.emoji}  ${island.title}'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '⭐ ${bn(prog.starsIn(islandId))} / ${bn(levels.length * 3)}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              itemCount: levels.length,
              itemBuilder: (context, i) {
                final level = levels[i];
                final unlocked = prog.isLevelUnlocked(level);
                final rec = scope.player.levels[level.id];
                // Zig-zag path, like a board game.
                final align = [
                  Alignment.centerLeft,
                  Alignment.center,
                  Alignment.centerRight,
                  Alignment.center,
                ][i % 4];
                return Align(
                  alignment: align,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: _LevelNode(
                      key: ValueKey('level_${level.id}'),
                      number: i + 1,
                      title: level.title,
                      color: island.color,
                      unlocked: unlocked,
                      isNext: level == next,
                      stars: rec?.bestStars ?? 0,
                      onTap: unlocked
                          ? () => Navigator.of(
                              context,
                            ).push(MaterialPageRoute(builder: (_) => PlayScreen(level: level)))
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _LevelNode extends StatelessWidget {
  final int number;
  final String title;
  final Color color;
  final bool unlocked;
  final bool isNext;
  final int stars;
  final VoidCallback? onTap;

  const _LevelNode({
    super.key,
    required this.number,
    required this.title,
    required this.color,
    required this.unlocked,
    required this.isNext,
    required this.stars,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: isNext ? 1.12 : 1,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked ? color : Colors.blueGrey.shade200,
                border: Border.all(color: isNext ? Colors.amber : Colors.white, width: 5),
                boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
              ),
              child: unlocked
                  ? Text(
                      bn(number),
                      style: const TextStyle(
                        fontSize: 36,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Icon(Icons.lock_rounded, size: 36, color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          StarsRow(stars, size: 22, emptyColor: Colors.black26),
          SizedBox(
            width: 150,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: unlocked ? Colors.black87 : Colors.black38),
            ),
          ),
        ],
      ),
    );
  }
}
