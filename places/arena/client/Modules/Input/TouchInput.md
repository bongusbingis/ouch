# TouchInput

Headless touch input layer for the arena client. It owns every touch signal,
classifies it, and publishes gameplay-level gestures. It renders nothing and
creates no `GuiObject` — the screen exists here only as normalized rectangles it
owns as data.

## Consuming it from react-lua

Same shape as the rest of this codebase's stores, so `useExternalStore` reads it
directly and the component never touches `UserInputService`:

```lua
local snapshot = useExternalStore(TouchInput.getSnapshot, TouchInput.subscribe)
-- snapshot.zonePixels.Action -> where to draw an affordance
-- snapshot.charge            -> 0-1, drive a charge meter
-- snapshot.lockedTargetId    -> outline that enemy
-- snapshot.inputDevice       -> hide touch UI on "Mouse"
```

### Snapshot

| Field | Meaning |
|---|---|
| `inputDevice` | `"Touch" \| "Mouse" \| "Gamepad"`, the **active** device from `LastInputType`, never platform capability |
| `zones` | `{ Movement, Action }` as normalized rects `{ x, y, width, height }` in 0–1 |
| `zonePixels` | The same rects in pixels, GUI-inset corrected |
| `leftHanded` | Whether zones are mirrored |
| `charge` | 0–1 while a hold is in progress, else 0 |
| `lockedTargetId` | Current aim lock, or nil (populated in Phase 2) |
| `viewport` | `{ width, height }` |

### Functions

- `TouchInput.start()` — idempotent, safe on every device.
- `TouchInput.subscribe(listener) -> unsubscribe`
- `TouchInput.onGesture(listener) -> unsubscribe`
- `TouchInput.registerExclusionRect(id, rect) -> remove` — a normalized rect that
  swallows touches. Register one per real button once UI exists, and taps
  landing on it are ignored by the tap-anywhere handler.
- `TouchInput.setLeftHanded(value)`
- `TouchInput.setLockedTarget(targetId)` — called by the aim layer, not by UI.

### Gesture payload

```lua
{ kind = "Tap" | "DoubleTap" | "ChargedRelease" | "Swipe",
  direction = "Up" | "Down" | "Left" | "Right" | nil,
  charge = 0-1,
  targetId = string?,   -- set when a tap landed on an enemy
  x = number, y = number }   -- normalized tap position
```

## Design notes

**Camera drag is not gated here.** The stock PlayerModule reads the same touch
stream and `UserInputService` signals observe without consuming, so a drag moves
the camera from its first frame no matter how this layer later classifies it.
There is nothing to buffer and replay for that to feel right. `Gestures` still
tracks the pre-promotion delta, for assists that want to *scale* drag rather
than merely observe it.

**Multi-touch is per `InputObject`.** Each finger carries its own classifier
state, so a camera drag and a simultaneous tap elsewhere in the action zone both
resolve correctly.

**Only the action zone is tracked.** Touches in the movement zone belong to the
thumbstick, and touches under the topbar or inside a registered exclusion rect
are ignored entirely.

**Pixel thresholds scale with viewport height** against
`MobileInput.ReferenceViewportHeight`, so a phone and a tablet ask for the same
physical thumb travel rather than the same pixel count.

## Pure logic

The classification itself lives in `ReplicatedStorage.Shared.Game.Input` and is
plain-number only, so it runs headlessly under Lune:

- `Zones` — layout, hit testing, inset math, threshold scaling
- `Gestures` — per-touch lifecycle state machine
- `TapTarget` — screen-space target scoring
- `InputBuffer` — one-slot buffer with expiry

Every one has a spec in `src/shared/Tests/`.

## Tuning

Everything is in `src/config/MobileInput.luau`, one constant per line with its
sane range. Each feature has `Enabled` and a 0–1 `Strength`; `Strength = 0` is
behaviourally identical to `Enabled = false`.
