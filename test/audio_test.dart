import 'dart:io';
import 'dart:math';

import 'package:fln_game/audio/audio_manager.dart';
import 'package:fln_game/audio/audio_settings.dart';
import 'package:fln_game/audio/coach.dart';
import 'package:fln_game/audio/voice_pack.dart';
import 'package:fln_game/data/cast.dart';
import 'package:fln_game/logic/progression.dart';
import 'package:fln_game/logic/puzzle_factory.dart';
import 'package:fln_game/logic/question.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

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
  String detail = 'fake';
  @override
  Future<VoiceState> check({bool again = false}) async => VoiceState.ready;
  @override
  Future<void> speak(String text, VoiceProfile voice, double volume) async => said.add(text);
  @override
  Future<void> stop() async => stops++;
}

class NoBanglaVoice extends FakeVoice {
  @override
  Future<VoiceState> check({bool again = false}) async => VoiceState.noBangla;
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

  test('voice pack: splits sentences, numbers and words', () {
    expect(VoicePack.sentences('চলো আবার দেখি। ৫ থেকে আরও ৩ গুনে সামনে যাও।'), [
      'চলো আবার দেখি।',
      '৫ থেকে আরও ৩ গুনে সামনে যাও।',
    ]);
    expect(VoicePack.pieces('৮ যোগ ৫ সমান কত?'), ['৮', 'যোগ', '৫', 'সমান কত?']);
    expect(VoicePack.pieces('কোন দলে ৩টি আছে?'), ['কোন দলে', '৩টি', 'আছে?']);
    expect(VoicePack.pieces('২, ৪, ৬, ৮, তারপর কত?'), ['২', '৪', '৬', '৮', 'তারপর কত?']);
  });

  test('voice pack: a question is stitched from clips, a gap falls back to TTS', () async {
    final voice = FakeVoice(), sound = FakeSound();
    final audio = AudioManager(
      settings: AudioSettings.memory(),
      voice: voice,
      sound: sound,
      clips: {
        'tuki|৮': 'tuki/8.mp3',
        '৫': 'shared/5.mp3',
        'tuki|যোগ': 'tuki/jog.mp3',
        'tuki|সমান কত?': 'tuki/soman.mp3',
      },
    );
    final cast = loadCast();
    final tuki = cast.characters['tuki']!, piku = cast.characters['piku']!;
    await audio.say([Line(tuki, '৮ যোগ ৫ সমান কত?')]);
    expect(sound.played, [
      'voice/tuki/8.mp3',
      'voice/tuki/jog.mp3',
      'voice/shared/5.mp3',
      'voice/tuki/soman.mp3',
    ]);
    expect(voice.said, isEmpty);
    // Piku has no "৮" of his own and there is no shared one: all of it is TTS.
    await audio.say([Line(piku, '৮ যোগ ৫ সমান কত?')]);
    expect(voice.said, ['৮ যোগ ৫ সমান কত?']);
  });

  test('the recording script covers every line the game says', () {
    final csv = File('docs/voice_script.csv');
    final have = {
      for (final line in csv.readAsLinesSync().skip(1))
        if (line.isNotEmpty) line.split(',')[0]: line,
    };
    final clips = <String, String>{};
    for (final row in have.values) {
      // file,speaker,text,... where text may be quoted and contain commas.
      final m = RegExp(r'^([^,]+),([^,]+),("(?:[^"]|"")*"|[^,]*),').firstMatch(row)!;
      var text = m.group(3)!;
      if (text.startsWith('"')) text = text.substring(1, text.length - 1).replaceAll('""', '"');
      clips['${m.group(2)}|$text'] = m.group(1)!;
    }
    final pack = VoicePack(clips);
    final cast = loadCast();
    final factory = PuzzleFactory(Random(5));
    final missing = <String>{};
    for (final level in loadContent().allLevels) {
      for (var i = 0; i < 30; i++) {
        final q = factory.forLevel(level);
        if (pack.plan('tuki', q.spoken) == null) missing.add(q.spoken);
        for (final who in ['bindu', 'piku']) {
          if (pack.plan(who, q.hint) == null) missing.add('$who: ${q.hint}');
        }
      }
    }
    for (final e in cast.events.values) {
      for (final l in e.lines.where((l) => !l.contains('{'))) {
        if (pack.plan(e.speaker, l) == null) missing.add('${e.speaker}: $l');
      }
    }
    expect(missing, isEmpty, reason: 'Run: flutter test tool/voice_script_test.dart');
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

  test('voice check reports a missing Bangla voice', () async {
    final audio = AudioManager(settings: AudioSettings.memory(), voice: NoBanglaVoice());
    expect(audio.voiceState, VoiceState.unknown);
    expect(await audio.checkVoice(), VoiceState.noBangla);
    expect(AudioManager.silent().voiceState, VoiceState.unknown);
    expect(await AudioManager.silent().checkVoice(), VoiceState.unavailable);
  });

  test('a right answer after a mistake gets the keep-going praise', () {
    final cast = loadCast();
    final coach = Coach(cast, AudioManager.silent(), Random(2));
    final line = coach.correct(afterRetry: true)!;
    expect(cast.events['correct_retry']!.lines, contains(line.text));
    expect(cast.events['correct']!.lines, contains(coach.correct()!.text));
  });
}
