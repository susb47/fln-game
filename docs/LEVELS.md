# Adding levels

Every level is one file in `assets/levels/`. The game reads the whole folder when it starts,
so adding a level is three steps and no code:

1. Copy `assets/levels/_template.json` to a new name, e.g. `assets/levels/counting_06.json`.
   (Files starting with `_` are ignored, so the template itself never shows up.)
2. Edit it (see the fields below). Save it as UTF-8, which VS Code does by default.
3. Run `flutter test`. The test `content_test.dart` checks every level file and tells you
   exactly which file and which field is wrong. Then restart the app (a full restart, not hot reload).

If a file has a mistake, the app skips just that level and lists the problem at the top of the
teacher dashboard, so a typo never crashes the game.

## Level fields

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | Unique name, e.g. `counting_06`. Progress is saved under this id, so do not rename it once children have played. |
| `island` | yes | Which island: an `id` from `assets/config/islands.json` (`counting`, `compare`, `addition`, `pattern`). |
| `order` | yes | Position on the island path. Lower comes first. Gaps are fine (10, 20, 30 leaves room to insert). |
| `title` | yes | Name shown under the level, in Bangla. |
| `grade` | no | Class the level is meant for (1, 2 or 3). Informational for now; the dashboards will use it later. |
| `questions` | no (8) | Questions per play, 1 to 30. |
| `pass` | no (0.75) | Share of first-try correct answers needed to pass and open the next level. 0.75 = 6 of 8. |
| `puzzles` | yes | One or more puzzle settings. Each question picks one at random, so mixing two types gives variety. |

Stars: 1 star for passing, 2 stars at 85% or more, 3 stars when every answer is right first try
(`StarRules` in `lib/logic/progression.dart`).

## Puzzle types

Every puzzle may also have `"objects": ["🥭", "🐟", ...]` (at least 5 emoji) to choose the pictures.

| `type` | Settings | What the child sees |
|---|---|---|
| `count` | `min`, `max` (1-20) | Objects in rows of five, "কয়টি আছে?", pick the numeral. |
| `find_group` | `min`, `max` (1-10) | A numeral, pick the group with that many objects. |
| `compare_groups` | `min`, `max` (1-10), `ask`: `more` / `less` / `mixed`, `minGap` | Two groups, pick the one with more (or less). |
| `compare_numbers` | `min`, `max` (0-100), `ask` | Two numerals, pick the bigger (or smaller). |
| `add_objects` | `maxSum` (2-10) | Two groups with +, pick the total. |
| `add_numbers` | `maxSum` (2-100) | "৩ + ৪ = ?" |
| `subtract_objects` | `max` (2-10) | A group with some crossed out, "কয়টি বাকি?" |
| `subtract_numbers` | `max` (2-100) | "৯ − ৪ = ?" |
| `pattern_pictures` | `unit`: `AB`, `AAB`, `ABB`, `ABC`, `ABCD` | A repeating picture pattern, pick what comes next. |
| `pattern_numbers` | `steps` (e.g. `[2, 5, 10]`), `direction`: `up` / `down` / `mixed`, `maxStart` | Number sequence, pick the next number. |

Example: a Grade 2 level mixing two types.

```json
{
  "id": "addition_06",
  "island": "addition",
  "order": 6,
  "title": "২০ পর্যন্ত যোগ",
  "questions": 10,
  "pass": 0.8,
  "puzzles": [
    { "type": "add_numbers", "maxSum": 20 },
    { "type": "add_objects", "maxSum": 10, "objects": ["🥭", "🍌", "🍎", "🍊", "🍇"] }
  ]
}
```

## New islands and achievements

- **Island**: add an entry to `assets/config/islands.json` (`id`, `title`, `emoji`, `color`, and
  `unlock` = which island and how many of its levels must be finished first, or `null`), then add
  level files that use its `id`.
- **Achievement**: add an entry to `assets/config/achievements.json`. `type` is one of
  `levels_completed`, `total_stars`, `perfect_levels`, `correct_answers`, `streak_days` (with
  `value`) or `island_complete` (with `island`).
- **New kind of puzzle** (e.g. place value, clocks, money): this needs code. Add it to
  `lib/logic/puzzle_factory.dart` (`make`, `validate`, `types`) and to the table above.
