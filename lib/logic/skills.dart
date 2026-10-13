import 'package:flutter/material.dart';

/// The skill strands ("islands") in this first version.
/// Order matters: it is the order shown on the home map.
enum Skill { counting, compare, addition, pattern }

/// Highest level in each strand. Mastering level [maxLevel] completes the island.
const maxLevel = 3;

extension SkillInfo on Skill {
  String get title => switch (this) {
        Skill.counting => 'গণনা',
        Skill.compare => 'বেশি না কম',
        Skill.addition => 'যোগ-বিয়োগ',
        Skill.pattern => 'পরেরটা কী?',
      };

  String get emoji => switch (this) {
        Skill.counting => '🍎',
        Skill.compare => '⚖️',
        Skill.addition => '➕',
        Skill.pattern => '🧩',
      };

  Color get color => switch (this) {
        Skill.counting => const Color(0xFFE76F51),
        Skill.compare => const Color(0xFF2A9D8F),
        Skill.addition => const Color(0xFF457B9D),
        Skill.pattern => const Color(0xFF9C6ADE),
      };

  /// The island that must reach level 2 before this one opens, or null if
  /// it is open from the start.
  Skill? get prerequisite => switch (this) {
        Skill.counting => null,
        Skill.compare => Skill.counting,
        Skill.addition => Skill.compare,
        Skill.pattern => null,
      };
}
