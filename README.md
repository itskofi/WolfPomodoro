# Wolf

A free, local menu-bar Pomodoro timer for macOS. Alternating focus sessions and breaks,
with a notification and an unmissable full-screen break screen when a session ends.

No accounts, no network requests, no analytics. Everything is stored in `UserDefaults`.

## Features

- **Focus / short break / long break** durations picked from presets (15, 25, 30, 45, 50,
  60, 90 min for focus) or set to any custom value.
- **Menu bar box** — a drawn box with the remaining time inside it, whose fill tracks the
  phase. Choose whether it *empties out* or *fills up*; it turns green during breaks.
- **Full-screen break screen** on every display when a focus session ends, dismissible
  with `Esc`, the ✕, or a button.
- **Notifications** with your own wording for each transition.
- **History** — today's focus total, a 7-day bar chart, and per-day totals. Breaks and
  skipped (partial) sessions are recorded honestly.
- **Light, dark, or system** appearance.

## Build

Requires the Swift toolchain (Xcode or Command Line Tools) on macOS 14+.

```sh
./build.sh --install   # builds Wolf.app, ad-hoc signs it, installs to ~/Applications
./build.sh             # build only, into ./build/Wolf.app
```

## Distribution

The build is **ad-hoc signed**, which is fine locally but not for public download —
Gatekeeper will refuse it on other machines. Shipping it properly needs an Apple Developer
ID certificate, the hardened runtime, and notarization. See §9 of [PRD.md](PRD.md).

## Design

Palette comes from the animal rather than from software: warm charcoal pelt, bone
off-white, and amber — the eye — as the accent, with a moonlit sage for breaks. The
countdown sits inside a 60-tick stopwatch bezel rather than the usual progress ring.
Full design notes and requirements are in [PRD.md](PRD.md).

## Licence

MIT.
