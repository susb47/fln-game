import 'package:flutter/material.dart';

import '../bn.dart';
import '../data/content.dart';
import '../game_scope.dart';
import '../logic/progression.dart';
import '../widgets/sound_widgets.dart';
import '../widgets/visuals.dart';
import 'play_screen.dart';

/// Stars, new achievements and what to play next.
class ResultScreen extends StatefulWidget {
  final LevelDef level;
  final LevelResult result;

  const ResultScreen({super.key, required this.level, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameScope.of(context).coach.levelEnd(widget.result);
    });
  }

  @override
  Widget build(BuildContext context) => _ResultView(level: widget.level, result: widget.result);
}

class _ResultView extends StatelessWidget {
  final LevelDef level;
  final LevelResult result;

  const _ResultView({required this.level, required this.result});

  void _play(BuildContext context, LevelDef l) => Navigator.of(
    context,
  ).pushReplacement(MaterialPageRoute(builder: (_) => PlayScreen(level: l)));

  @override
  Widget build(BuildContext context) {
    final island = GameScope.of(context).content.island(level.island);
    final r = result;
    return Scaffold(
      backgroundColor: island.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CaptionBubble(),
                const SizedBox(height: 16),
                StarsRow(r.stars, size: 72, emptyColor: Colors.black26),
                const SizedBox(height: 12),
                Text(
                  r.passed ? 'ধাপ শেষ! 🎉' : 'প্রায় হয়ে গেছে!',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'প্রথম চেষ্টায় ঠিক: ${bn(r.correct)} / ${bn(r.total)}',
                  style: const TextStyle(fontSize: 22),
                ),
                if (!r.passed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'পরের ধাপ খুলতে ${bn((level.pass * r.total).ceil())}টি ঠিক লাগবে। আবার চেষ্টা করো!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.brown.shade700),
                    ),
                  ),
                for (final a in r.newAchievements)
                  Card(
                    color: const Color(0xFFFFF4D6),
                    margin: const EdgeInsets.only(top: 16),
                    child: ListTile(
                      leading: Text(a.emoji, style: const TextStyle(fontSize: 36)),
                      title: Text(
                        'নতুন পুরস্কার: ${a.title}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(a.description),
                    ),
                  ),
                const SizedBox(height: 28),
                if (r.passed && r.nextLevel != null)
                  _BigButton(
                    key: const ValueKey('next_level'),
                    color: island.color,
                    icon: Icons.arrow_forward_rounded,
                    label: 'পরের ধাপ',
                    onPressed: () => _play(context, r.nextLevel!),
                  ),
                if (r.suggestEasier != null)
                  _BigButton(
                    color: island.color,
                    icon: Icons.replay_rounded,
                    label: 'আগের ধাপটা আরেকবার',
                    onPressed: () => _play(context, r.suggestEasier!),
                  ),
                _BigButton(
                  key: const ValueKey('replay'),
                  color: r.passed ? Colors.blueGrey : island.color,
                  icon: Icons.refresh_rounded,
                  label: 'আবার খেলো',
                  onPressed: () => _play(context, level),
                ),
                _BigButton(
                  key: const ValueKey('back_to_island'),
                  color: Colors.blueGrey,
                  icon: Icons.map_rounded,
                  label: 'দ্বীপে ফিরে যাও',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _BigButton({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SizedBox(
      width: 300,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontSize: 22)),
      ),
    ),
  );
}
