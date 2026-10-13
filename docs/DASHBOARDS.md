# Dashboards plan

Two dashboards, each in its own file under `lib/dashboards/`. Both read only data saved on the
phone (`lib/logic/profile.dart`); nothing is sent anywhere.

## 1. Child dashboard: "আমার অগ্রগতি" (`child_dashboard.dart`)

Who: the child, from the 📊 button on the island map. Goal: pride and a reason to come back.
Must work for a child who cannot read yet, so it leans on emoji, numbers and bars.

| Section | Shows | Built |
|---|---|---|
| Headline tiles | ⭐ stars, ✅ levels done of total, 🏆 achievements, 🔥 days in a row, ⏱️ minutes played, 🎯 first-try correct % | ✓ |
| Island progress | One bar per island in its own colour: levels done of total | ✓ |
| Last 7 days | Minutes played per day (single series, value on each bar) | ✓ |
| Recent games | Last 5 levels with date, stars and score | ✓ |

## 2. Teacher / parent dashboard (`teacher_dashboard.dart`)

Who: a teacher or parent, from the sign-in screen behind a grown-up check (a two-digit sum).
Goal, from the plan: "class summary of who is stuck on which skill", so the adult knows whom
to help and with what. Shared-device classroom model: every child on this phone.

| Section | Shows | Built |
|---|---|---|
| Headline tiles | Players, played this week, average first-try accuracy, stuck levels | ✓ |
| Content problems | Any level file that failed to load, with the reason | ✓ |
| Who needs help | Each child and level they failed 2+ times without passing | ✓ |
| All players table | Name, last played, levels, stars, accuracy, stuck count. Tap a row to open the child. | ✓ |
| Child detail | The child dashboard plus accuracy per skill, the stuck list, 15 recent games, a per-level table (attempts, best %, stars, locked), and delete player | ✓ |

"Stuck" = 2 or more failed plays of a level that has never been passed (`Progression.stuckLevels`).

## Next (not built yet)

1. **One-page weekly guide** for teachers (plan section 6): print or share a summary per child with a suggested offline activity for each stuck skill.
2. **Export**: share a CSV of all players, so a pilot team can collect data from many phones (needed for the pilot measurement in plan section 9).
3. **Class / group grouping** for teachers with more than one class on a device.
4. **Equity view** (plan: track by gender and location): needs optional gender/school fields on the profile, collected with consent.
5. **Pre/post assessment**: re-run the placement check after a few weeks and show the change.
