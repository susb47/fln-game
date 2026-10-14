import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import '../data/cast.dart';
import '../game_scope.dart';

/// A character's round face: their picture, or their emoji when they have none.
class CharacterFace extends StatelessWidget {
  final CharacterDef character;
  final double size;
  const CharacterFace(this.character, {super.key, this.size = 52});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Color.alphaBlend(character.color.withValues(alpha: 0.25), Colors.white),
      border: Border.all(color: character.color, width: 3),
    ),
    child: character.face != null
        ? Image.asset(character.face!, fit: BoxFit.cover, width: size, height: size)
        : Text(character.emoji, style: TextStyle(fontSize: size * 0.55)),
  );
}

/// A character standing, full body. Falls back to the round face.
class CharacterFigure extends StatelessWidget {
  final CharacterDef character;
  final double height;
  const CharacterFigure(this.character, {super.key, this.height = 140});

  @override
  Widget build(BuildContext context) => character.image != null
      ? Image.asset(character.image!, height: height, fit: BoxFit.contain)
      : CharacterFace(character, size: height * 0.7);
}

/// The speaking character with what they just said. Tap it to hear it again.
///
/// With captions off, only the face and the replay button show.
class CaptionBubble extends StatelessWidget {
  /// Off when the speaker's picture is already shown next to the bubble.
  final bool showFace;
  const CaptionBubble({super.key, this.showFace = true});

  @override
  Widget build(BuildContext context) {
    final audio = GameScope.of(context).audio;
    return ListenableBuilder(
      listenable: Listenable.merge([audio, audio.settings]),
      builder: (context, _) {
        final line = audio.caption;
        if (line == null) return const SizedBox(height: 56);
        final showText = audio.settings.captionsOn;
        return Semantics(
          button: true,
          label: 'আবার শোনো: ${line.text}',
          child: GestureDetector(
            key: const ValueKey('caption'),
            onTap: audio.replay,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showFace) ...[CharacterFace(line.speaker), const SizedBox(width: 8)],
                if (showText)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: line.speaker.color, width: 2),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${line.speaker.name}: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: line.speaker.color,
                              ),
                            ),
                            TextSpan(text: line.text),
                          ],
                        ),
                        style: const TextStyle(fontSize: 17, color: Colors.black87),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                IconButton(
                  key: const ValueKey('replay_voice'),
                  tooltip: 'আবার শোনো',
                  onPressed: audio.replay,
                  icon: const Icon(Icons.replay_circle_filled, size: 36),
                  color: line.speaker.color,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// App-bar button: speaker icon that opens the sound settings.
class SoundButton extends StatelessWidget {
  const SoundButton({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = GameScope.of(context).audio;
    return ListenableBuilder(
      listenable: audio.settings,
      builder: (context, _) => IconButton(
        key: const ValueKey('sound_settings'),
        tooltip: 'শব্দ',
        icon: Icon(audio.settings.muted ? Icons.volume_off : Icons.volume_up),
        onPressed: () => showSoundSettings(context),
      ),
    );
  }
}

Future<void> showSoundSettings(BuildContext context) {
  final audio = GameScope.of(context).audio;
  final s = audio.settings;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    builder: (context) => ListenableBuilder(
      listenable: s,
      builder: (context, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('শব্দ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const VoiceStatusCard(),
              SwitchListTile(
                key: const ValueKey('voice_switch'),
                title: const Text('কথা বলা'),
                subtitle: const Text('চরিত্ররা প্রশ্ন আর উৎসাহের কথা পড়ে শোনায়'),
                value: s.voiceOn,
                onChanged: (v) {
                  s.voiceOn = v;
                  if (!v) audio.stop();
                },
              ),
              SwitchListTile(
                key: const ValueKey('sfx_switch'),
                title: const Text('খেলার শব্দ'),
                value: s.sfxOn,
                onChanged: (v) => s.sfxOn = v,
              ),
              SwitchListTile(
                key: const ValueKey('captions_switch'),
                title: const Text('কথাগুলো লেখায় দেখাও'),
                value: s.captionsOn,
                onChanged: (v) => s.captionsOn = v,
              ),
              Row(
                children: [
                  const Icon(Icons.volume_down),
                  Expanded(
                    child: Slider(
                      value: s.volume,
                      onChanged: (v) => s.volume = v,
                      onChangeEnd: (_) => audio.sfx(Sfx.tap),
                    ),
                  ),
                  const Icon(Icons.volume_up),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Says whether a Bangla voice was found, with a test button and how to fix it.
class VoiceStatusCard extends StatelessWidget {
  const VoiceStatusCard({super.key});

  static String fixSteps() {
    if (kIsWeb) {
      return 'Chrome-এ বাংলা কণ্ঠ থাকে না। Microsoft Edge-এ খোলো '
          '(flutter run -d edge) অথবা Android ফোনে চালাও।';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ফোনের Settings > System > Languages > Text-to-speech output > '
          'Google Speech Services বেছে নাও > Install voice data > বাংলা (বাংলাদেশ) ডাউনলোড করো। '
          'Google Speech Services না থাকলে Play Store থেকে "Speech Services by Google" ইনস্টল করো। '
          'তারপর নিচের "আবার খোঁজো" ছোঁও।';
    }
    return 'এই কম্পিউটারে বাংলা কণ্ঠ নেই। Android ফোনে বা Microsoft Edge-এ চালাও।';
  }

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final audio = scope.audio;
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final state = audio.voiceState;
        final ok = state == VoiceState.ready;
        final checking = state == VoiceState.unknown;
        final color = ok ? Colors.green.shade700 : (checking ? Colors.blueGrey : Colors.deepOrange);
        return Container(
          key: const ValueKey('voice_status'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color.alphaBlend(color.withValues(alpha: 0.08), Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    ok
                        ? Icons.check_circle
                        : (checking ? Icons.hourglass_top : Icons.warning_amber),
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(switch (state) {
                      VoiceState.ready => 'বাংলা কণ্ঠ চালু আছে',
                      VoiceState.unknown => 'বাংলা কণ্ঠ খোঁজা হচ্ছে…',
                      VoiceState.noBangla => 'এই যন্ত্রে বাংলা কণ্ঠ পাওয়া যায়নি',
                      VoiceState.unavailable => 'এই যন্ত্রে লেখা পড়ে শোনানোর ব্যবস্থা নেই',
                    }, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
                  ),
                ],
              ),
              if (ok && audio.voiceDetail.isNotEmpty)
                Text(
                  audio.voiceDetail,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              if (!ok && !checking) ...[
                const SizedBox(height: 6),
                Text(fixSteps(), style: const TextStyle(fontSize: 14)),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (ok)
                    FilledButton.icon(
                      key: const ValueKey('voice_test'),
                      onPressed: () {
                        final t = scope.coach.trainer;
                        audio.say([Line(t, 'আমি ${t.name}। ${t.signature}')]);
                      },
                      icon: const Icon(Icons.record_voice_over),
                      label: const Text('শুনে দেখো'),
                    ),
                  if (!checking)
                    OutlinedButton.icon(
                      key: const ValueKey('voice_recheck'),
                      onPressed: () => audio.checkVoice(again: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('আবার খোঁজো'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A strip on the map when voice is on but no Bangla voice was found.
class MissingVoiceBanner extends StatelessWidget {
  const MissingVoiceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = GameScope.of(context).audio;
    return ListenableBuilder(
      listenable: Listenable.merge([audio, audio.settings]),
      builder: (context, _) {
        final missing =
            audio.voiceState == VoiceState.noBangla || audio.voiceState == VoiceState.unavailable;
        if (!missing || !audio.settings.voiceOn) return const SizedBox.shrink();
        return Material(
          color: const Color(0xFFFFD8B0),
          child: InkWell(
            key: const ValueKey('missing_voice'),
            onTap: () => showSoundSettings(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.volume_off, color: Colors.deepOrange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'বাংলা কণ্ঠ পাওয়া যায়নি, তাই প্রশ্ন পড়ে শোনানো যাচ্ছে না। ঠিক করতে এখানে ছোঁও।',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
