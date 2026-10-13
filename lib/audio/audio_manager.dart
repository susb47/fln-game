import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/cast.dart';
import 'audio_settings.dart';
import 'voice_pack.dart';

/// Short sound effects in assets/sfx/.
enum Sfx { tap, pop, whoosh, hello, correct, wrong, star, levelUp, tryAgain }

String _sfxFile(Sfx s) => switch (s) {
  Sfx.tap => 'sfx/tap.wav',
  Sfx.pop => 'sfx/pop.wav',
  Sfx.whoosh => 'sfx/whoosh.wav',
  Sfx.hello => 'sfx/hello.wav',
  Sfx.correct => 'sfx/correct.wav',
  Sfx.wrong => 'sfx/wrong.wav',
  Sfx.star => 'sfx/star.wav',
  Sfx.levelUp => 'sfx/level_up.wav',
  Sfx.tryAgain => 'sfx/try_again.wav',
};

/// One thing a character says. Shown as a caption and spoken.
class Line {
  final CharacterDef speaker;
  final String text;
  const Line(this.speaker, this.text);
}

/// Whether the device can speak Bangla.
enum VoiceState {
  /// Not checked yet.
  unknown,

  /// A Bangla voice was found and selected.
  ready,

  /// Text-to-speech works, but this device has no Bangla voice.
  noBangla,

  /// No text-to-speech on this device at all.
  unavailable,
}

/// Speaks text in a character's voice.
abstract class VoiceBackend {
  /// Finds and selects a Bangla voice. Safe to call more than once;
  /// [again] looks again (after the user installs a voice).
  Future<VoiceState> check({bool again = false});

  /// The voice selected by [check], for the settings screen (e.g. "bn-BD").
  String get detail;
  Future<void> speak(String text, VoiceProfile voice, double volume);
  Future<void> stop();
}

/// Plays audio files from assets/.
abstract class SoundBackend {
  Future<void> effect(String asset, double volume);

  /// Plays a recorded voice clip and waits until it ends.
  Future<void> clip(String asset, double volume);
  Future<void> stop();
}

/// The one place the game makes sound.
///
/// Lines play one after another and never overlap: a new [say] cuts off
/// whatever is still playing. A line that the voice pack (assets/voice/
/// clips.json) fully covers plays from recordings, stitched from whole
/// sentences, words and numbers; anything else uses the device's Bangla
/// text-to-speech. See [VoicePack].
class AudioManager extends ChangeNotifier {
  final AudioSettings settings;
  final VoiceBackend? _voice;
  final SoundBackend? _sound;
  final VoicePack pack;

  AudioManager({
    required this.settings,
    VoiceBackend? voice,
    SoundBackend? sound,
    Map<String, String> clips = const {},
  }) : _voice = voice,
       _sound = sound,
       pack = VoicePack(clips);

  /// Real device audio.
  factory AudioManager.device(AudioSettings settings, {Map<String, String> clips = const {}}) =>
      AudioManager(settings: settings, voice: TtsVoice(), sound: PlayerSound(), clips: clips);

  /// Makes no sound but still keeps captions. For tests.
  factory AudioManager.silent([AudioSettings? settings]) =>
      AudioManager(settings: settings ?? AudioSettings.memory());

  /// Whether this device can speak Bangla. Updated by [checkVoice].
  VoiceState voiceState = VoiceState.unknown;
  String get voiceDetail => _voice?.detail ?? '';

  /// Looks for a Bangla voice now, so the settings screen can say if one is missing.
  Future<VoiceState> checkVoice({bool again = false}) async {
    final v = _voice;
    if (again) {
      voiceState = VoiceState.unknown;
      notifyListeners();
    }
    voiceState = v == null ? VoiceState.unavailable : await v.check(again: again);
    notifyListeners();
    return voiceState;
  }

  /// What is being said now, or was said last. Shown as the caption.
  Line? caption;
  List<Line> _last = const [];
  int _turn = 0;

  /// Says [lines] in order, cutting off anything still playing.
  Future<void> say(List<Line> lines) async {
    final turn = ++_turn;
    _last = lines;
    await _stopVoice();
    for (final line in lines) {
      if (turn != _turn) return;
      caption = line;
      notifyListeners();
      if (settings.voiceOn) await _speak(line, turn);
    }
  }

  /// Says the last lines again (the replay button).
  Future<void> replay() => say(_last);

  final _lastSfx = <Sfx, DateTime>{};

  void sfx(Sfx s) {
    if (!settings.sfxOn || _sound == null) return;
    // Many objects popping in at once make one quick run of pops, not a roar.
    final now = DateTime.now();
    final last = _lastSfx[s];
    if (s == Sfx.pop && last != null && now.difference(last).inMilliseconds < 70) return;
    _lastSfx[s] = now;
    final volume = s == Sfx.pop ? settings.volume * 0.6 : settings.volume;
    unawaited(_guard(_sound.effect(_sfxFile(s), volume)));
  }

  Future<void> stop() async {
    _turn++;
    await _stopVoice();
  }

  Future<void> _speak(Line line, int turn) async {
    final files = _sound == null ? null : pack.plan(line.speaker.id, line.text);
    if (files != null) {
      for (final f in files) {
        if (turn != _turn) return;
        // Never let a broken clip hold up the game.
        await _guard(_sound!.clip('voice/$f', settings.volume).timeout(const Duration(seconds: 6)));
      }
      return;
    }
    final job = _voice?.speak(line.text, line.speaker.voice, settings.volume);
    if (job == null) return;
    // Never let a missing voice hold up the game.
    final limit = Duration(milliseconds: 3000 + 150 * line.text.length);
    await _guard(job.timeout(limit));
  }

  Future<void> _stopVoice() async {
    await _guard(_voice?.stop());
    await _guard(_sound?.stop());
  }

  static Future<void> _guard(Future<void>? f) async {
    try {
      await f;
    } catch (e) {
      if (kDebugMode) debugPrint('audio: $e');
    }
  }
}

/// Device text-to-speech, Bangla first.
///
/// Many phones sold in Bangladesh ship their own speech engine (Samsung, Xiaomi)
/// with no Bangla voice, so on Android this switches to Google's engine when
/// it is installed. Without a Bangla voice the game stays silent rather than
/// reading Bangla letters with an English voice; captions still show.
class TtsVoice implements VoiceBackend {
  static const _google = 'com.google.android.tts';
  static const _langs = ['bn-BD', 'bn-IN', 'bn'];

  final _tts = FlutterTts();
  Future<VoiceState>? _checked;
  VoiceState _state = VoiceState.unknown;
  @override
  String detail = '';

  @override
  Future<VoiceState> check({bool again = false}) {
    if (again) _checked = null;
    return _checked ??= _check();
  }

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<VoiceState> _check() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      if (_android) await _useGoogleEngine();
      final found = kIsWeb ? await _pickWebVoice() : await _pickLanguage();
      _state = found ? VoiceState.ready : VoiceState.noBangla;
    } catch (e) {
      if (kDebugMode) debugPrint('tts: not available ($e)');
      _state = VoiceState.unavailable;
    }
    if (kDebugMode) debugPrint('tts: $_state $detail');
    return _state;
  }

  Future<void> _useGoogleEngine() async {
    try {
      final engines = [for (final e in (await _tts.getEngines as List? ?? const [])) '$e'];
      final current = '${await _tts.getDefaultEngine}';
      if (engines.contains(_google) && current != _google) {
        await _tts.setEngine(_google);
        detail = _google;
      }
    } catch (_) {
      // Keep the default engine.
    }
  }

  /// Android, Windows: ask the engine for each Bangla locale in turn.
  Future<bool> _pickLanguage() async {
    for (final lang in _langs) {
      final r = await _tts.setLanguage(lang);
      if (r == 1 || r == true) {
        detail = [lang, if (detail.isNotEmpty) detail].join(' · ');
        return true;
      }
    }
    return false;
  }

  /// Web: pick a voice whose locale is Bangla. Browsers load voices late,
  /// so ask a few times.
  Future<bool> _pickWebVoice() async {
    for (var attempt = 0; attempt < 6; attempt++) {
      final voices = [
        for (final v in (await _tts.getVoices as List? ?? const []))
          if (v is Map) {for (final e in v.entries) '${e.key}': '${e.value}'},
      ];
      if (voices.isNotEmpty) {
        Map<String, String>? best;
        for (final lang in _langs) {
          for (final v in voices) {
            final locale = (v['locale'] ?? '').replaceAll('_', '-');
            if (best == null && locale.toLowerCase().startsWith(lang.toLowerCase())) best = v;
          }
        }
        if (best == null) return false;
        await _tts.setVoice({'name': best['name']!, 'locale': best['locale']!});
        detail = '${best['name']} (${best['locale']})';
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// Android takes 0.5 as normal speed; web and Windows take 1.0.
  double _rate(double r) {
    final normal = kIsWeb || defaultTargetPlatform == TargetPlatform.windows ? 1.0 : 0.5;
    return (normal * r).clamp(0.1, 2.0);
  }

  @override
  Future<void> speak(String text, VoiceProfile voice, double volume) async {
    if (await check() != VoiceState.ready) return;
    await _tts.setPitch(voice.pitch.clamp(0.5, 2.0));
    await _tts.setSpeechRate(_rate(voice.rate));
    await _tts.setVolume(volume);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    if (_checked == null) return;
    await _tts.stop();
  }
}

/// Sound effects and recorded clips through audioplayers.
class PlayerSound implements SoundBackend {
  // Three players per effect, used in turn, so quick repeats overlap instead
  // of cutting each other off.
  final _effects = <String, List<AudioPlayer>>{};
  final _next = <String, int>{};
  final _clip = AudioPlayer();
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    // Effects mix with speech instead of pausing it.
    await AudioPlayer.global.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );
  }

  @override
  Future<void> effect(String asset, double volume) async {
    await _configure();
    final pool = _effects.putIfAbsent(
      asset,
      () => List.generate(3, (_) => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency)),
    );
    final i = _next[asset] = ((_next[asset] ?? -1) + 1) % pool.length;
    final p = pool[i];
    await p.stop();
    await p.play(AssetSource(asset), volume: volume);
  }

  @override
  Future<void> clip(String asset, double volume) async {
    await _configure();
    final done = _clip.onPlayerComplete.first;
    await _clip.play(AssetSource(asset), volume: volume);
    await done;
  }

  @override
  Future<void> stop() => _clip.stop();
}
