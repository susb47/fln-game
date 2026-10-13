import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import '../data/cast.dart';
import '../game_scope.dart';

/// A character's round face.
class CharacterFace extends StatelessWidget {
  final CharacterDef character;
  final double size;
  const CharacterFace(this.character, {super.key, this.size = 52});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Color.alphaBlend(character.color.withValues(alpha: 0.25), Colors.white),
      border: Border.all(color: character.color, width: 3),
    ),
    child: Text(character.emoji, style: TextStyle(fontSize: size * 0.55)),
  );
}

/// The speaking character with what they just said. Tap it to hear it again.
///
/// With captions off, only the face and the replay button show.
class CaptionBubble extends StatelessWidget {
  const CaptionBubble({super.key});

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
                CharacterFace(line.speaker),
                const SizedBox(width: 8),
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
    builder: (context) => ListenableBuilder(
      listenable: s,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('শব্দ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
