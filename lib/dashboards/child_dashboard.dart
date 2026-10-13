import 'package:flutter/material.dart';

import '../bn.dart';
import '../game_scope.dart';
import '../logic/profile.dart';
import 'dashboard_widgets.dart';

const _weekdays = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি', 'রবি'];

/// One child's progress. The child sees it from the map (📊);
/// a teacher sees it with [forTeacher], which adds the per-level table.
class ChildDashboard extends StatelessWidget {
  final Profile profile;
  final bool forTeacher;
  final VoidCallback? onDelete;

  const ChildDashboard({super.key, required this.profile, this.forTeacher = false, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final content = scope.content;
    final prog = scope.progressionFor(profile);
    final p = profile;
    final now = DateTime.now();
    final week = [for (var i = 6; i >= 0; i--) now.subtract(Duration(days: i))];
    final stuck = prog.stuckLevels();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F4F8),
        title: Text(forTeacher ? '${p.avatar} ${p.name}' : '📊 আমার অগ্রগতি'),
        actions: [
          if (onDelete != null)
            IconButton(
              tooltip: 'খেলোয়াড় মুছুন',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StatTile(emoji: '⭐', value: bn(p.totalStars), label: 'তারা'),
                StatTile(
                  emoji: '✅',
                  value: '${bn(p.levelsCompleted)}/${bn(content.allLevels.length)}',
                  label: 'ধাপ শেষ',
                ),
                StatTile(emoji: '🏆', value: bn(p.achievements.length), label: 'পুরস্কার'),
                StatTile(emoji: '🔥', value: bn(p.streak(now)), label: 'টানা দিন'),
                StatTile(
                  emoji: '⏱️',
                  value: bn((p.totalSeconds / 60).round()),
                  label: 'মিনিট খেলা',
                ),
                StatTile(
                  emoji: '🎯',
                  value: p.totalAnswers == 0 ? '–' : bnPercent(p.totalCorrect / p.totalAnswers),
                  label: 'প্রথম চেষ্টায় ঠিক',
                ),
              ],
            ),
            Panel(
              title: 'দ্বীপে অগ্রগতি',
              child: Column(
                children: [
                  for (final island in content.islands)
                    BarRow(
                      label: '${island.emoji} ${island.title}',
                      color: island.color,
                      value: content.levelsOf(island.id).isEmpty
                          ? 0
                          : prog.completedIn(island.id) / content.levelsOf(island.id).length,
                      trailing:
                          '${bn(prog.completedIn(island.id))}/${bn(content.levelsOf(island.id).length)} ধাপ',
                    ),
                ],
              ),
            ),
            if (forTeacher)
              Panel(
                title: 'দক্ষতা অনুযায়ী সঠিকতা (প্রথম চেষ্টা)',
                child: Column(
                  children: [
                    for (final island in content.islands)
                      BarRow(
                        label: '${island.emoji} ${island.title}',
                        color: island.color,
                        value: p.islands[island.id]?.accuracy ?? 0,
                        trailing: (p.islands[island.id]?.answers ?? 0) == 0
                            ? 'খেলেনি'
                            : '${bnPercent(p.islands[island.id]!.accuracy)} '
                                  '(${bn(p.islands[island.id]!.answers)})',
                      ),
                  ],
                ),
              ),
            Panel(
              title: 'গত ৭ দিন (মিনিট)',
              child: DayBars(
                color: const Color(0xFF457B9D),
                unit: 'মিনিট',
                days: [
                  for (final d in week)
                    (_weekdays[d.weekday - 1], ((p.days[dayKey(d)]?.seconds ?? 0) / 60).round()),
                ],
              ),
            ),
            if (forTeacher && stuck.isNotEmpty)
              Panel(
                title: '⚠️ এখানে আটকে আছে',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final l in stuck)
                      Text(
                        '• ${content.island(l.island).title}: ${l.title} '
                        '(${bn(p.levels[l.id]!.fails)} বার চেষ্টা)',
                        style: const TextStyle(fontSize: 15, color: inkPrimary),
                      ),
                  ],
                ),
              ),
            Panel(
              title: 'সাম্প্রতিক খেলা',
              child: p.sessions.isEmpty
                  ? const Text('এখনো কোনো খেলা নেই', style: TextStyle(color: inkSecondary))
                  : Column(
                      children: [
                        for (final s in p.sessions.reversed.take(forTeacher ? 15 : 5))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Text(
                              content.level(s.levelId) != null
                                  ? content.island(content.level(s.levelId)!.island).emoji
                                  : '•',
                              style: const TextStyle(fontSize: 22),
                            ),
                            title: Text(content.level(s.levelId)?.title ?? s.levelId),
                            subtitle: Text('${bnDate(s.at)} · ${bnMinutes(s.seconds)}'),
                            trailing: Text(
                              '${'⭐' * s.stars}  ${bn(s.correct)}/${bn(s.total)}',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                      ],
                    ),
            ),
            if (forTeacher)
              Panel(
                title: 'প্রতিটি ধাপ',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 18,
                    columns: const [
                      DataColumn(label: Text('ধাপ')),
                      DataColumn(label: Text('চেষ্টা'), numeric: true),
                      DataColumn(label: Text('সেরা'), numeric: true),
                      DataColumn(label: Text('তারা')),
                    ],
                    rows: [
                      for (final l in content.allLevels)
                        DataRow(
                          cells: [
                            DataCell(Text('${content.island(l.island).emoji} ${l.title}')),
                            DataCell(Text(bn(p.levels[l.id]?.attempts ?? 0))),
                            DataCell(
                              Text(
                                p.levels[l.id] == null ? '–' : bnPercent(p.levels[l.id]!.bestScore),
                              ),
                            ),
                            DataCell(
                              Text(
                                prog.isLevelUnlocked(l)
                                    ? '⭐' * (p.levels[l.id]?.bestStars ?? 0)
                                    : '🔒',
                              ),
                            ),
                          ],
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
