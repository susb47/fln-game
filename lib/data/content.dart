import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/puzzle_factory.dart';

/// Folder scanned for level files. Every `*.json` file in it is one level.
/// Files whose name starts with `_` are ignored (use that for drafts).
const levelsFolder = 'assets/levels/';
const islandsFile = 'assets/config/islands.json';
const achievementsFile = 'assets/config/achievements.json';

/// One island on the map, from `assets/config/islands.json`.
class IslandDef {
  final String id;
  final String title;
  final String emoji;
  final Color color;

  /// Island whose levels must be finished first, or null if open from the start.
  final String? unlockIsland;
  final int unlockLevels;

  const IslandDef({
    required this.id,
    required this.title,
    required this.emoji,
    required this.color,
    this.unlockIsland,
    this.unlockLevels = 0,
  });

  /// A pale, fully opaque tint of [color] for backgrounds.
  /// (A see-through colour here is what made screens go black.)
  Color get background => Color.alphaBlend(color.withValues(alpha: 0.15), Colors.white);

  factory IslandDef.fromJson(Map<String, dynamic> j) {
    final unlock = j['unlock'] as Map<String, dynamic>?;
    return IslandDef(
      id: j['id'] as String,
      title: j['title'] as String,
      emoji: j['emoji'] as String,
      color: _parseColor(j['color'] as String),
      unlockIsland: unlock?['island'] as String?,
      unlockLevels: (unlock?['levels'] as num?)?.toInt() ?? 0,
    );
  }
}

Color _parseColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
}

/// One kind of puzzle with its settings, e.g. `{"type": "count", "min": 1, "max": 5}`.
class PuzzleSpec {
  final String type;
  final Map<String, dynamic> params;

  const PuzzleSpec(this.type, this.params);

  int integer(String key, int fallback) => (params[key] as num?)?.toInt() ?? fallback;
  String text(String key, String fallback) => params[key] as String? ?? fallback;
  List<int> integers(String key, List<int> fallback) =>
      (params[key] as List?)?.map((e) => (e as num).toInt()).toList() ?? fallback;
  List<String>? strings(String key) => (params[key] as List?)?.cast<String>();

  factory PuzzleSpec.fromJson(Map<String, dynamic> j) => PuzzleSpec(j['type'] as String, j);
}

/// One level, loaded from a file in `assets/levels/`.
class LevelDef {
  final String id;
  final String island;
  final int order;
  final String title;

  /// Questions per play of this level.
  final int questions;

  /// Share of first-try correct answers needed to pass (0.75 = 75%).
  final double pass;

  /// Each question picks one of these at random.
  final List<PuzzleSpec> puzzles;

  final String source;

  const LevelDef({
    required this.id,
    required this.island,
    required this.order,
    required this.title,
    required this.questions,
    required this.pass,
    required this.puzzles,
    this.source = '',
  });

  factory LevelDef.fromJson(Map<String, dynamic> j, {String source = ''}) => LevelDef(
    id: j['id'] as String,
    island: j['island'] as String,
    order: (j['order'] as num).toInt(),
    title: j['title'] as String,
    questions: (j['questions'] as num?)?.toInt() ?? 8,
    pass: (j['pass'] as num?)?.toDouble() ?? 0.75,
    puzzles: (j['puzzles'] as List)
        .map((p) => PuzzleSpec.fromJson(p as Map<String, dynamic>))
        .toList(),
    source: source,
  );
}

/// One achievement, from `assets/config/achievements.json`.
class AchievementDef {
  final String id;
  final String emoji;
  final String title;
  final String description;

  /// levels_completed, total_stars, perfect_levels, island_complete,
  /// correct_answers, streak_days
  final String type;
  final int value;
  final String? island;

  const AchievementDef({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.type,
    this.value = 1,
    this.island,
  });

  factory AchievementDef.fromJson(Map<String, dynamic> j) => AchievementDef(
    id: j['id'] as String,
    emoji: j['emoji'] as String,
    title: j['title'] as String,
    description: j['description'] as String? ?? '',
    type: j['type'] as String,
    value: (j['value'] as num?)?.toInt() ?? 1,
    island: j['island'] as String?,
  );
}

const achievementTypes = {
  'levels_completed',
  'total_stars',
  'perfect_levels',
  'island_complete',
  'correct_answers',
  'streak_days',
};

/// Everything the game reads from files: islands, levels and achievements.
class Content {
  final List<IslandDef> islands;
  final List<AchievementDef> achievements;
  final Map<String, List<LevelDef>> _levelsByIsland;

  /// Problems found while loading. Broken files are skipped, not fatal.
  final List<String> errors;

  Content({
    required this.islands,
    required List<LevelDef> levels,
    required this.achievements,
    this.errors = const [],
  }) : _levelsByIsland = {
         for (final i in islands)
           i.id: levels.where((l) => l.island == i.id).toList()
             ..sort((a, b) => a.order.compareTo(b.order)),
       };

  List<LevelDef> levelsOf(String islandId) => _levelsByIsland[islandId] ?? const [];
  List<LevelDef> get allLevels => [for (final i in islands) ...levelsOf(i.id)];
  IslandDef island(String id) => islands.firstWhere((i) => i.id == id);

  LevelDef? level(String id) {
    for (final l in allLevels) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Reads every file. Works with any [AssetBundle], so tests can use files on disk.
  static Future<Content> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(b);
    final files =
        manifest
            .listAssets()
            .where((p) => p.startsWith(levelsFolder) && p.endsWith('.json'))
            .where((p) => !p.substring(levelsFolder.length).startsWith('_'))
            .toList()
          ..sort();
    final texts = <String, String>{for (final f in files) f: await b.loadString(f)};
    return parse(
      islandsJson: await b.loadString(islandsFile),
      achievementsJson: await b.loadString(achievementsFile),
      levelFiles: texts,
    );
  }

  /// Parses and validates content. Invalid levels are left out and reported in [errors].
  static Content parse({
    required String islandsJson,
    required String achievementsJson,
    required Map<String, String> levelFiles,
  }) {
    final errors = <String>[];
    final islands = (jsonDecode(islandsJson)['islands'] as List)
        .map((j) => IslandDef.fromJson(j as Map<String, dynamic>))
        .toList();
    final islandIds = islands.map((i) => i.id).toSet();
    for (final i in islands) {
      if (i.unlockIsland != null && !islandIds.contains(i.unlockIsland)) {
        errors.add('islands.json: "${i.id}" unlocks after unknown island "${i.unlockIsland}"');
      }
    }

    final levels = <LevelDef>[];
    final ids = <String>{};
    for (final MapEntry(key: file, value: text) in levelFiles.entries) {
      final LevelDef level;
      try {
        level = LevelDef.fromJson(jsonDecode(text) as Map<String, dynamic>, source: file);
      } catch (e) {
        errors.add('$file: cannot read it ($e)');
        continue;
      }
      final problems = <String>[
        if (!islandIds.contains(level.island)) 'unknown island "${level.island}"',
        if (ids.contains(level.id)) 'id "${level.id}" is already used by another level',
        if (level.questions < 1 || level.questions > 30) '"questions" must be 1 to 30',
        if (level.pass <= 0 || level.pass > 1) '"pass" must be more than 0 and at most 1',
        if (level.puzzles.isEmpty) '"puzzles" is empty',
        for (final p in level.puzzles) ...PuzzleFactory.validate(p),
      ];
      if (problems.isEmpty) {
        levels.add(level);
        ids.add(level.id);
      } else {
        errors.addAll(problems.map((p) => '$file: $p'));
      }
    }

    final achievements = <AchievementDef>[];
    for (final j in jsonDecode(achievementsJson)['achievements'] as List) {
      try {
        final a = AchievementDef.fromJson(j as Map<String, dynamic>);
        if (!achievementTypes.contains(a.type)) {
          errors.add('achievements.json: "${a.id}" has unknown type "${a.type}"');
        } else if (a.type == 'island_complete' && !islandIds.contains(a.island)) {
          errors.add('achievements.json: "${a.id}" names unknown island "${a.island}"');
        } else {
          achievements.add(a);
        }
      } catch (e) {
        errors.add('achievements.json: cannot read an entry ($e)');
      }
    }

    if (kDebugMode) {
      for (final e in errors) {
        debugPrint('CONTENT ERROR: $e');
      }
    }
    return Content(islands: islands, levels: levels, achievements: achievements, errors: errors);
  }
}
