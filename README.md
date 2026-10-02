# lsi_flutter

The LSI student app — a Flutter client for the Laravel API (dashboard, exams,
calendar, XP and streaks).

## Running locally

### With dummy data (no backend required)

Every screen can be driven offline from the in-memory fixtures in
`lib/core/network/fake/fake_backend.dart`:

```bash
flutter run --dart-define=USE_FAKE_API=true
```

The flag is off by default on purpose: a normal build must never ship a login
that accepts anything.

## What the API does and does not support

Non-obvious limits in the Laravel app, verified against `routes/api.php` and the
controllers. They are the reason some screens say less than they could.

| Thing | Status |
| --- | --- |
| `/xp-history/{user}` | Bound to the **numeric** user id by `->whereNumber('user')`. Holding a `public_id` must call `/users/{public_id}/xp-history` — same controller, same payload. |
| Level | `levelFromExp = floor(exp / 100) + 1`; `maxXPForLevel` is a fixed 100 and `currentXP` is `exp % 100`, so "XP to next level" is exact. Level is never stored independently. |
| Daily claim | `baseXp + min(4, floor(streak / 5))`. `nextClaimAt` is the start of the *next calendar day*, not a rolling cooldown. |
| Streak / `loginDates` | Built from distinct `DATE(created_at)` on `gamification_histories` — a day counts when you **earned XP**, not when you opened the app. `StreakService` advances on a dashboard visit. Window is 90 days. |
| Points | `season_progress.points` is real, but the ledger returns only `amount_xp`. Points are awarded independently of XP, so no breakdown is derivable. |
| Badges | **No JSON endpoint.** The dashboard computes an earned-badge count and discards it; the only badge list is `PublicProfileController`, which returns Inertia HTML. `/u/{public_id}` is registered under `api.php` but is not JSON — do not call it. |
| Ledger reasons | Closed set: `Daily Claim`, `Bonus Claim`, `Assignment Graded`, `Exam Submission`, `Exam Completion XP`, `On-time Exam XP`, `Exam Accuracy XP`, `Season Reward`, `Admin Adjustment`. Deductions reuse the same reason with a negative amount. |

`XpCategory.fromReason` maps that set for the level sheet's breakdown, and falls
back to `other` so a future server-side reason still renders.

### If your home directory contains a space

Flutter's native-assets step invokes `dart` with an unquoted path, so a user
folder like `C:\Users\First Last\` fails every build with:

```text
'C:\Users\First' is not recognized as an internal or external command
Building native assets for package:objective_c failed.
```

Build through a space-free directory alias of the SDK instead. From the project
root, once:

```bash
powershell -NoProfile -Command "New-Item -ItemType Junction -Path '.flutter-sdk' -Target 'C:\path\to\flutter'"
```

Then build or run through it:

```bash
./.flutter-sdk/bin/flutter.bat build apk --debug --dart-define=USE_FAKE_API=true
```

`.flutter-sdk/` is a directory junction, not a copy of the SDK, and is
git-ignored.

## Screens

Four tabs (Home, Exams, Calendar, More). More carries the pages that do not
deserve a permanent tab slot, plus its own sub-routes so the tab bar stays
visible.

Tappable surfaces on the dashboard hero open a sheet:

| Tap | Sheet |
| --- | --- |
| Level ring, or **Season XP** | Level, progress to the next level, next badge's level, and where recent XP came from |
| **Day streak** | Streak summary and a 13-week calendar of earned-XP days |
| **Points** | Season total, and an explicit note that no breakdown is available |
| Either reward card | Why that reward is worth what it is, with the streak bonus ladder |
| `#n of m` chip | The leaderboard page |

Chats and Settings are real pages under More; Courses, Community and Games are
listed with a "Soon" marker.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
