import 'dart:math';

import '../bn.dart';
import '../data/content.dart';
import 'question.dart';

/// Everyday objects a child in Bangladesh will recognise.
const defaultObjects = ['🍎', '🥭', '🍌', '🐟', '🌸', '⭐', '🎈', '🐤', '🚲', '⚽'];

/// Turns a [PuzzleSpec] from a level file into a question.
///
/// To add a new puzzle type: add a case to [make], a case to [validate],
/// and describe it in docs/LEVELS.md.
class PuzzleFactory {
  final Random _rng;
  PuzzleFactory([Random? rng]) : _rng = rng ?? Random();

  static const types = {
    'count',
    'find_group',
    'compare_groups',
    'compare_numbers',
    'add_objects',
    'add_numbers',
    'subtract_objects',
    'subtract_numbers',
    'pattern_pictures',
    'pattern_numbers',
  };

  /// A question for one random puzzle of [level].
  Question forLevel(LevelDef level) => make(level.puzzles[_rng.nextInt(level.puzzles.length)]);

  Question make(PuzzleSpec s) => switch (s.type) {
    'count' => _count(s),
    'find_group' => _findGroup(s),
    'compare_groups' => _compareGroups(s),
    'compare_numbers' => _compareNumbers(s),
    'add_objects' => _addObjects(s),
    'add_numbers' => _addNumbers(s),
    'subtract_objects' => _subtractObjects(s),
    'subtract_numbers' => _subtractNumbers(s),
    'pattern_pictures' => _patternPictures(s),
    'pattern_numbers' => _patternNumbers(s),
    _ => throw ArgumentError('Unknown puzzle type "${s.type}"'),
  };

  /// Problems with a spec, in plain words, for level authors.
  static List<String> validate(PuzzleSpec s) {
    final t = s.type;
    final errors = <String>[];
    void range(String lo, String hi, int min, int max) {
      final a = s.integer(lo, -1), b = s.integer(hi, -1);
      if (a < min || b > max || a > b) {
        errors.add('$t: "$lo" and "$hi" must satisfy $min <= $lo <= $hi <= $max');
      }
    }

    void atMost(String key, int min, int max) {
      final v = s.integer(key, -1);
      if (v < min || v > max) errors.add('$t: "$key" must be $min to $max');
    }

    void oneOf(String key, Set<String> allowed, String fallback) {
      if (!allowed.contains(s.text(key, fallback))) {
        errors.add('$t: "$key" must be one of ${allowed.join(", ")}');
      }
    }

    switch (t) {
      case 'count':
        range('min', 'max', 1, 20);
      case 'find_group':
        range('min', 'max', 1, 10);
      case 'compare_groups':
        range('min', 'max', 1, 10);
        oneOf('ask', {'more', 'less', 'mixed'}, 'more');
        if (s.integer('max', 0) - s.integer('min', 0) < s.integer('minGap', 1)) {
          errors.add('$t: "max" minus "min" must be at least "minGap"');
        }
      case 'compare_numbers':
        range('min', 'max', 0, 100);
        oneOf('ask', {'more', 'less', 'mixed'}, 'more');
      case 'add_objects':
        atMost('maxSum', 2, 10);
      case 'add_numbers':
        atMost('maxSum', 2, 100);
      case 'subtract_objects':
        atMost('max', 2, 10);
      case 'subtract_numbers':
        atMost('max', 2, 100);
      case 'pattern_pictures':
        oneOf('unit', {'AB', 'AAB', 'ABB', 'ABC', 'ABCD'}, 'AB');
      case 'pattern_numbers':
        if (s.integers('steps', [1]).any((x) => x < 1 || x > 100)) {
          errors.add('$t: every "steps" value must be 1 to 100');
        }
        oneOf('direction', {'up', 'down', 'mixed'}, 'up');
        atMost('maxStart', 0, 100);
      default:
        errors.add('unknown puzzle type "$t" (known: ${types.join(", ")})');
    }
    final objects = s.strings('objects');
    if (objects != null && objects.length < 5) {
      errors.add('$t: "objects" needs at least 5 emoji');
    }
    return errors;
  }

  // ---------- Counting ----------

  Question _count(PuzzleSpec s) {
    final lo = s.integer('min', 1), hi = s.integer('max', 5);
    final n = _between(lo, hi);
    return _shuffled(
      Question(
        prompt: 'কয়টি আছে?',
        visuals: [ObjectGroup(_object(s), n)],
        options: _numbers(n, max(1, lo - 2), hi + 2),
        correctIndex: 0,
        hint: 'একটি একটি করে গুনে দেখো।',
        hintNumbersObjects: true,
      ),
    );
  }

  Question _findGroup(PuzzleSpec s) {
    final lo = s.integer('min', 1), hi = s.integer('max', 5);
    final n = _between(lo, hi);
    final emoji = _object(s);
    return _shuffled(
      Question(
        prompt: 'কোন দলে ${bn(n)}টি আছে?',
        visuals: [BigText(bn(n))],
        options: [
          for (final k in _withDistractors(n, 1, hi + 2)) AnswerOption.group(ObjectGroup(emoji, k)),
        ],
        correctIndex: 0,
        hint: 'প্রতিটি দল আঙুল দিয়ে গুনে দেখো।',
      ),
    );
  }

  // ---------- More / less ----------

  bool _askMore(PuzzleSpec s) => switch (s.text('ask', 'more')) {
    'less' => false,
    'mixed' => _rng.nextBool(),
    _ => true,
  };

  Question _compareGroups(PuzzleSpec s) {
    final lo = s.integer('min', 1), hi = s.integer('max', 5), gap = s.integer('minGap', 1);
    final more = _askMore(s);
    final word = more ? 'বেশি' : 'কম';
    final a = _between(lo, hi - gap);
    final b = _between(a + gap, hi);
    final emoji = _object(s);
    return _shuffled(
      Question(
        prompt: 'কোন দলে $word আছে?',
        visuals: const [],
        options: [
          AnswerOption.group(ObjectGroup(emoji, more ? b : a)),
          AnswerOption.group(ObjectGroup(emoji, more ? a : b)),
        ],
        correctIndex: 0,
        hint: 'দুই দল গুনে দেখো। কোনটিতে সংখ্যা $word?',
      ),
    );
  }

  Question _compareNumbers(PuzzleSpec s) {
    final lo = s.integer('min', 1), hi = s.integer('max', 20);
    final more = _askMore(s);
    final a = _between(lo, hi);
    var b = _between(lo, hi);
    while (b == a) {
      b = _between(lo, hi);
    }
    final answer = more ? max(a, b) : min(a, b);
    final other = answer == a ? b : a;
    return _shuffled(
      Question(
        prompt: more ? 'কোন সংখ্যাটি বড়?' : 'কোন সংখ্যাটি ছোট?',
        speech: '${bn(min(a, b))} আর ${bn(max(a, b))}, ${more ? 'কোনটি বড়?' : 'কোনটি ছোট?'}',
        visuals: const [],
        options: [AnswerOption.text(bn(answer)), AnswerOption.text(bn(other))],
        correctIndex: 0,
        hint: '১ থেকে গুনতে থাকো। যেটি আগে আসে সেটি ছোট।',
      ),
    );
  }

  // ---------- Addition / subtraction ----------

  Question _addObjects(PuzzleSpec s) {
    final total = s.integer('maxSum', 5);
    final a = _between(1, total - 1);
    final b = _between(1, total - a);
    final emoji = _object(s);
    return _shuffled(
      Question(
        prompt: 'মোট কয়টি?',
        visuals: [ObjectGroup(emoji, a), const BigText('+'), ObjectGroup(emoji, b)],
        options: _numbers(a + b, 1, total + 2),
        correctIndex: 0,
        hint: 'দুই দল মিলিয়ে সব গুনে দেখো।',
        hintNumbersObjects: true,
      ),
    );
  }

  Question _addNumbers(PuzzleSpec s) {
    final total = s.integer('maxSum', 10);
    final a = _between(1, total - 1);
    final b = _between(1, total - a);
    return _shuffled(
      Question(
        prompt: 'যোগ করো',
        speech: '${bn(a)} যোগ ${bn(b)} সমান কত?',
        visuals: [BigText('${bn(a)} + ${bn(b)} = ?')],
        options: _numbers(a + b, 0, total + 2),
        correctIndex: 0,
        hint: '${bn(a)} থেকে আরও ${bn(b)} গুনে সামনে যাও।',
      ),
    );
  }

  Question _subtractObjects(PuzzleSpec s) {
    final hi = s.integer('max', 7);
    final a = _between(2, hi);
    final b = _between(1, a - 1);
    return _shuffled(
      Question(
        prompt: '${bn(b)}টি চলে গেল। কয়টি বাকি?',
        visuals: [ObjectGroup(_object(s), a, crossed: b)],
        options: _numbers(a - b, 0, hi),
        correctIndex: 0,
        hint: 'কাটা নেই এমনগুলো গুনে দেখো।',
      ),
    );
  }

  Question _subtractNumbers(PuzzleSpec s) {
    final hi = s.integer('max', 10);
    final a = _between(2, hi);
    final b = _between(1, a - 1);
    return _shuffled(
      Question(
        prompt: 'বিয়োগ করো',
        speech: '${bn(a)} বিয়োগ ${bn(b)} সমান কত?',
        visuals: [BigText('${bn(a)} − ${bn(b)} = ?')],
        options: _numbers(a - b, 0, hi),
        correctIndex: 0,
        hint: '${bn(a)} থেকে ${bn(b)} ঘর পিছনে গুনে যাও।',
      ),
    );
  }

  // ---------- Patterns ----------

  Question _patternPictures(PuzzleSpec s) {
    final unitCode = s.text('unit', 'AB');
    final symbols = (List.of(_objects(s))..shuffle(_rng)).take(5).toList();
    final unit = [for (final c in unitCode.split('')) symbols[c.codeUnitAt(0) - 65]];
    final shown = max(5, unit.length * 2);
    final seq = List.generate(shown + 1, (i) => unit[i % unit.length]);
    final answer = seq.last;
    final wrong = {...unit, symbols[4]}.where((x) => x != answer).take(2);
    return _shuffled(
      Question(
        prompt: 'পরেরটা কী হবে?',
        visuals: [
          Sequence([...seq.take(shown), '?']),
        ],
        options: [AnswerOption.text(answer), ...wrong.map(AnswerOption.text)],
        correctIndex: 0,
        hint: 'কোন অংশটি বারবার ফিরে আসছে খুঁজে দেখো।',
      ),
    );
  }

  Question _patternNumbers(PuzzleSpec s) {
    final step = _pick(s.integers('steps', [1]));
    final dir = s.text('direction', 'up');
    final down = dir == 'down' || (dir == 'mixed' && _rng.nextBool());
    final maxStart = s.integer('maxStart', 10);
    final int start;
    if (down) {
      start = 4 * step + _between(0, maxStart); // never goes below zero
    } else {
      // Skip counting by 2, 5 or 10 starts on a multiple of the step.
      start = step == 1 ? _between(0, maxStart) : step * _between(0, maxStart ~/ step);
    }
    final seq = List.generate(5, (i) => down ? start - i * step : start + i * step);
    final answer = seq.last;
    final options = <int>{answer};
    for (final d in [answer + step, answer - step, answer + 1, answer - 1, answer + 2]) {
      if (d >= 0) options.add(d);
      if (options.length == 3) break;
    }
    return _shuffled(
      Question(
        prompt: 'পরের সংখ্যাটি কী?',
        speech: '${seq.take(4).map(bn).join(', ')}, তারপর কত?',
        visuals: [
          Sequence([...seq.take(4).map(bn), '?']),
        ],
        options: options.map((k) => AnswerOption.text(bn(k))).toList(),
        correctIndex: 0,
        hint: 'প্রতিবার কত করে ${down ? 'কমছে' : 'বাড়ছে'} দেখো।',
      ),
    );
  }

  // ---------- helpers ----------

  List<String> _objects(PuzzleSpec s) => s.strings('objects') ?? defaultObjects;
  String _object(PuzzleSpec s) => _pick(_objects(s));

  int _between(int lo, int hi) => lo + _rng.nextInt(hi - lo + 1);

  T _pick<T>(List<T> items) => items[_rng.nextInt(items.length)];

  List<AnswerOption> _numbers(int answer, int lo, int hi) =>
      _withDistractors(answer, lo, hi).map((k) => AnswerOption.text(bn(k))).toList();

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
  /// and moves [Question.correctIndex] to match.
  Question _shuffled(Question q) {
    final order = List.generate(q.options.length, (i) => i)..shuffle(_rng);
    return Question(
      prompt: q.prompt,
      visuals: q.visuals,
      options: [for (final i in order) q.options[i]],
      correctIndex: order.indexOf(q.correctIndex),
      hint: q.hint,
      hintNumbersObjects: q.hintNumbersObjects,
      speech: q.speech,
    );
  }
}
