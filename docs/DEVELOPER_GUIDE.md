# Developer guide: সংখ্যার দ্বীপ (v0.6)

This guide is for anyone working on the code. For the project status, open decisions and next steps,
see the handover document. For adding levels without touching code, see [LEVELS.md](LEVELS.md).

## 1. What the app is

The app is an offline maths puzzle game for Bangladesh Grades 1 to 3, written in Flutter.
- Children sign in by picture and get a placement check.
- They then play level paths on 4 islands (25 levels each) and earn stars and achievements.
- Teachers and parents see progress on a dashboard behind a grown-up sum.
- Everything is saved on the device. There is no server.

| | |
|---|---|
| Flutter | 3.32 or newer (`sdk: ^3.8.0`), built and tested with Flutter 3.47.7 |
| Packages | `shared_preferences`, `flutter_tts` (Bangla speech), `audioplayers` (sound effects, recorded clips) |
| Font | Noto Sans Bengali (bundled, OFL licence in `assets/fonts/OFL.txt`) |
| Platforms | Android, web (Chrome), Windows |
| Code size | about 3,200 lines of Dart in `lib/` |

## 2. Setup on Windows

On an 8 GB machine, develop in Chrome and test on a real Android phone; avoid the emulator.

```
cd C:\dev\fln_game          (short path, no spaces, not in OneDrive)
flutter pub get
flutter test                 (28 tests should pass)
flutter run -d chrome
```

- **Hot reload:** `r` reloads after a code change. `R` restarts, which is needed after adding a level file.
- **Android phone:** turn on USB debugging, plug the phone in, then run `flutter run`.
- **Release APK:** `flutter build apk --release --split-per-abi`.
- **Kotlin cache errors on Android:** run `flutter clean` and build again.

`android/gradle.properties` must keep:
```
kotlin.incremental=false        <- always keep (project rule)
org.gradle.jvmargs=-Xmx2G ...   <- not the template's 8G, the laptop only has 8 GB
```

## 3. Code map

```
lib/
  main.dart                 loads content + profiles, then: no player -> AuthScreen,
                            placement not done -> PlacementScreen, else MapScreen
  brand.dart                app name, tagline, company name, logo paths (change names here only)
  game_scope.dart           InheritedWidget: gives every screen the content, the store, the player,
                            the characters (cast), the audio manager and the coach
  audio/                    audio_manager (speech queue, clips, effects, captions), coach (who says what),
                            audio_settings (voice / effects / captions / volume),
                            voice_pack (stitches recorded clips; falls back to text-to-speech)
  data/cast.dart            loads characters.json, dialogue.json, voice/clips.json
  bn.dart                   Bangla digits bn(), dates, minutes, percent, praise + try-again lines, avatars
  data/content.dart         IslandDef, LevelDef, PuzzleSpec, AchievementDef; Content.load() reads
                            assets/levels/*.json + assets/config/*.json and collects errors
  logic/question.dart       Question, AnswerOption, visuals (ObjectGroup, BigText, Sequence)
  logic/puzzle_factory.dart turns a PuzzleSpec into a Question; validate() checks level settings
  logic/progression.dart    stars, unlocking, placement, "stuck" detection, achievements
  logic/profile.dart        Profile, LevelRecord, Tally, SessionLog, streaks; JSON save format
  logic/profile_store.dart  ChangeNotifier: create / sign in / guest / save guest / delete;
                            saved in shared_preferences under key 'profiles_v2'
  screens/                  auth, placement, map, island (zig-zag path), play, result, achievements
  dashboards/               child_dashboard, teacher_dashboard, dashboard_widgets (kept separate on purpose)
  widgets/                  visuals (object groups, answer buttons, stars), anim (PopIn, Shake, Pulse,
                            CrossOut), celebration (confetti, praise card), sound_widgets
                            (faces, figures, captions), trainer_picker, avatar, adult_gate
assets/
  levels/                   one JSON file per level (files starting with _ are ignored: _template.json)
  config/                   islands.json, achievements.json, characters.json, dialogue.json
  sfx/                      sound effects (made for this project)
  voice/                    clips.json + boy/, girl/ clip folders (empty: text-to-speech is used)
  characters/               the nine trainers, full body; faces/ has their round faces
  brand/                    app_icon.png, company_logo.png (used in the app)
  fonts/                    Noto Sans Bengali
docs/                       this guide, LEVELS.md, DASHBOARDS.md, VOICES.md, voice_script.csv, brand/
tools/                      make_sfx.py (sound effects), voice_pack.py (link or make voice clips)
tool/                       voice_script_test.dart (writes docs/voice_script.csv)
test/                       content, progression and app tests
```

**Data flow:**
1. Level and config files are read by `Content.load()`.
2. `PuzzleFactory` makes questions from them.
3. `Progression` updates the current `Profile`.
4. `ProfileStore` saves it.
5. The screens and dashboards read the content and player through `GameScope`.

## 4. Game rules (in `logic/progression.dart`)

| Rule | Value |
|---|---|
| Pass mark | per level `pass`, default 0.75 of first-try answers |
| Stars | 1 at pass, 2 at 85% or more, 3 at 100% (`StarRules`) |
| Next level | opens when the previous one is passed |
| Islands | open after N levels of another island (`unlock` in islands.json) |
| Placement | 2 probe levels per island, at 1/3 and 2/3 of its path; opens levels up to the last correct probe |
| Stuck | 2 or more fails on a level never passed; shown on the teacher dashboard |
| Easier suggestion | after failing a level twice, the result screen suggests the level before it |
| Guest | not saved; can be saved into a new profile from the map |

## 5. Common tasks

**Add or change a level.** Copy `assets/levels/_template.json` and give it a new `id` and `order`. Run `flutter test`, then `R` in the running app. All fields and puzzle settings are in [LEVELS.md](LEVELS.md). Never rename an `id` children have already played, because progress is saved under it.

**Add an island.** Add an entry to `assets/config/islands.json` with `id`, `title`, `emoji`, `color`, and `unlock` (`null` or `{island, levels}`). Then add level files with that `island`.

**Add an achievement.** Add an entry to `assets/config/achievements.json`. The supported `type` values are `levels_completed`, `total_stars`, `perfect_levels`, `island_complete` (needs `island`), `correct_answers` and `streak_days`. A new type needs a case in `Progression.isAchieved` and in `progressToward`.

**Add a puzzle type.**
1. Add the name to `PuzzleFactory.types`.
2. Add a case in `make()` that returns a `Question`.
3. Add a case in `validate()` that checks its settings in plain words.
4. If it needs a new picture, add a visual class in `logic/question.dart` and draw it in `widgets/visuals.dart`.
5. Document it in LEVELS.md, then add a level using it.

`content_test.dart` loads every level file, so a bad setting fails the tests.

**Change the app or company name.** Edit `lib/brand.dart`. The Android label is in `android/app/src/main/AndroidManifest.xml`, and the web name is in `web/index.html` and `web/manifest.json`.

**Change the app icon.** The source files are in `docs/brand/icon.svg` and `icon_full.svg`. Re-export them to the PNG sizes in `android/app/src/main/res/mipmap-*`, `web/icons/` and `web/favicon.png`, and to `windows/runner/resources/app_icon.ico`.

## 6. Rules to keep

1. Keep `kotlin.incremental=false` in `android/gradle.properties`.
2. Screen backgrounds must be solid colours. See-through `Scaffold` backgrounds caused the "screen goes black" bug. For a tint, use `Color.alphaBlend(color.withValues(alpha: 0.15), Colors.white)`.
3. Levels stay as data files and are never written in Dart.
4. Dashboards stay as separate files in `lib/dashboards/`.
5. All text children see is in Bangla, with Bangla digits (`bn()`).
6. Keep the app light: no new packages without a reason, and no network.
7. Run `flutter analyze` and `flutter test` before sharing a build.
8. Screens never pick spoken lines themselves: they call `coach` (see [VOICES.md](VOICES.md)).

## 7. Tests

`flutter test` runs 28 tests (`audio_test.dart` covers the trainers, dialogue, voice pack, mute and replay):
- `content_test.dart`: every level file, the template, and the config files.
- `progression_test.dart`: stars, unlocks, placement, achievements and streaks.
- `app_test.dart`: sign-in, guest play and saving, a level play-through, and the teacher dashboard.
- `test/helpers.dart`: loads the content from disk.

Screenshots in `fln_game_screens/` were made with Flutter golden tests (`--update-goldens`), loading the fonts from disk with `FontLoader`. That script is not part of the test suite.

## 8. Saved data

Players are stored as JSON in `shared_preferences` under the key `profiles_v2`. Each profile holds:
- name, picture (an emoji or `kid:<trainer id>`) and chosen trainer;
- the levels it has opened, with stars, best score, attempts and fails per level;
- per-island answer tallies;
- the days it played (for streaks);
- its last 50 sessions;
- the achievements it has earned.

If you change the format, bump the key or migrate the old data, or players lose progress.
