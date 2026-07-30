# PRD — Wolf (macOS Pomodoro Timer)

**Status:** v0.3
**Date:** 2026-07-30 (v0.1 → v0.3; renamed from FlowClone to **Wolf** in v0.3)
**Platform:** macOS 14+ (built and tested on macOS 26.5, Apple Silicon)

## 1. Purpose

**Wolf** is a free, local, menu-bar Pomodoro timer for macOS that replicates the core loop
of [Flow](https://www.flow.app/de/): alternating focus sessions and breaks, with a
notification and an unmissable full-screen break screen when a session ends.

Non-goals: accounts, sync, app/web blocking, Apple Watch, iCal logging. Those are
explicitly deferred (§7).

## 2. Users & core scenario

A single user on their own Mac wants to work in timed intervals. They set the app running
in the morning, click Start, and are pulled out of focus by a full-screen break screen when
each session ends — without needing to look at a clock or pay a license fee.

## 3. Functional requirements

### FR-1 Timer engine
- Three phase types: **Focus**, **Short break**, **Long break**.
- Cycle: Focus → Short break, repeated. After every *N* focus sessions (`intervals`, the
  long-break interval), the break is a **Long break** and the session counter resets.
- States: `idle`, `running`, `paused`.
- Countdown is computed from a wall-clock deadline (not by decrementing a counter), so it
  stays accurate across UI stalls. Time spent with the lid closed / machine asleep counts
  as elapsed.
- Controls: Start, Pause, Resume, Skip (end current phase now), Reset (back to idle,
  session counter to 0).

### FR-2 Configurable durations (Settings)
Durations are chosen from a **dropdown of presets**, with a **"Custom…"** entry that
replaces the dropdown in place with a number field (1–180). A stored value outside the
presets renders as `37 min (custom)`.

| Setting | Default | Choices |
|---|---|---|
| Focus duration | 25 min | 15 / 25 / 30 / 45 / 50 / 60 / 90 + custom |
| Short break | 5 min | 3 / 5 / 10 / 15 / 20 + custom |
| Long break | 15 min | 10 / 15 / 20 / 30 / 45 + custom |
| Sessions before long break | 4 | 1–12 |
| Auto-start breaks | on | bool |
| Auto-start next focus session | off | bool |
| Play sound on phase change | on | bool |
| Show full-screen break screen | on | bool |
| Menu bar box direction | Empties out | Empties out / Fills up |
| Theme | Match system | Match system / Light / Dark |

All settings persist in `UserDefaults` and take effect on the next phase (changing the
focus duration mid-focus does not retroactively move the current deadline).

### FR-3 Menu bar item
- `NSStatusItem` is the app's only permanent UI; the app is an accessory (no Dock icon,
  no main window).
- The indicator is a drawn **rounded box** (20 pt tall, width hugging the text) with the
  remaining `MM:SS` set at 12.5 pt semibold **inside** it, so the box is filled by its
  label rather than padded with empty space. Its horizontal fill tracks phase progress, in the direction chosen in
  Settings and stated in words:
  - **Empties out** (default): full at phase start, empty at `00:00`.
  - **Fills up**: empty at phase start, full at `00:00`.
- During a break the whole box (outline, fill, text) is **green**; during focus it is a
  template image so macOS tints it correctly for light and dark menu bars. Paused draws at
  half opacity.
- Clicking opens a panel directly under the menu bar with three tabs:
  **Timer · History · Settings** (see §6). The panel is sized to its content per tab.
- Timer tab: tick dial with countdown, phase name, session dots (`● ● ○ ○`), one primary
  Start/Pause button, with Skip and Reset as ghost buttons beneath it.

### FR-4 Notification
- On every phase transition the app posts a local notification via `UserNotifications`:
  - Focus ended → "Focus session complete — time for a break" (+ break length).
  - Break ended → "Break over — back to focus".
- Notification text for each transition is configurable in Settings (two text fields).
- If notification authorization is denied or unavailable (e.g. unsigned build), the app
  degrades silently: sound + full-screen screen still fire. No error dialog.

### FR-5 Full-screen break screen
- When a focus session ends and the setting is on, a borderless full-screen window covers
  **every connected display**, above all other windows and above the menu bar
  (`.screenSaver` window level, joins all Spaces).
- Content: "Time for a break", live countdown of the break, session counter, and buttons
  **Skip break** and **Start focus now**.
- The window closes automatically when the break ends, on Skip, on `Esc`, or via the ✕ at
  its top-left corner.
- The screen is dismissible (it does not lock the machine or trap input) — it is a strong
  interruption, not a kiosk.

### FR-6 Sound
- Short system sound on each phase change (`Glass` at focus end, `Ping` at break end),
  suppressible via Settings.

### FR-7 History
- Every ended phase is recorded: type, start and end timestamps, planned length, actual
  seconds spent, and whether it completed or was skipped early.
- Focus **and** break phases are recorded; sessions ended early are stored as **partial**
  with the minutes actually spent. Phases under 30 s and phases cleared with Reset are not
  recorded.
- Stored as JSON in `UserDefaults`, pruned to the last 90 days / 1000 records.
- History tab shows: today's focus total and session count (with break minutes and partial
  count), a **7-day bar chart** of daily focus totals with today highlighted, and a grid of
  the same seven days' totals. Individual sessions are collapsed into day totals.

### FR-8 Launch & packaging
- Ships as `Wolf.app` (bundle id `com.local.wolf`, generated `AppIcon.icns`), ad-hoc code signed, installable to `~/Applications`.
- `LSUIElement = true` (agent app). Quitting from the popover menu terminates it.

## 4. Non-functional requirements

- Idle CPU near zero: a single 0.5 s tick timer only while running.
- No network access at all. No analytics, no accounts.
- Entirely local storage (`UserDefaults`, including history), no files written outside the
  app's prefs.
- Cold start under 1 s.

## 5. Architecture

```
Sources/Wolf/
  main.swift              NSApplication bootstrap, .accessory activation policy
  AppDelegate.swift       wires status item, popover, overlay, notifications
  Settings.swift          UserDefaults-backed, ObservableObject; presets, BoxDirection
  PomodoroTimer.swift     phase state machine, deadline math, elapsed tracking (engine)
  SessionStore.swift      persisted history + derived daily/weekly stats
  MenuBarBox.swift        draws the menu bar box NSImage
  PopoverView.swift       tabbed shell + Timer tab
  SettingsView.swift      grouped settings form
  DurationPicker.swift    preset dropdown with in-place custom entry
  HistoryView.swift       today summary + 7-day bar chart
  OverlayController.swift full-screen NSWindow per NSScreen
  Notifier.swift          UNUserNotificationCenter wrapper w/ graceful degradation
```

The engine is UI-independent and publishes `phase`, `remaining`, `state`,
`completedFocusSessions`; every view is a pure function of that. `PomodoroTimer` tracks
actual elapsed seconds separately from the countdown (accumulated across pauses) so
`SessionStore` can record partial sessions truthfully.

## 6. Design language

Wolf takes its palette from the animal rather than from software: warm charcoal pelt, bone
off-white, and **amber — the eye** — as the single accent, with a moonlit sage for breaks.
It is deliberately **opaque**: no vibrancy, no translucency, so the panel reads as its own
object rather than a tinted sheet over the desktop.

Every token in `Theme.swift` is a **dynamic colour**, so one definition serves both
appearances. The user picks Light, Dark, or **Match system** (default) in Settings; the
choice is applied as an `NSAppearance` on the panel and the break screen.

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` | `#EDEDEA` | `#191A1C` | panel and break-screen base |
| `surface` / `surfaceRim` | `#FFFFFF` / `#DCDBD6` | `#222326` / `#33353A` | cards, tabs, hairlines |
| `accent` | `#B0741F` | `#E0A03C` | focus phase — the wolf's eye |
| `mint` | `#3D7565` | `#7FB5A2` | break phase |
| `text` / `textDim` | `#1C1D20` / `#6C6E73` | `#ECEAE5` / `#97948D` | copy |

**Signature — the tick dial.** Instead of the usual pomodoro progress ring, the countdown
sits inside a 60-tick stopwatch bezel (`TickDial`): ticks still to come are lit in the
phase colour, spent ticks fall back to the rim, so the dial visibly empties. Every fifth
tick is longer, as on a real bezel. The countdown is set in **monospaced** type, so the
panel reads as an instrument and the digits never jitter as numbers change.

Layout rules:
- **Content-sized panel** (320 pt wide) — each tab is exactly as tall as it needs to be,
  via `NSHostingController.sizingOptions = [.preferredContentSize]`. Only Settings scrolls.
- **`Card`** — every settings/history group is one full-width card, so all groups share
  identical edges and padding.
- **`Row`** — label left, control in a shared 138 pt right-hand column; dropdowns fill that
  column and toggles pin to its trailing edge, so all controls sit on one vertical axis.
- **Chrome** — ✕ close at the top-left in the macOS idiom and ⏻ quit at the top-right, both
  quiet until the pointer is over them, when they colour. Tabs highlight on hover too.
  The break screen carries the same ✕ at its top-left.
- **Wolf mark** — a geometric wolf head used in the title bar and on the break screen,
  tinted with the current phase. The app icon extends it: a wolf in profile with an amber
  clock ring clamped in its jaws, a bite already out of the dial, speed streaks behind.

## 7. Acceptance criteria (v0.3)

1. Set focus 1 min / short break 1 min / long break after 2, press Start.
2. Menu bar box counts down with the time inside it and drains to empty at `00:00`.
3. A notification appears with the configured focus-end text.
4. A sound plays and the full-screen break screen appears on all displays; the box is green
   for the duration of the break.
5. The break counts down on the overlay; at 0 the overlay disappears and the break-end
   notification fires.
6. After the 2nd focus session the break shown is the long break.
7. Switching the box direction to *Fills up* inverts the fill live.
7b. The panel opens directly beneath the menu bar at a fixed size, closes via the ✕ at its
   top-left, and quits via the ⏻ at its top-right.
8. Choosing 45 from the focus dropdown shows `45:00` while idle; Custom → 37 persists
   across a relaunch and renders as `37 min (custom)`.
9. History tab shows today's total, the completed sessions, and today's bar; Skip
   mid-session records a partial with the minutes actually spent.
10. Settings and history survive an app relaunch.

## 8. Deferred (v0.4+)

Streaks and per-session drill-down, app & website blocking, custom sound files, global
hotkeys, Focus-mode / Do-Not-Disturb integration, iCal logging, themes, launch-at-login,
history export.

## 9. Distribution (not yet done)

Today the app is **ad-hoc signed** (`codesign -s -`), which is fine on this Mac but not for
public download — Gatekeeper will tell other users the app "cannot be opened because the
developer cannot be verified", and they would have to right-click → Open to bypass it.

To put Wolf on a website for one-click install:
1. Join the Apple Developer Program (€99/yr) and create a **Developer ID Application**
   certificate.
2. Re-sign with that identity **plus the hardened runtime**
   (`codesign --options runtime --timestamp`).
3. **Notarize** the build (`xcrun notarytool submit`) and **staple** the ticket
   (`xcrun stapler staple Wolf.app`).
4. Ship it as a `.dmg` (or zipped app) and host it.
5. Optional: Sparkle for in-app updates; a privacy note is trivial since Wolf makes no
   network requests at all.

Legally, Wolf is original code that reimplements a common technique (Pomodoro); the rename
away from "Flow" avoids trading on another product's name.
