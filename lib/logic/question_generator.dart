import 'dart:math';

import '../bn.dart';
import 'question.dart';
import 'skills.dart';

/// Everyday objects a child in Bangladesh will recognise.
const objectEmojis = ['🍎', '🥭', '🍌', '🐟', '🌸', '⭐', '🎈', '🐤', '🚲', '⚽'];

/// Builds questions for a skill and level. Levels follow
/// Concrete -> Pictorial -> Abstract: level 1 uses few objects,
/// level 3 moves to numerals only.
class QuestionGenerator {
  final Random _rng;
  QuestionGenerator([Random? rng]) : _rng = rng ?? Random();

  Question make(Skill skill, int level) => switch (skill) {
        Skill.counting => _counting(level),
        Skill.compare => _compare(level),
        Skill.addition => _addition(level),
        Skill.pattern => _pattern(level),
      };

  // ---------- Counting ----------

  Question _counting(int level) {
    final (lo, hi) = switch (level) { 1 => (1, 5), 2 => (3, 10), _ => (11, 20) };
    final n = _between(lo, hi);
    final emoji = _pick(objectEmojis);
    final numbers = _withDistractors(n, max(1, lo - 2), hi + 2);

    // Variation: sometimes ask the reverse (numeral -> group). Not at level 3,
    // where three groups of 11-20 objects would not fit on a small phone.
    if (level < 3 && _rng.nextInt(3) == 0) {
      final groups = numbers.map((k) => AnswerOption.group(ObjectGroup(emoji, k))).toList();
      return _shuffled(Question(
        skill: Skill.counting,
        level: level,
        prompt: 'কোন দলে ${bn(n)}টি আছে?',
        visuals: [BigText(bn(n))],
        options: groups,
        correctIndex: 0,
        hint: 'প্রতিটি দল আঙুল দিয়ে গুনে দেখো।',
      ));
    }
    return _shuffled(Question(
      skill: Skill.counting,
      level: level,
      prompt: 'কয়টি আছে?',
      visuals: [ObjectGroup(emoji, n)],
      options: numbers.map((k) => AnswerOption.text(bn(k))).toList(),
      correctIndex: 0,
      hint: 'একটি একটি করে গুনে দেখো।',
      hintNumbersObjects: true,
    ));
  }

  // ---------- More / less ----------

  Question _compare(int level) {
    final askMore = level == 1 || _rng.nextBool();
    final word = askMore ? 'বেশি' : 'কম';
    if (level == 3) {
      final a = _between(1, 20);
      var b = _between(1, 20);
      while (b == a) {
        b = _between(1, 20);
      }
      final answer = askMore ? max(a, b) : min(a, b);
      final other = answer == a ? b : a;
      return _shuffled(Question(
        skill: Skill.compare,
        level: level,
        prompt: askMore ? 'কোন সংখ্যাটি বড়?' : 'কোন সংখ্যাটি ছোট?',
        visuals: const [],
        options: [AnswerOption.text(bn(answer)), AnswerOption.text(bn(other))],
        correctIndex: 0,
        hint: '১ থেকে গুনতে থাকো। যেটি আগে আসে সেটি ছোট।',
      ));
    }
    final hi = level == 1 ? 5 : 10;
    final minGap = level == 1 ? 2 : 1;
    final a = _between(1, hi - minGap);
    final b = _between(a + minGap, hi);
    final answer = askMore ? b : a;
    final other = askMore ? a : b;
    final emoji = _pick(objectEmojis);
    return _shuffled(Question(
      skill: Skill.compare,
      level: level,
      prompt: 'কোন দলে $word আছে?',
      visuals: const [],
      options: [
        AnswerOption.group(ObjectGroup(emoji, answer)),
        AnswerOption.group(ObjectGroup(emoji, other)),
      ],
      correctIndex: 0,
      hint: 'দুই দল গুনে দেখো। কোনটিতে সংখ্যা $word?',
    ));
  }

  // ---------- Addition / subtraction ----------

  Question _addition(int level) {
    final emoji = _pick(objectEmojis);
    if (level == 3) {
      if (_rng.nextBool()) {
        final a = _between(2, 12);
        final b = _between(1, 20 - a);
        return _symbolic(level, a, '+', b, a + b, 20);
      }
      final a = _between(3, 10);
      final b = _between(1, a - 1);
      return _symbolic(level, a, '−', b, a - b, 10);
    }
    final total = level == 1 ? 5 : 10;
    final a = _between(1, total - 1);
    final b = _between(1, total - a);
    final sum = a + b;
    return _shuffled(Question(
      skill: Skill.addition,
      level: level,
      prompt: 'মোট কয়টি?',
      visuals: [ObjectGroup(emoji, a), const BigText('+'), ObjectGroup(emoji, b)],
      options: _withDistractors(sum, 1, total + 2).map((k) => AnswerOption.text(bn(k))).toList(),
      correctIndex: 0,
      hint: 'দুই দল মিলিয়ে সব গুনে দেখো।',
      hintNumbersObjects: true,
    ));
  }

  Question _symbolic(int level, int a, String op, int b, int answer, int hi) {
    return _shuffled(Question(
      skill: Skill.addition,
      level: level,
      prompt: op == '+' ? 'যোগ করো' : 'বিয়োগ করো',
      visuals: [BigText('${bn(a)} $op ${bn(b)} = ?')],
      options: _withDistractors(answer, 0, hi).map((k) => AnswerOption.text(bn(k))).toList(),
      correctIndex: 0,
      hint: op == '+'
          ? '${bn(a)} থেকে আরও ${bn(b)} গুনে সামনে যাও।'
          : '${bn(a)} থেকে ${bn(b)} ঘর পিছনে গুনে যাও।',
    ));
  }

  // ---------- Patterns: what comes next? ----------

  Question _pattern(int level) {
    if (level == 3) {
      final step = _pick([1, 2, 5, 10]);
      final down = step == 1 && _rng.nextBool();
      final start = step == 1 ? _between(down ? 6 : 1, down ? 15 : 10) : step * _between(0, 3);
      final seq = List.generate(5, (i) => down ? start - i : start + i * step);
      final answer = seq.last;
      final distractors = <int>{answer};
      for (final d in [answer + step, answer - step, answer + 1, answer - 1, answer + 2]) {
        if (d >= 0) distractors.add(d);
        if (distractors.length == 3) break;
      }
      return _shuffled(Question(
        skill: Skill.pattern,
        level: level,
        prompt: 'পরের সংখ্যাটি কী?',
        visuals: [
          Sequence([...seq.take(4).map(bn), '?'])
        ],
        options: distractors.map((k) => AnswerOption.text(bn(k))).toList(),
        correctIndex: 0,
        hint: 'প্রতিবার কত করে ${down ? 'কমছে' : 'বাড়ছে'} দেখো।',
      ));
    }
    final symbols = (List.of(objectEmojis)..shuffle(_rng)).take(4).toList();
    final unit = switch (level) {
      1 => [symbols[0], symbols[1]], // A B
      _ => _rng.nextBool()
          ? [symbols[0], symbols[0], symbols[1]] // A A B
          : [symbols[0], symbols[1], symbols[2]], // A B C
    };
    final shown = level == 1 ? 5 : 6;
    final seq = List.generate(shown + 1, (i) => unit[i % unit.length]);
    final answer = seq.last;
    final wrong = {...unit, symbols[3]}.where((s) => s != answer).take(2);
    return _shuffled(Question(
      skill: Skill.pattern,
      level: level,
      prompt: 'পরেরটা কী হবে?',
      visuals: [
        Sequence([...seq.take(shown), '?'])
      ],
      options: [AnswerOption.text(answer), ...wrong.map(AnswerOption.text)],
      correctIndex: 0,
      hint: 'কোন অংশটি বারবার ফিরে আসছে খুঁজে দেখো।',
    ));
  }

  // ---------- helpers ----------

  int _between(int lo, int hi) => lo + _rng.nextInt(hi - lo + 1);

  T _pick<T>(List<T> items) => items[_rng.nextInt(items.length)];

  /// [answer] first, then two different nearby numbers within [lo, hi].
  List<int> _withDistractors(int answer, int lo, int hi) {
    final result = [answer];
    final candidates = [answer + 1, answer - 1, answer + 2, answer - 2, answer + 3, answer - 3]
      ..shuffle(_rng);
    for (final c in candidates) {
      if (c >= lo && c <= hi && !result.contains(c)) result.add(c);
      if (result.length == 3) break;
    }
    return result;
  }

  /// Every builder puts the correct option first; this shuffles the options
  /// and updates [Question.correctIndex] to match.
  Question _shuffled(Question q) {
    final order = List.generate(q.options.length, (i) => i)..shuffle(_rng);
    return Question(
      skill: q.skill,
      level: q.level,
      prompt: q.prompt,
      visuals: q.visuals,
      options: [for (final i in order) q.options[i]],
      correctIndex: order.indexOf(q.correctIndex),
      hint: q.hint,
      hintNumbersObjects: q.hintNumbersObjects,
    );
  }
}
