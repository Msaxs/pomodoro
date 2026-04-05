# Pomodoro

A Zero-UI Pomodoro timer for iPhone. No buttons. No clutter. Just time.

---

## What is this?

Most productivity apps are full of controls. This one has none.

Pomodoro is a landscape-only focus timer that runs a 5-stage work/rest sequence automatically. You interact with it through gestures alone — a tap to start or pause, a long press to fast-forward. The Dynamic Island keeps you informed without you ever opening the app.

---

## The Stage

| Stage | Name | Duration |
|-------|------|----------|
| 01 | PREPARING | 2m 30s |
| 02 | DOMINATING | 25m |
| 03 | RECOVERING | 2m 30s |
| 04 | DOMINATING | 25m |
| 05 | RECOVERING | 5m |

---

## Gestures

| Gesture | Action |
|---------|--------|
| **Single Tap** | Start / Pause |
| **Hold** | Accelerate |

---

## Dynamic Island

A Live Activity runs throughout your session, visible on the Dynamic Island and Lock Screen:

- **Compact:** Amber dot (left) + live countdown (right)
- **Expanded:** Stage name, countdown timer, progress bar
- **Paused state:** Dims to indicate the timer is paused
- **Force-quit:** Island disappears immediately

---

## Design Principles

- **Zero UI** — no visible buttons, ever
- **Landscape only** — the full screen is the timer
- **Haptic contrast** — heavy thud to start, soft clicks to accelerate
- **Amber Authority** — `#FFBF00` as the single brand color throughout

---

## Requirements

- iPhone with Dynamic Island (iPhone 14 Pro or later)
- iOS 18+
- Xcode 16+
