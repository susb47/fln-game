# সংখ্যার দ্বীপ (Number Islands), v0.5

Docs: [developer guide](docs/DEVELOPER_GUIDE.md) · [voices and sound](docs/VOICES.md) · [adding levels](docs/LEVELS.md) · [dashboard plan](docs/DASHBOARDS.md)

A puzzle game for Bangladesh primary grades 1 to 3, built from `FLN_Puzzle_Game_Plan.docx`.

## What's in it

- **Sign in by picture**: each child taps their own picture and name. No passwords (they are 6 to 9),
  no internet, everything stays on the phone. **Guest** play works without a profile and is not saved;
  a guest can tap "সেভ করো" to keep their progress as a new profile.
- **Placement check** for each new player (8 quick puzzles, two per island) so they start at their level.
- **Level progression**: each island is a path of levels. Pass a level (75% first-try correct by
  default) to open the next. 1 to 3 stars per level. Failing a level twice suggests the easier one before it.
  Islands open after finishing levels on an earlier island.
- **100 levels**, 25 on each of 4 islands: counting, more/less, add/subtract (including picture take-away), patterns.
- **14 achievements** (first level, star counts, perfect levels, island complete, 3- and 7-day streaks...).
- **Dashboards**: "আমার অগ্রগতি" for the child (📊 on the map) and a teacher/parent dashboard
  (from the sign-in screen, behind a grown-up sum) showing who is stuck on which skill.
  Plan: [docs/DASHBOARDS.md](docs/DASHBOARDS.md).

**Black background fix**: the play and result screens used a see-through background colour, so
whatever was behind them (black) showed through, especially during screen changes. All screens now
use solid colours.

Note: v0.1 progress is not carried over; players start fresh in v0.2.

## Where things live

```
assets/levels/          one JSON file per level  <- add your own levels here (docs/LEVELS.md)
assets/config/          islands.json, achievements.json
lib/main.dart           app start: sign-in -> placement -> island map
lib/data/content.dart   loads and checks islands, levels and achievements
lib/logic/              puzzle_factory (questions), progression (stars, unlocks, achievements),
                        profile + profile_store (saved players), question model
lib/screens/            auth, placement, map, island, play, result, achievements
lib/dashboards/         child_dashboard.dart, teacher_dashboard.dart, dashboard_widgets.dart
lib/widgets/            puzzle visuals, answer buttons, stars, grown-up check
docs/                   DEVELOPER_GUIDE.md, LEVELS.md (how to add levels), DASHBOARDS.md (dashboard plan), brand/
test/                   content checks for every level file, progression rules, full play-through
```

## Run it on Windows 11 with VS Code

Your PC (8 GB RAM) will struggle with the Android emulator, so use **Chrome** while developing and a
**real Android phone** for real testing.

1. Unzip `fln_game` to a short path with no spaces, e.g. `C:\dev\fln_game` (not inside OneDrive).
   If you have v0.1 there, replace the whole folder.
2. In VS Code install the **Flutter** extension, then *File > Open Folder* and pick `C:\dev\fln_game`.
3. In the terminal (`` Ctrl+` ``):
   ```
   flutter pub get
   flutter test
   flutter run -d chrome
   ```
   Press `r` for hot reload after editing code, `R` for a full restart (needed after adding a level file).

### On an Android phone
1. Run `flutter doctor`. If the Android toolchain is missing, install Android Studio once just for the
   Android SDK (skip its emulator), then `flutter doctor --android-licenses`.
2. On the phone: Settings > About phone > tap *Build number* 7 times, then turn on *USB debugging*.
3. Plug in, accept the prompt on the phone, then `flutter run`.
4. To share an installable file: `flutter build apk --release --split-per-abi`, then send
   `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`.

If you still see a black screen anywhere, note which screen and whether it was Chrome or the phone.

## Brand (v0.2.1)
- App icon, company logo and lockup: `docs/brand/` (SVG sources + PNG). Icons are already installed for Android, web and Windows.
- Names live in `lib/brand.dart`. "Dhaap Learning Systems Ltd." is a placeholder: change it there once the company name is final.

## Levels (v0.3)
- 100 levels: 25 on each island (counting, compare, addition, pattern), in `assets/levels/`. Each has a `grade` tag (1-12 → Grade 1, 13-20 → Grade 2, 21-25 → Grade 3, roughly).
- Android build settings: `android/gradle.properties` keeps `kotlin.incremental=false` (always keep this line) and uses a 2 GB Gradle heap to suit an 8 GB machine.

## Voices and sound (v0.4)
- Tuki 🦊 reads questions and cheers, Bindu 🤖 gives the first hint, Professor Piku 🦉 helps after a second mistake. Captions show what is said; tap to hear again.
- Uses the phone's Bangla text-to-speech now; drop recorded clips into `assets/voice/` later. Sound effects, mute, captions and volume in the speaker menu.
- Edit lines in `assets/config/dialogue.json`, characters in `assets/config/characters.json`. Details: [docs/VOICES.md](docs/VOICES.md).
- New packages: `flutter_tts`, `audioplayers`. Run `flutter pub get` after updating.

## v0.4.1
- Voice fix: picks Google's speech engine on Android and a Bangla voice explicitly; shows a fix-it strip and steps when no Bangla voice exists; "শুনে দেখো" test button in the speaker menu.
- Celebration after every right answer (character card + confetti), confetti when a level is passed.

## v0.5
- Every question animates in: the prompt drops in, objects pop in one by one with a soft pop, taken-away objects get crossed out, number patterns drop in tile by tile with a pulsing "?", and the answers rise up last. Wrong answers shake; right answers hop. Result stars land one at a time.
- New sound effects, all made in `tools/make_sfx.py`: tap, pop, whoosh, hello, correct, wrong, star, level up, try again.
- Voice pack: recorded or AI-made clips replace text-to-speech, stitched from sentences, words and numbers. `docs/voice_script.csv` lists all 950 clips to make; `tools/voice_pack.py` links them in or makes them with Google Cloud. Details: [docs/VOICES.md](docs/VOICES.md#voice-pack).
