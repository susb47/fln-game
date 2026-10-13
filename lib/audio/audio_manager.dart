import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/cast.dart';
import 'audio_settings.dart';

/// Short sound effects in assets/sfx/.
enum Sfx { tap, correct, wrong, star, levelUp, tryAgain }

String _sfxFile(Sfx s) => switch (s) {
  Sfx.tap => 'sfx/tap.wav',
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

/// Speaks text in a character's voice.
abstract class VoiceBackend {
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
/// whatever is still playing. A sentence with a recorded clip in
/// assets/voice/clips.json plays that clip; anything else uses the device's
/// Bangla text-to-speech.
class AudioManager extends ChangeNotifier {
  final AudioSettings settings;
  final VoiceBackend? _voice;
  final SoundBackend? _sound;
  Map<String, String> clips;

  AudioManager({
    required this.settings,
    VoiceBackend? voice,
    SoundBackend? sound,
    this.clips = const {},
  }) : _voice = voice,
       _sound = sound;

  /// Real device audio.
  factory AudioManager.device(AudioSettings settings, {Map<String, String> clips = const {}}) =>
      AudioManager(settings: settings, voice: TtsVoice(), sound: PlayerSound(), clips: clips);

  /// Makes no sound but still keeps captions. For tests.
  factory AudioManager.silent([AudioSettings? settings]) =>
      AudioManager(settings: settings ?? AudioSettings.memory());

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
      if (settings.voiceOn) await _speak(line);
    }
  }

  /// Says the last lines again (the replay button).
  Future<void> replay() => say(_last);

  void sfx(Sfx s) {
    if (!settings.sfxOn || _sound == null) return;
    unawaited(_guard(_sound.effect(_sfxFile(s), settings.volume)));
  }

  Future<void> stop() async {
    _turn++;
    await _stopVoice();
  }

  Future<void> _speak(Line line) async {
    final clip = clips[line.text];
    final job = clip != null && _sound != null
        ? _sound.clip('voice/$clip', settings.volume)
        : _voice?.speak(line.text, line.speaker.voice, settings.volume);
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
class TtsVoice implements VoiceBackend {
  final _tts = FlutterTts();
  Future<bool>? _ready;

  Future<bool> _init() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      for (final lang in ['bn-BD', 'bn-IN', 'bn']) {
        bool ok;
        try {
          final r = await _tts.isLanguageAvailable(lang);
          ok = r == true || r == 1;
        } catch (_) {
          ok = lang == 'bn-BD'; // Platform cannot tell us: just try it.
        }
        if (ok) {
          await _tts.setLanguage(lang);
          break;
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('tts: not available ($e)');
      return false;
    }
  }

  /// Android takes 0.5 as normal speed; web and Windows take 1.0.
  double _rate(double r) {
    final normal = kIsWeb || defaultTargetPlatform == TargetPlatform.windows ? 1.0 : 0.5;
    return (normal * r).clamp(0.1, 2.0);
  }

  @override
  Future<void> speak(String text, VoiceProfile voice, double volume) async {
    if (!await (_ready ??= _init())) return;
    await _tts.setPitch(voice.pitch.clamp(0.5, 2.0));
    await _tts.setSpeechRate(_rate(voice.rate));
    await _tts.setVolume(volume);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    if (_ready == null) return;
    await _tts.stop();
  }
}

/// Sound effects and recorded clips through audioplayers.
class PlayerSound implements SoundBackend {
  final _effects = <String, AudioPlayer>{};
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
    final p = _effects.putIfAbsent(
      asset,
      () => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency),
    );
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
