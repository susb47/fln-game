import 'package:flutter/material.dart';

import '../logic/progress.dart';
import '../logic/skills.dart';
import '../widgets/visuals.dart';
import 'play_screen.dart';

/// The island map: one island per skill strand.
class HomeScreen extends StatelessWidget {
  final Progress progress;

  const HomeScreen({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFBDE0FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D3557),
        foregroundColor: Colors.white,
        title: const Text('সংখ্যার দ্বীপ', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _confirmReset(context),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset', child: Text('অগ্রগতি মুছে ফেলুন (শিক্ষক/অভিভাবক)')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: GridView.extent(
          maxCrossAxisExtent: 260,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            for (final skill in Skill.values) _IslandCard(progress: progress, skill: skill),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('সব অগ্রগতি মুছে ফেলবেন?'),
        content: const Text('শিশুটি আবার শুরুর যাচাই থেকে খেলবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('না')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('হ্যাঁ, মুছুন')),
        ],
      ),
    );
    if (ok == true) progress.reset();
  }
}

class _IslandCard extends StatelessWidget {
  final Progress progress;
  final Skill skill;

  const _IslandCard({required this.progress, required this.skill});

  @override
  Widget build(BuildContext context) {
    final unlocked = progress.isUnlocked(skill);
    final p = progress.skills[skill]!;
    return Material(
      color: unlocked ? skill.color : Colors.blueGrey.shade300,
      borderRadius: BorderRadius.circular(28),
      elevation: unlocked ? 4 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: unlocked
            ? () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PlayScreen(progress: progress, skill: skill),
                ))
            : () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    'আগে "${skill.prerequisite!.title}" দ্বীপে একটি তারা জেতো!',
                    style: const TextStyle(fontSize: 18),
                  ),
                )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FittedBox(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(unlocked ? skill.emoji : '🔒', style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                Text(skill.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                StarsRow(p.stars),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
