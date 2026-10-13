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

Phone voices always sound robotic, so the game can play pre-made clips instead. See [Voice pack](#voice-pack).

## When the voice is silent

At start-up the app looks for a Bangla voice:
- **Android:** switches to Google's speech engine if it is installed (Samsung and Xiaomi phones default to their own engine, which has no Bangla), then asks for `bn-BD`, `bn-IN` or `bn`.
- **Browser:** picks a voice whose language is Bangla.

If none is found, the map shows an orange strip and the speaker menu shows the steps to fix it. Questions are then shown as captions only, not read with an English voice.

| Where you run it | Bangla voice? | What to do |
|---|---|---|
| Android phone | Yes, with Google's engine | Settings > System > Languages > Text-to-speech output > Google > Install voice data > বাংলা (বাংলাদেশ). Then tap "আবার খোঁজো" in the speaker menu. |
| Chrome on Windows | No | Use Microsoft Edge (`flutter run -d edge`), which has Bangla voices, or test on the phone. |
| Windows app | Usually no | Test on the phone. |

The speaker menu has a "শুনে দেখো" button that makes Tuki speak, so you can check the voice without playing a level.

## Animations

- **Each question:** the prompt drops in, then objects pop in one by one with a soft pop sound (a whoosh starts each new question). Objects being taken away get a red cross and fall back. Pattern tiles drop in one at a time and the "?" pulses. The answers rise up last. Code: `lib/widgets/anim.dart`, used in `lib/widgets/visuals.dart`.
- **Wrong answer:** the button shakes and greys out.
- **Right answer:** the button hops.
- **After every right answer:** confetti bursts and the speaking character pops up in a card with the same words they say (`lib/widgets/celebration.dart`).
- **Right after a mistake:** the line comes from `correct_retry` ("হাল ছাড়োনি, দারুণ!") and the confetti is lighter.
- **Passing a level:** a bigger confetti burst on the result screen, and the stars land one at a time, each with a twinkle.

## Voice pack

Recorded (or AI-made) clips replace text-to-speech. Questions change every time ("৮ যোগ ৫ সমান কত?"), so the game stitches a line together from pieces:
1. the whole line, if it has a clip;
2. otherwise each sentence;
3. otherwise, inside a sentence, the numbers and the words between them: "৮" + "যোগ" + "৫" + "সমান কত?". A number keeps a suffix stuck to it ("৩টি"), because it is said as one word ("তিনটি").

If any piece is missing, the whole line uses text-to-speech, so a child never hears half a recording and half a robot. The code is `lib/audio/voice_pack.dart`.

**The recording script** is `docs/voice_script.csv` (open it in Excel or Google Sheets). It has 950 rows: tuki 349, bindu 299, piku 302. Most are numbers 0 to 200 and tens to 1000, which each character says in hints. Columns:
- `file`: the name to save the recording as, for example `tuki/0123.mp3`.
- `speaker`: who says it.
- `text`: exactly what to say.
- `kind`: `number` or `speech`.
- `used_in`: where the game uses it.

After adding levels or changing `dialogue.json`, run `flutter test tool/voice_script_test.dart`. Existing rows keep their file names and new ones are added at the end. `flutter test` fails with a reminder if the script no longer covers every line.

**With a voice artist:**
1. Give them the CSV. One file per row, mono, MP3 or WAV, a short silence at each end, the same loudness throughout.
2. Numbers are read on their own, in a calm, even voice, so they fit any sentence.
3. Put the files in `assets/voice/` under the names in the `file` column (`assets/voice/tuki/0123.mp3`).
4. Run `python tools/voice_pack.py link`. It writes `assets/voice/clips.json` for every file it finds.

**With Google's AI voices:**
1. In Google Cloud, turn on the Text-to-Speech API and make an API key.
2. `set GOOGLE_TTS_KEY=your-key` (Windows) or `export GOOGLE_TTS_KEY=your-key`.
3. `python tools/voice_pack.py google`. It makes every missing clip, then links them. Choose voices at the top of the script (Google's Bangla voices are bn-IN).

You can mix the two: record what matters most first (praise, the welcome), and let the rest fall back to text-to-speech or AI clips.

**clips.json keys** are the piece's text, or `speaker|text` for one character only. The tools write `speaker|text`. A hand-written entry such as `"দারুণ!": "darun.mp3"` is used for any speaker without their own clip. Lines with `{name}` always use text-to-speech, since names cannot be recorded.

## Sound settings

The speaker button on the map, placement and play screens opens the settings. They are saved on the device, not per child:
- কথা বলা: voice on or off.
- খেলার শব্দ: sound effects on or off.
- কথাগুলো লেখায় দেখাও: captions on or off.
- A volume slider.

The sound effects are in `assets/sfx/`. They are made by `tools/make_sfx.py` (needs numpy), so there are no licences to track: tap, pop, whoosh, hello, correct, wrong, star, level_up and try_again. Tweak a recipe and run it again, or replace any file with one of the same name.

## Code

- `lib/audio/voice_pack.dart`: splits a line into pieces and finds a clip for each.
- `lib/audio/audio_manager.dart`: plays lines one at a time and never overlapping. It plays the voice pack's clips or text-to-speech for each line, plays effects, handles replay, and holds the current caption.
- `lib/audio/coach.dart`: the dialogue controller. Screens call `coach.correct()`, `coach.wrong(q, tries)` and so on, and it picks the speaker and line.
- `lib/audio/audio_settings.dart`: the saved sound settings.
- `lib/data/cast.dart`: loads and checks characters.json, dialogue.json and clips.json.
- `lib/widgets/sound_widgets.dart`: the caption bubble, the character face, the speaker button and the settings sheet.

The research event logging from the V2 plan (which hint was shown and what happened next) is not built yet.
