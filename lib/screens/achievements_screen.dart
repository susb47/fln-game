import 'package:flutter/material.dart';

import '../bn.dart';
import '../game_scope.dart';

/// Every achievement from assets/config/achievements.json, earned or not.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final prog = scope.progression;
    final earned = scope.player.achievements;
    final all = scope.content.achievements;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4D6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF4D6),
        title: Text('🏆 পুরস্কার (${bn(earned.length)}/${bn(all.length)})'),
      ),
      body: SafeArea(
        child: GridView.extent(
          maxCrossAxisExtent: 200,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: [
            for (final a in all)
              Card(
                color: earned.containsKey(a.id) ? Colors.white : Colors.grey.shade200,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Opacity(
                        opacity: earned.containsKey(a.id) ? 1 : 0.3,
                        child: Text(a.emoji, style: const TextStyle(fontSize: 44)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        a.description,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const Spacer(),
                      if (!earned.containsKey(a.id))
                        LinearProgressIndicator(
                          value: prog.progressToward(a),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
