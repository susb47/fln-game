import 'dart:convert';

import 'package:flutter/services.dart';

const charactersFile = 'assets/config/characters.json';
const dialogueFile = 'assets/config/dialogue.json';
const clipsFile = 'assets/voice/clips.json';

/// Events the game reacts to with a spoken line. Each one is a key in dialogue.json.
const dialogueEvents = {
  'welcome',
  'placement_start',
  'level_start',
  'question',
  'correct',
  'correct_retry',
  'wrong_first',
  'wrong_again',
  'level_pass',
  'level_perfect',
  'level_fail',
  'achievement',
};

/// How a character sounds. 1.0 is the device's normal pitch and speed.
class VoiceProfile {
  final double pitch;
  final double rate;

  /// Characters in the same group share recorded clips (e.g. "boy", "girl").
  final String? group;
  const VoiceProfile({this.pitch = 1.0, this.rate = 1.0, this.group});

  factory VoiceProfile.fromJson(Map<String, dynamic>? j) => VoiceProfile(
    pitch: (j?['pitch'] as num?)?.toDouble() ?? 1.0,
    rate: (j?['rate'] as num?)?.toDouble() ?? 1.0,
    group: j?['group'] as String?,
  );
}

/// One character, from `assets/config/characters.json`.
class CharacterDef {
  final String id;
  final String name;
  final String kind;
  final String emoji;
  final Color color;
  final bool active;
  final String role;
  final VoiceProfile voice;
  final String signature;

  /// A child trainer the player can pick.
  final bool trainer;

  /// Full-body picture and round face picture (asset paths), if the character has art.
  final String? image;
  final String? face;

  /// Which recorded clips this character uses: its voice group, or its own id.
  String get voiceKey => voice.group ?? id;

  const CharacterDef({
    required this.id,
    required this.name,
    this.kind = '',
    required this.emoji,
    this.color = const Color(0xFF888888),
    this.active = true,
    this.role = '',
    this.voice = const VoiceProfile(),
    this.signature = '',
    this.trainer = false,
    this.image,
    this.face,
  });

  factory CharacterDef.fromJson(Map<String, dynamic> j) => CharacterDef(
    id: j['id'] as String,
    name: j['name'] as String,
    kind: j['kind'] as String? ?? '',
    emoji: j['emoji'] as String,
    color: Color(
      int.parse((j['color'] as String? ?? '#888888').substring(1), radix: 16) | 0xFF000000,
    ),
    active: j['active'] as bool? ?? true,
    role: j['role'] as String? ?? '',
    voice: VoiceProfile.fromJson(j['voice'] as Map<String, dynamic>?),
    signature: j['signature'] as String? ?? '',
    trainer: j['trainer'] as bool? ?? false,
    image: j['image'] as String?,
    face: j['face'] as String?,
  );
}

/// Who speaks for one event, and the lines to pick from.
class DialogueEvent {
  final String speaker;
  final List<String> lines;
  const DialogueEvent(this.speaker, this.lines);
}

/// The characters, what they say, and any recorded clips.
class Cast {
  final Map<String, CharacterDef> characters;
  final Map<String, DialogueEvent> events;

  /// Exact sentence -> audio file in assets/voice/.
  final Map<String, String> clips;
  final List<String> errors;

  const Cast({
    required this.characters,
    required this.events,
    this.clips = const {},
    this.errors = const [],
  });

  /// A tiny built-in cast, used by tests and when the files are missing.
  static const fallback = Cast(
    characters: {'tuki': CharacterDef(id: 'tuki', name: 'টুকি', emoji: '🦊')},
    events: {},
  );

  /// Speaker name in dialogue.json meaning "the trainer this player picked".
  static const trainerSpeaker = 'trainer';

  /// The children a player can pick as their trainer, in file order.
  List<CharacterDef> get trainers => [
    for (final c in characters.values)
      if (c.trainer && c.active) c,
  ];

  /// The player's trainer, or the first trainer when they have not picked one.
  CharacterDef trainer(String? id) {
    final t = trainers;
    return characters[id] ?? (t.isNotEmpty ? t.first : characters.values.first);
  }

  /// Who says [event]. [trainerId] is the player's chosen trainer.
  CharacterDef speaker(String event, [String? trainerId]) {
    final s = events[event]?.speaker;
    if (s == trainerSpeaker) return trainer(trainerId);
    return characters[s] ?? trainer(trainerId);
  }

  static Future<Cast> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    try {
      String? clips;
      try {
        clips = await b.loadString(clipsFile);
      } catch (_) {}
      return parse(
        charactersJson: await b.loadString(charactersFile),
        dialogueJson: await b.loadString(dialogueFile),
        clipsJson: clips,
      );
    } catch (e) {
      return Cast(
        characters: fallback.characters,
        events: const {},
        errors: ['characters/dialogue: cannot read ($e)'],
      );
    }
  }

  static Cast parse({
    required String charactersJson,
    required String dialogueJson,
    String? clipsJson,
  }) {
    final errors = <String>[];
    final characters = <String, CharacterDef>{};
    for (final j in jsonDecode(charactersJson)['characters'] as List) {
      try {
        final c = CharacterDef.fromJson(j as Map<String, dynamic>);
        characters[c.id] = c;
      } catch (e) {
        errors.add('characters.json: cannot read an entry ($e)');
      }
    }
    if (characters.isEmpty) characters.addAll(fallback.characters);

    final events = <String, DialogueEvent>{};
    final raw = jsonDecode(dialogueJson)['events'] as Map<String, dynamic>;
    for (final MapEntry(key: name, value: v) in raw.entries) {
      if (name.startsWith('_')) continue;
      final String speaker;
      final List<String> lines;
      try {
        final j = v as Map<String, dynamic>;
        speaker = j['speaker'] as String? ?? '';
        lines = [for (final l in j['lines'] as List? ?? const []) l as String];
      } catch (e) {
        errors.add('dialogue.json: cannot read "$name" ($e)');
        continue;
      }
      if (!dialogueEvents.contains(name)) {
        errors.add('dialogue.json: unknown event "$name" (known: ${dialogueEvents.join(", ")})');
      } else if (speaker != trainerSpeaker && !characters.containsKey(speaker)) {
        errors.add('dialogue.json: "$name" names unknown speaker "$speaker"');
      } else if (lines.isEmpty && name != 'question') {
        errors.add('dialogue.json: "$name" has no lines');
      } else {
        events[name] = DialogueEvent(speaker, lines);
      }
    }

    final clips = <String, String>{};
    if (clipsJson != null) {
      final m = jsonDecode(clipsJson)['clips'] as Map<String, dynamic>? ?? const {};
      for (final e in m.entries) {
        clips[e.key] = e.value as String;
      }
    }
    return Cast(characters: characters, events: events, clips: clips, errors: errors);
  }
}
