import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';

import '../bn.dart';
import '../dashboards/child_dashboard.dart';
import '../game_scope.dart';
import '../widgets/sound_widgets.dart';
import 'achievements_screen.dart';
import 'auth_screen.dart';
import 'island_screen.dart';

/// The island map: one island per strand, from assets/config/islands.json.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  void initState() {
    super.initState();
    // Tuki greets the player once each time they sign in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scope = GameScope.of(context);
      scope.audio.sfx(Sfx.hello);
      scope.coach.welcome(scope.player.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final player = scope.player;
    final prog = scope.progression;
    return Scaffold(
      backgroundColor: const Color(0xFFBDE0FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D3557),
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'খেলোয়াড় বদলাও',
          onPressed: scope.store.signOut,
          icon: Text(player.avatar, style: const TextStyle(fontSize: 26)),
        ),
        title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          const SoundButton(),
          Center(
            child: Text(
              '⭐ ${bn(player.totalStars)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            key: const ValueKey('achievements'),
            tooltip: 'পুরস্কার',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AchievementsScreen())),
            icon: const Text('🏆', style: TextStyle(fontSize: 24)),
          ),
          IconButton(
            key: const ValueKey('my_progress'),
            tooltip: 'আমার অগ্রগতি',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => ChildDashboard(profile: player))),
            icon: const Text('📊', style: TextStyle(fontSize: 24)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const MissingVoiceBanner(),
            if (player.isGuest)
              Material(
                color: const Color(0xFFFFE8A3),
                child: ListTile(
                  leading: const Text('🙂', style: TextStyle(fontSize: 28)),
                  title: const Text('তুমি অতিথি। খেলা সেভ হচ্ছে না।'),
                  trailing: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateProfileScreen(fromGuest: true)),
                    ),
                    child: const Text('সেভ করো'),
                  ),
                ),
              ),
            Expanded(
              child: GridView.extent(
                maxCrossAxisExtent: 260,
                padding: const EdgeInsets.all(16),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  for (final island in scope.content.islands)
                    _IslandCard(
                      key: ValueKey('island_${island.id}'),
                      emoji: island.emoji,
                      title: island.title,
                      color: island.color,
                      unlocked: prog.isIslandUnlocked(island),
                      done: prog.completedIn(island.id),
                      total: scope.content.levelsOf(island.id).length,
                      onTap: () => prog.isIslandUnlocked(island)
                          ? Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => IslandScreen(islandId: island.id)),
                            )
                          : ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'আগে "${scope.content.island(island.unlockIsland!).title}" দ্বীপের '
                                  '${bn(island.unlockLevels)}টি ধাপ শেষ করো!',
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IslandCard extends StatelessWidget {
  final String emoji;
  final String title;
  final Color color;
  final bool unlocked;
  final int done;
  final int total;
  final VoidCallback onTap;

  const _IslandCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.color,
    required this.unlocked,
    required this.done,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: unlocked ? color : Colors.blueGrey.shade300,
      borderRadius: BorderRadius.circular(28),
      elevation: unlocked ? 4 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FittedBox(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(unlocked ? emoji : '🔒', style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      minHeight: 10,
                      color: Colors.amber,
                      backgroundColor: Colors.white38,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${bn(done)} / ${bn(total)} ধাপ',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
