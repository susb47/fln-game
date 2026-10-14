import 'package:flutter/material.dart';

import '../bn.dart';
import '../game_scope.dart';
import '../widgets/avatar.dart';
import '../logic/profile.dart';
import 'child_dashboard.dart';
import 'dashboard_widgets.dart';

/// Every child on this device: who is playing, how they are doing, and who
/// is stuck on which skill. Opened from the sign-in screen behind the adult check.
class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    return ListenableBuilder(
      listenable: scope.store,
      builder: (context, _) {
        final content = scope.content;
        final kids = scope.store.profiles;
        final now = DateTime.now();
        final weekAgo = now.subtract(const Duration(days: 7));
        final activeThisWeek = kids
            .where((p) => p.lastPlayed != null && p.lastPlayed!.isAfter(weekAgo))
            .length;
        final answers = kids.fold(0, (s, p) => s + p.totalAnswers);
        final correct = kids.fold(0, (s, p) => s + p.totalCorrect);
        final stuck = [
          for (final p in kids)
            for (final l in scope.progressionFor(p).stuckLevels()) (p, l),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF1F4F8),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF1F4F8),
            title: const Text('শিক্ষক / অভিভাবক ড্যাশবোর্ড'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    StatTile(emoji: '👧', value: bn(kids.length), label: 'খেলোয়াড়'),
                    StatTile(emoji: '📅', value: bn(activeThisWeek), label: 'এই সপ্তাহে খেলেছে'),
                    StatTile(
                      emoji: '🎯',
                      value: answers == 0 ? '–' : bnPercent(correct / answers),
                      label: 'গড় সঠিকতা',
                    ),
                    StatTile(emoji: '⚠️', value: bn(stuck.length), label: 'আটকে থাকা ধাপ'),
                  ],
                ),
                if (content.errors.isNotEmpty)
                  Panel(
                    title: '🛠️ লেভেল ফাইলে সমস্যা (${bn(content.errors.length)})',
                    child: Text(
                      content.errors.join('\n'),
                      style: const TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ),
                Panel(
                  title: 'যাদের সাহায্য দরকার',
                  child: stuck.isEmpty
                      ? const Text('কেউ আটকে নেই 👍', style: TextStyle(color: inkSecondary))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (p, l) in stuck)
                              Text(
                                '• ${avatarText(p.avatar)}${p.name}: ${content.island(l.island).title}, '
                                '${l.title} (${bn(p.levels[l.id]!.fails)} বার চেষ্টা)',
                                style: const TextStyle(fontSize: 15, color: inkPrimary),
                              ),
                          ],
                        ),
                ),
                Panel(
                  title: 'সব খেলোয়াড়',
                  child: kids.isEmpty
                      ? const Text('এখনো কোনো খেলোয়াড় নেই', style: TextStyle(color: inkSecondary))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            showCheckboxColumn: false,
                            columnSpacing: 18,
                            columns: const [
                              DataColumn(label: Text('নাম')),
                              DataColumn(label: Text('শেষ খেলা')),
                              DataColumn(label: Text('ধাপ'), numeric: true),
                              DataColumn(label: Text('তারা'), numeric: true),
                              DataColumn(label: Text('সঠিকতা'), numeric: true),
                              DataColumn(label: Text('আটকে'), numeric: true),
                            ],
                            rows: [
                              for (final p in kids)
                                DataRow(
                                  onSelectChanged: (_) => _openChild(context, p),
                                  cells: [
                                    DataCell(Text('${avatarText(p.avatar)}${p.name}')),
                                    DataCell(
                                      Text(p.lastPlayed == null ? '–' : bnDate(p.lastPlayed!)),
                                    ),
                                    DataCell(Text(bn(p.levelsCompleted))),
                                    DataCell(Text(bn(p.totalStars))),
                                    DataCell(
                                      Text(
                                        p.totalAnswers == 0
                                            ? '–'
                                            : bnPercent(p.totalCorrect / p.totalAnswers),
                                      ),
                                    ),
                                    DataCell(
                                      Text(bn(scope.progressionFor(p).stuckLevels().length)),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'সব তথ্য শুধু এই ফোনে থাকে। অতিথিদের খেলা এখানে দেখা যায় না।',
                    style: TextStyle(color: inkSecondary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openChild(BuildContext context, Profile p) {
    final store = GameScope.of(context).store;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (c) => ChildDashboard(
          profile: p,
          forTeacher: true,
          onDelete: () async {
            final ok = await showDialog<bool>(
              context: c,
              builder: (d) => AlertDialog(
                title: Text('${p.name}-কে মুছে ফেলবেন?'),
                content: const Text('এই খেলোয়াড়ের সব অগ্রগতি মুছে যাবে।'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('না')),
                  FilledButton(
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('হ্যাঁ, মুছুন'),
                  ),
                ],
              ),
            );
            if (ok == true && c.mounted) {
              store.delete(p);
              Navigator.of(c).pop();
            }
          },
        ),
      ),
    );
  }
}
