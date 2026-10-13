import '../data/content.dart';
import 'profile.dart';

/// Star thresholds. A level's own "pass" decides 1 star; these decide 2 and 3.
class StarRules {
  static const twoStars = 0.85;
  static const threeStars = 1.0;
}

/// Stars for one play: 0 if not passed.
int starsFor(double score, double pass) {
  if (score < pass) return 0;
  if (score >= StarRules.threeStars) return 3;
  if (score >= StarRules.twoStars) return 2;
  return 1;
}

/// What happened when a level finished.
class LevelResult {
  final int correct;
  final int total;
  final int stars;
  final bool newBest;
  final LevelDef? nextLevel;

  /// The level before, suggested after failing this one twice.
  final LevelDef? suggestEasier;
  final List<AchievementDef> newAchievements;

  const LevelResult({
    required this.correct,
    required this.total,
    required this.stars,
    required this.newBest,
    required this.nextLevel,
    required this.suggestEasier,
    required this.newAchievements,
  });

  bool get passed => stars > 0;
}

/// Unlock rules, results and achievements for one child.
class Progression {
  final Content content;
  final Profile profile;

  Progression(this.content, this.profile);

  int completedIn(String islandId) =>
      content.levelsOf(islandId).where((l) => profile.levels[l.id]?.completed ?? false).length;

  int starsIn(String islandId) =>
      content.levelsOf(islandId).fold(0, (s, l) => s + (profile.levels[l.id]?.bestStars ?? 0));

  bool isIslandUnlocked(IslandDef island) {
    if (island.unlockIsland == null) return true;
    if (completedIn(island.unlockIsland!) >= island.unlockLevels) return true;
    // Placement or earlier play can open an island early.
    return content
        .levelsOf(island.id)
        .any(
          (l) => profile.openedLevels.contains(l.id) || (profile.levels[l.id]?.completed ?? false),
        );
  }

  bool isLevelUnlocked(LevelDef level) {
    final island = content.island(level.island);
    if (!isIslandUnlocked(island)) return false;
    final levels = content.levelsOf(level.island);
    final i = levels.indexOf(level);
    return i == 0 ||
        profile.openedLevels.contains(level.id) ||
        (profile.levels[level.id]?.completed ?? false) ||
        (profile.levels[levels[i - 1].id]?.completed ?? false);
  }

  /// The level to play next on an island: the first unlocked, unfinished one,
  /// skipping levels the placement check showed the child already knows.
  LevelDef? nextLevelIn(String islandId) {
    final levels = content.levelsOf(islandId);
    final placedAt = levels.lastIndexWhere((l) => profile.openedLevels.contains(l.id));
    for (final l in levels.skip(placedAt < 0 ? 0 : placedAt)) {
      if (isLevelUnlocked(l) && !(profile.levels[l.id]?.completed ?? false)) return l;
    }
    return null;
  }

  bool isIslandComplete(String islandId) {
    final levels = content.levelsOf(islandId);
    return levels.isNotEmpty && completedIn(islandId) == levels.length;
  }

  /// Levels tried at least twice and never passed: where a child is stuck.
  List<LevelDef> stuckLevels() => [
    for (final l in content.allLevels)
      if ((profile.levels[l.id]?.fails ?? 0) >= 2 && !(profile.levels[l.id]!.completed)) l,
  ];

  /// Counts one answer (first try only) toward the island and today's totals.
  void recordAnswer(String islandId, bool correct, [DateTime? now]) {
    final t = profile.islands.putIfAbsent(islandId, Tally.new);
    t.answers++;
    if (correct) t.correct++;
    final d = profile.days.putIfAbsent(dayKey(now ?? DateTime.now()), Tally.new);
    d.answers++;
    if (correct) d.correct++;
  }

  /// Saves a finished level and works out stars, unlocks and achievements.
  LevelResult finishLevel(LevelDef level, int correct, int seconds, [DateTime? now]) {
    final at = now ?? DateTime.now();
    final total = level.questions;
    final score = correct / total;
    final stars = starsFor(score, level.pass);
    final rec = profile.record(level.id);
    final wasCompleted = rec.completed;
    final newBest = stars > rec.bestStars;
    rec.attempts++;
    if (stars == 0) rec.fails++;
    if (newBest) rec.bestStars = stars;
    if (score > rec.bestScore) rec.bestScore = score;

    profile.islands.putIfAbsent(level.island, Tally.new).seconds += seconds;
    profile.days.putIfAbsent(dayKey(at), Tally.new).seconds += seconds;
    _trimDays(at);
    profile.sessions.add(
      SessionLog(
        levelId: level.id,
        at: at,
        correct: correct,
        total: total,
        stars: stars,
        seconds: seconds,
      ),
    );
    if (profile.sessions.length > Profile.maxSessions) profile.sessions.removeAt(0);

    final levels = content.levelsOf(level.island);
    final i = levels.indexOf(level);
    final next = i + 1 < levels.length ? levels[i + 1] : null;
    return LevelResult(
      correct: correct,
      total: total,
      stars: stars,
      newBest: newBest,
      nextLevel: next != null && isLevelUnlocked(next) ? next : null,
      suggestEasier: !wasCompleted && stars == 0 && rec.fails >= 2 && i > 0 ? levels[i - 1] : null,
      newAchievements: checkAchievements(at),
    );
  }

  /// Opens levels after the placement check. [results] maps a level to
  /// whether its probe question was answered correctly.
  void finishPlacement(Map<LevelDef, bool> results) {
    for (final island in content.islands) {
      final probes = results.entries.where((e) => e.key.island == island.id).toList()
        ..sort((a, b) => a.key.order.compareTo(b.key.order));
      final levels = content.levelsOf(island.id);
      for (final p in probes) {
        if (!p.value) break;
        // Open every level up to and including the probe.
        for (final l in levels.takeWhile((l) => l.order <= p.key.order)) {
          profile.openedLevels.add(l.id);
        }
      }
    }
    profile.placementDone = true;
  }

  /// Two probe levels per island, about a third and two thirds along.
  List<LevelDef> placementProbes() => [
    for (final island in content.islands)
      ...() {
        final levels = content.levelsOf(island.id);
        if (levels.length < 2) return <LevelDef>[];
        final a = levels.length ~/ 3;
        final b = (levels.length * 2) ~/ 3;
        return {levels[a == 0 ? 1 : a], levels[b]}.toList();
      }(),
  ];

  bool isAchieved(AchievementDef a, [DateTime? now]) => switch (a.type) {
    'levels_completed' => profile.levelsCompleted >= a.value,
    'total_stars' => profile.totalStars >= a.value,
    'perfect_levels' => profile.perfectLevels >= a.value,
    'island_complete' => isIslandComplete(a.island!),
    'correct_answers' => profile.totalCorrect >= a.value,
    'streak_days' => profile.bestStreak >= a.value,
    _ => false,
  };

  /// Unlocks any achievements newly earned and returns them.
  List<AchievementDef> checkAchievements([DateTime? now]) {
    final earned = <AchievementDef>[];
    for (final a in content.achievements) {
      if (!profile.achievements.containsKey(a.id) && isAchieved(a, now)) {
        profile.achievements[a.id] = dayKey(now ?? DateTime.now());
        earned.add(a);
      }
    }
    return earned;
  }

  /// Progress toward an achievement, 0 to 1, for the achievements screen.
  double progressToward(AchievementDef a) {
    final have = switch (a.type) {
      'levels_completed' => profile.levelsCompleted,
      'total_stars' => profile.totalStars,
      'perfect_levels' => profile.perfectLevels,
      'correct_answers' => profile.totalCorrect,
      'streak_days' => profile.bestStreak,
      'island_complete' => completedIn(a.island!),
      _ => 0,
    };
    final need = a.type == 'island_complete' ? content.levelsOf(a.island!).length : a.value;
    return need == 0 ? 0 : (have / need).clamp(0, 1).toDouble();
  }

  void _trimDays(DateTime now) {
    final cutoff = dayKey(now.subtract(const Duration(days: Profile.maxDays)));
    profile.days.removeWhere((k, _) => k.compareTo(cutoff) < 0);
  }
}
