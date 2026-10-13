/// A child's saved data. Everything stays on this device.
library;

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Best result and attempts for one level.
class LevelRecord {
  int bestStars;
  double bestScore;
  int attempts;
  int fails;

  LevelRecord({this.bestStars = 0, this.bestScore = 0, this.attempts = 0, this.fails = 0});

  bool get completed => bestStars > 0;

  Map<String, dynamic> toJson() => {
    'stars': bestStars,
    'score': bestScore,
    'attempts': attempts,
    'fails': fails,
  };

  factory LevelRecord.fromJson(Map<String, dynamic> j) => LevelRecord(
    bestStars: (j['stars'] as num?)?.toInt() ?? 0,
    bestScore: (j['score'] as num?)?.toDouble() ?? 0,
    attempts: (j['attempts'] as num?)?.toInt() ?? 0,
    fails: (j['fails'] as num?)?.toInt() ?? 0,
  );
}

/// Answers and time on one island, or on one day.
class Tally {
  int answers;
  int correct;
  int seconds;

  Tally({this.answers = 0, this.correct = 0, this.seconds = 0});

  double get accuracy => answers == 0 ? 0 : correct / answers;

  Map<String, dynamic> toJson() => {'a': answers, 'c': correct, 's': seconds};

  factory Tally.fromJson(Map<String, dynamic> j) => Tally(
    answers: (j['a'] as num?)?.toInt() ?? 0,
    correct: (j['c'] as num?)?.toInt() ?? 0,
    seconds: (j['s'] as num?)?.toInt() ?? 0,
  );
}

/// One finished play of a level.
class SessionLog {
  final String levelId;
  final DateTime at;
  final int correct;
  final int total;
  final int stars;
  final int seconds;

  const SessionLog({
    required this.levelId,
    required this.at,
    required this.correct,
    required this.total,
    required this.stars,
    required this.seconds,
  });

  Map<String, dynamic> toJson() => {
    'level': levelId,
    'at': at.toIso8601String(),
    'correct': correct,
    'total': total,
    'stars': stars,
    'seconds': seconds,
  };

  factory SessionLog.fromJson(Map<String, dynamic> j) => SessionLog(
    levelId: j['level'] as String,
    at: DateTime.parse(j['at'] as String),
    correct: (j['correct'] as num).toInt(),
    total: (j['total'] as num).toInt(),
    stars: (j['stars'] as num).toInt(),
    seconds: (j['seconds'] as num).toInt(),
  );
}

class Profile {
  static const maxSessions = 50;
  static const maxDays = 90;

  final String id;
  String name;
  String avatar;
  final DateTime createdAt;

  /// Guests play without saving anything.
  final bool isGuest;

  bool placementDone;

  /// Levels opened by the placement check (playable without finishing earlier ones).
  final Set<String> openedLevels;
  final Map<String, LevelRecord> levels;

  /// Achievement id -> date unlocked.
  final Map<String, String> achievements;
  final Map<String, Tally> islands;

  /// 'yyyy-mm-dd' -> what was played that day.
  final Map<String, Tally> days;

  /// Most recent last.
  final List<SessionLog> sessions;

  Profile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.createdAt,
    this.isGuest = false,
    this.placementDone = false,
    Set<String>? openedLevels,
    Map<String, LevelRecord>? levels,
    Map<String, String>? achievements,
    Map<String, Tally>? islands,
    Map<String, Tally>? days,
    List<SessionLog>? sessions,
  }) : openedLevels = openedLevels ?? {},
       levels = levels ?? {},
       achievements = achievements ?? {},
       islands = islands ?? {},
       days = days ?? {},
       sessions = sessions ?? [];

  factory Profile.guest() =>
      Profile(id: 'guest', name: 'অতিথি', avatar: '🙂', createdAt: DateTime.now(), isGuest: true);

  LevelRecord record(String levelId) => levels.putIfAbsent(levelId, LevelRecord.new);

  int get totalStars => levels.values.fold(0, (sum, r) => sum + r.bestStars);
  int get levelsCompleted => levels.values.where((r) => r.completed).length;
  int get perfectLevels => levels.values.where((r) => r.bestStars == 3).length;
  int get totalAnswers => islands.values.fold(0, (sum, t) => sum + t.answers);
  int get totalCorrect => islands.values.fold(0, (sum, t) => sum + t.correct);
  int get totalSeconds => days.values.fold(0, (sum, t) => sum + t.seconds);
  DateTime? get lastPlayed => sessions.isEmpty ? null : sessions.last.at;

  /// Days in a row played, ending today or yesterday.
  int streak([DateTime? now]) {
    var day = now ?? DateTime.now();
    if (!days.containsKey(dayKey(day))) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (days.containsKey(dayKey(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Longest run of days in a row ever played (for achievements).
  int get bestStreak {
    final sorted = days.keys.map(DateTime.parse).toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in sorted) {
      run = (prev != null && d.difference(prev).inHours.round() <= 24 + 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  /// Copies a guest's progress into a new saved profile.
  Profile savedAs({required String id, required String name, required String avatar}) => Profile(
    id: id,
    name: name,
    avatar: avatar,
    createdAt: createdAt,
    placementDone: placementDone,
    openedLevels: {...openedLevels},
    levels: levels,
    achievements: achievements,
    islands: islands,
    days: days,
    sessions: sessions,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'createdAt': createdAt.toIso8601String(),
    'placementDone': placementDone,
    'openedLevels': openedLevels.toList(),
    'levels': {for (final e in levels.entries) e.key: e.value.toJson()},
    'achievements': achievements,
    'islands': {for (final e in islands.entries) e.key: e.value.toJson()},
    'days': {for (final e in days.entries) e.key: e.value.toJson()},
    'sessions': sessions.map((s) => s.toJson()).toList(),
  };

  factory Profile.fromJson(Map<String, dynamic> j) {
    Map<String, T> mapOf<T>(String key, T Function(Map<String, dynamic>) f) => {
      for (final e in ((j[key] as Map?) ?? {}).entries)
        e.key as String: f(e.value as Map<String, dynamic>),
    };
    return Profile(
      id: j['id'] as String,
      name: j['name'] as String,
      avatar: j['avatar'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      placementDone: j['placementDone'] as bool? ?? false,
      openedLevels: ((j['openedLevels'] as List?) ?? []).cast<String>().toSet(),
      levels: mapOf('levels', LevelRecord.fromJson),
      achievements: ((j['achievements'] as Map?) ?? {}).cast<String, String>(),
      islands: mapOf('islands', Tally.fromJson),
      days: mapOf('days', Tally.fromJson),
      sessions: ((j['sessions'] as List?) ?? [])
          .map((s) => SessionLog.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
