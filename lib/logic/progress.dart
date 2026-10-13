import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'skills.dart';

/// Tuning knobs for the adaptive rules. The plan says to tune these in the pilot.
class Rules {
  /// How many recent first-try answers are looked at.
  static const window = 10;

  /// Correct answers needed in that window to move up (8 of 10 = 80%).
  static const toLevelUp = 8;

  /// Wrong answers in a row that move the child back down a level.
  static const wrongInARowToDrop = 3;
}

enum LevelChange { none, up, down, mastered }

class SkillProgress {
  int level;
  bool mastered;

  /// Recent first-try results at the current level, oldest first.
  final List<bool> recent;

  SkillProgress({this.level = 1, this.mastered = false, List<bool>? recent})
      : recent = recent ?? [];

  /// 0 to 3 stars shown on the island.
  int get stars => mastered ? 3 : level - 1;

  Map<String, dynamic> toJson() => {'level': level, 'mastered': mastered, 'recent': recent};

  factory SkillProgress.fromJson(Map<String, dynamic> j) => SkillProgress(
        level: (j['level'] as int).clamp(1, maxLevel),
        mastered: j['mastered'] as bool? ?? false,
        recent: (j['recent'] as List?)?.cast<bool>().toList(),
      );
}

/// One child's progress, stored only on this device.
class Progress extends ChangeNotifier {
  static const _key = 'progress_v1';

  final SharedPreferences? _prefs;
  bool placementDone;
  final Map<Skill, SkillProgress> skills;

  Progress._(this._prefs, this.placementDone, this.skills);

  /// In-memory progress for tests.
  factory Progress.fresh() => Progress._(null, false, _emptySkills());

  static Map<Skill, SkillProgress> _emptySkills() =>
      {for (final s in Skill.values) s: SkillProgress()};

  static Future<Progress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final skills = _emptySkills();
    var placementDone = false;
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        placementDone = j['placementDone'] as bool? ?? false;
        final saved = j['skills'] as Map<String, dynamic>? ?? {};
        for (final s in Skill.values) {
          if (saved[s.name] != null) skills[s] = SkillProgress.fromJson(saved[s.name]);
        }
      } catch (_) {
        // Corrupt or old data: start fresh rather than crash.
      }
    }
    return Progress._(prefs, placementDone, skills);
  }

  bool isUnlocked(Skill s) {
    final pre = s.prerequisite;
    if (pre == null) return true;
    final p = skills[pre]!;
    return p.mastered || p.level >= 2;
  }

  /// Records a first-try result and applies the adaptive rules.
  LevelChange record(Skill skill, bool correct) {
    final p = skills[skill]!;
    p.recent.add(correct);
    if (p.recent.length > Rules.window) p.recent.removeAt(0);

    var change = LevelChange.none;
    final tail = p.recent.length >= Rules.wrongInARowToDrop
        ? p.recent.sublist(p.recent.length - Rules.wrongInARowToDrop)
        : const <bool>[];
    if (tail.isNotEmpty && tail.every((r) => !r)) {
      if (p.level > 1) {
        p.level--;
        p.mastered = false;
        change = LevelChange.down;
      }
      p.recent.clear();
    } else if (p.recent.length >= Rules.window &&
        p.recent.where((r) => r).length >= Rules.toLevelUp) {
      if (p.level < maxLevel) {
        p.level++;
        change = LevelChange.up;
      } else if (!p.mastered) {
        p.mastered = true;
        change = LevelChange.mastered;
      }
      p.recent.clear();
    }
    _save();
    return change;
  }

  /// Sets starting levels from the placement check.
  void finishPlacement(Map<Skill, int> startLevels) {
    for (final e in startLevels.entries) {
      skills[e.key] = SkillProgress(level: e.value.clamp(1, maxLevel));
    }
    placementDone = true;
    _save();
  }

  void reset() {
    skills
      ..clear()
      ..addAll(_emptySkills());
    placementDone = false;
    _save();
  }

  void _save() {
    notifyListeners();
    _prefs?.setString(
      _key,
      jsonEncode({
        'placementDone': placementDone,
        'skills': {for (final e in skills.entries) e.key.name: e.value.toJson()},
      }),
    );
  }
}
