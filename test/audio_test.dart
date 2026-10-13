import 'dart:io';
import 'dart:math';

import 'package:fln_game/audio/audio_manager.dart';
import 'package:fln_game/audio/audio_settings.dart';
import 'package:fln_game/audio/coach.dart';
import 'package:fln_game/data/cast.dart';
import 'package:fln_game/logic/progression.dart';
import 'package:fln_game/logic/question.dart';
import 'package:flutter_test/flutter_test.dart';

Cast loadCast() => Cast.parse(
  charactersJson: File(charactersFile).readAsStringSync(),
  dialogueJson: File(dialogueFile).readAsStringSync(),
  clipsJson: File(clipsFile).readAsStringSync(),
);

/// Records what would have been spoken or played.
class FakeVoice implements VoiceBackend {
  final said = <String>[];
  int stops = 0;
  @override
  Future<void> speak(String text, VoiceProfile voice, double volume) async => said.add(text);
  @override
  Future<void> stop() async => stops++;
}

class FakeSound implements SoundBackend {
  final played = <String>[];
  @override
  Future<void> effect(String asset, double volume) async => played.add(asset);
  @override
  Future<void> clip(String asset, double volume) async => played.add(asset);
  @override
  Future<void> stop() async {}
}

const q = Question(
  prompt: 'যোগ করো',
  speech: '২ যোগ ৩ সমান কত?',
  visuals: [],
  options: [],
  correctIndex: 0,
  hint: '২ থেকে আরও ৩ গুনে সামনে যাও।',
);

void main() {
  test('character and dialogue files load without errors', () {
    final cast = loadCast();
    expect(cast.errors, isEmpty, reason: cast.errors.join('\n'));
    expect(cast.characters.keys, containsAll(['tuki', 'bindu', 'piku', 'jhilimili', 'gubu']));
    for (final e in dialogueEvents) {
      expect(cast.events, contains(e), reason: 'dialogue.json has no "$e"');
    }
  });

  test('bad dialogue entries are reported, not fatal', () {
    final cast = Cast.parse(
      charactersJson: File(charactersFile).readAsStringSync(),
      dialogueJson:
          '{"events": {"correct": {"speaker": "nobody", "lines": ["x"]},'
          ' "dance": {"speaker": "tuki", "lines": ["x"]}, "wrong_first": {"speaker": "bindu"}}}',
    );
    expect(cast.errors, hasLength(3));
  });

  test('coach picks the right speaker and fills in the hint', () async {
    final voice = FakeVoice(), sound = FakeSound();
    final audio = AudioManager(settings: AudioSettings.memory(), voice: voice, sound: sound);
    final coach = Coach(loadCast(), audio, Random(1));

    coach.wrong(q, 1);
    await Future<void>.delayed(Duration.zero);
    expect(audio.caption!.speaker.id, 'bindu');
    expect(audio.caption!.text, endsWith(q.hint));
    expect(sound.played, contains('sfx/wrong.wav'));

    coach.wrong(q, 2);
    await Future<void>.delayed(Duration.zero);
    expect(audio.caption!.speaker.id, 'piku');

    await audio.say([coach.questionLine(q)]);
    expect(voice.said.last, '২ যোগ ৩ সমান কত?');
  });

  test('level end: stars and achievements are spoken in order', () async {
    final voice = FakeVoice();
    final audio = AudioManager(settings: AudioSettings.memory(), voice: voice);
    const r = LevelResult(
      correct: 7,
      total: 8,
      stars: 2,
      newBest: true,
      nextLevel: null,
      suggestEasier: null,
      newAchievements: [],
    );
    Coach(loadCast(), audio).levelEnd(r);
    await Future<void>.delayed(Duration.zero);
    expect(voice.said.single, contains('২টি তারা'));
  });

  test('a recorded clip replaces text-to-speech for that exact sentence', () async {
    final voice = FakeVoice(), sound = FakeSound();
    final audio = AudioManager(
      settings: AudioSettings.memory(),
      voice: voice,
      sound: sound,
      clips: {'দারুণ!': 'tuki_darun.mp3'},
    );
    final tuki = loadCast().characters['tuki']!;
    await audio.say([Line(tuki, 'দারুণ!'), Line(tuki, 'খুব ভালো!')]);
    expect(sound.played, ['voice/tuki_darun.mp3']);
    expect(voice.said, ['খুব ভালো!']);
  });

  test('mute: no speech or effects, but captions still update', () async {
    final voice = FakeVoice(), sound = FakeSound();
    final settings = AudioSettings.memory(voiceOn: false)..sfxOn = false;
    final audio = AudioManager(settings: settings, voice: voice, sound: sound);
    final tuki = loadCast().characters['tuki']!;
    audio.sfx(Sfx.correct);
    await audio.say([Line(tuki, 'দারুণ!')]);
    expect(voice.said, isEmpty);
    expect(sound.played, isEmpty);
    expect(audio.caption!.text, 'দারুণ!');
  });

  test('a new line cuts off the old one, and replay says it again', () async {
    final voice = FakeVoice();
    final audio = AudioManager(settings: AudioSettings.memory(), voice: voice);
    final tuki = loadCast().characters['tuki']!;
    final first = audio.say([Line(tuki, 'এক'), Line(tuki, 'দুই')]);
    final second = audio.say([Line(tuki, 'তিন')]);
    await Future.wait([first, second]);
    expect(voice.said, isNot(contains('দুই')));
    expect(voice.said.last, 'তিন');
    await audio.replay();
    expect(voice.said.last, 'তিন');
  });
}
