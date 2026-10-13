/// Something shown in the question area.
sealed class Visual {
  const Visual();
}

/// A group of identical objects, laid out in rows of five.
/// The last [crossed] objects are shown crossed out (for take-away puzzles).
class ObjectGroup extends Visual {
  final String emoji;
  final int count;
  final int crossed;
  const ObjectGroup(this.emoji, this.count, {this.crossed = 0});
}

/// A large piece of text: a numeral, "+", "=", or a whole sum like "৭ + ৮ = ?".
class BigText extends Visual {
  final String text;
  const BigText(this.text);
}

/// A row of items in a pattern, the last of which is "?".
class Sequence extends Visual {
  final List<String> items;
  const Sequence(this.items);
}

/// One answer button: either text (a numeral or emoji) or a group of objects.
class AnswerOption {
  final String? label;
  final ObjectGroup? group;
  const AnswerOption.text(String this.label) : group = null;
  const AnswerOption.group(ObjectGroup this.group) : label = null;
}

class Question {
  /// Short instruction in Bangla.
  final String prompt;
  final List<Visual> visuals;
  final List<AnswerOption> options;
  final int correctIndex;

  /// Shown after a wrong answer.
  final String hint;

  /// When true, the hint also numbers each object so the child can count along.
  final bool hintNumbersObjects;

  /// What the voice says, when it should say more than [prompt] (e.g. the sum itself).
  final String? speech;

  String get spoken => speech ?? prompt;

  const Question({
    required this.prompt,
    required this.visuals,
    required this.options,
    required this.correctIndex,
    required this.hint,
    this.hintNumbersObjects = false,
    this.speech,
  });
}
