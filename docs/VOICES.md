# Voices, characters and sound

The game talks. A character reads each question, cheers a right answer, gives a hint after a wrong one, and sums up each level. Everything said also shows as a caption, and the child can tap it to hear it again.

## Who speaks when

| Moment | Speaker | Event in `dialogue.json` |
|---|---|---|
| Map opens after sign-in | Tuki 🦊 | `welcome` |
| Placement check starts | Tuki | `placement_start` |
| Level starts | Tuki | `level_start`, then the first question |
| Each question | Tuki | `question` (reads the question itself) |
| Right answer | Tuki | `correct` (+ chime) |
| First wrong answer | Bindu 🤖 | `wrong_first` + the question's hint |
| Second wrong answer | Professor Piku 🦉 | `wrong_again` + the hint |
| Level passed | Tuki | `level_pass` or `level_perfect` (+ fanfare) |
| Level not passed | Piku | `level_fail` |
| New achievement | Tuki | `achievement` |

Jhilimili 🐰 and Gubu 🐘 are in `characters.json` with `"active": false`. They are ready for the later modes (Help the Village and so on).

## Changing what they say

Edit `assets/config/dialogue.json`. No code changes are needed.
- Each event has a `speaker` (a character `id`) and `lines`. The game picks one line at random.
- `{hint}`, `{stars}`, `{title}` and `{name}` are filled in by the game.
- Keep lines to one short sentence. Never shame the child, and never use countdowns.
- After editing, run `flutter test`. `audio_test.dart` checks that every event exists and names a real character.

To give a character a different speaker, or to change its voice, edit `assets/config/characters.json`:
- `voice.pitch` sets the pitch. 1.0 is normal; higher sounds younger.
- `voice.rate` sets the speed. 1.0 is normal; Piku is slower at 0.85.

## Text-to-speech now, recorded voice later

**Today:** the app uses the device's own Bangla text-to-speech (`flutter_tts`), trying `bn-BD` first, then `bn-IN`.

**Android:** Google's speech engine needs its Bangla voice. If the phone stays silent or speaks English, set it up once:
1. Open Settings > System > Languages > Text-to-speech output.
2. Choose Google's engine.
3. Under Install voice data, download বাংলা (Bangladesh).

**Chrome:** Bangla voices depend on the computer. On Windows there is often no Bangla voice, so test speech on the phone.

**Recording real voices.** No code changes are needed:
1. Record the sentence exactly as written in `dialogue.json`. MP3 or WAV, mono, short silence at the ends.
2. Put the file in `assets/voice/`, for example `assets/voice/tuki_darun.mp3`.
3. Add a line to `assets/voice/clips.json`: `"দারুণ!": "tuki_darun.mp3"`.

The game then plays the recording for that sentence and still uses text-to-speech for everything else. Questions with numbers (for example "৮ বিয়োগ ৫ সমান কত?") change every time, so they stay on text-to-speech.

## Sound settings

The speaker button on the map, placement and play screens opens the settings. They are saved on the device, not per child:
- কথা বলা: voice on or off.
- খেলার শব্দ: sound effects on or off.
- কথাগুলো লেখায় দেখাও: captions on or off.
- A volume slider.

The sound effects are in `assets/sfx/` and were made for this project, so there are no licences to track: tap, correct, wrong, star, level_up and try_again. Replace any of them with a file of the same name.

## Code

- `lib/audio/audio_manager.dart`: plays lines one at a time and never overlapping. It picks a recorded clip or text-to-speech for each line, plays effects, handles replay, and holds the current caption.
- `lib/audio/coach.dart`: the dialogue controller. Screens call `coach.correct()`, `coach.wrong(q, tries)` and so on, and it picks the speaker and line.
- `lib/audio/audio_settings.dart`: the saved sound settings.
- `lib/data/cast.dart`: loads and checks characters.json, dialogue.json and clips.json.
- `lib/widgets/sound_widgets.dart`: the caption bubble, the character face, the speaker button and the settings sheet.

The research event logging from the V2 plan (which hint was shown and what happened next) is not built yet.
