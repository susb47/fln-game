import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound choices for this device: voice, sound effects, captions and volume.
class AudioSettings extends ChangeNotifier {
  static const _key = 'audio_v1';

  bool _voiceOn;
  bool _sfxOn;
  bool _captionsOn;
  double _volume;
  final SharedPreferences? _prefs;

  AudioSettings._(
    this._prefs, {
    bool voiceOn = true,
    bool sfxOn = true,
    bool captionsOn = true,
    double volume = 1.0,
  }) : _voiceOn = voiceOn,
       _sfxOn = sfxOn,
       _captionsOn = captionsOn,
       _volume = volume;

  /// Not saved anywhere. For tests.
  AudioSettings.memory({bool voiceOn = true, bool sfxOn = true, bool captionsOn = true})
    : this._(null, voiceOn: voiceOn, sfxOn: sfxOn, captionsOn: captionsOn);

  static Future<AudioSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final j = jsonDecode(prefs.getString(_key) ?? '{}') as Map<String, dynamic>;
      return AudioSettings._(
        prefs,
        voiceOn: j['voice'] as bool? ?? true,
        sfxOn: j['sfx'] as bool? ?? true,
        captionsOn: j['captions'] as bool? ?? true,
        volume: (j['volume'] as num?)?.toDouble() ?? 1.0,
      );
    } catch (_) {
      return AudioSettings._(prefs);
    }
  }

  bool get voiceOn => _voiceOn;
  bool get sfxOn => _sfxOn;
  bool get captionsOn => _captionsOn;
  double get volume => _volume;

  /// True when both voice and sound effects are off.
  bool get muted => !_voiceOn && !_sfxOn;

  set voiceOn(bool v) => _set(() => _voiceOn = v);
  set sfxOn(bool v) => _set(() => _sfxOn = v);
  set captionsOn(bool v) => _set(() => _captionsOn = v);
  set volume(double v) => _set(() => _volume = v.clamp(0.0, 1.0));

  void _set(void Function() change) {
    change();
    notifyListeners();
    _prefs?.setString(
      _key,
      jsonEncode({'voice': _voiceOn, 'sfx': _sfxOn, 'captions': _captionsOn, 'volume': _volume}),
    );
  }
}
