# Dodgeball throw UX

## Architecture

- `PlayerModule.Combat.TouchIntent` remains the touch classifier. It emits local presentation events for pending, camera-owned, charge, tap, swipe, cancellation, and cleanup transitions.
- `CombatState` remains the charge and local combat-state owner. It also mirrors the server-projected dodgeball cooldown and exposes one-shot release, cancel, and ready revisions.
- `ThrowUXClient` samples those owners plus `AimDirector` at 30 Hz and exposes one immutable React snapshot. It does not send network traffic.
- `ChargeAim` calculates the ballistic path and impact once, at 30 Hz, and gives that result directly to the React trajectory renderer. It also restores the configured FOV smoothly after charge.
- `CombatHUD` renders the reticle, charge segments, landing marker, swipe feedback, onboarding, mobile hammer button, and optional debug readout.
- `CombatFeedback` routes optional configured audio through `ClientAudio` and restrained pulses through `HapticService`.

## UI states

| State | Presentation |
|---|---|
| Ready | Small white rounded reticle with a subtle ready pulse. |
| PendingInput | Reticle remains calm; touch-local contact feedback appears without showing charge. |
| Charging | A continuous ring contracts, thickens, brightens, and warms toward pink while the trajectory strengthens, FOV eases inward, and the held ball compresses slightly. |
| FullCharge | The smooth pink ring settles tightly around the reticle with one elastic pulse, brighter trajectory, and a stronger one-shot haptic/audio hook. |
| Release | Trajectory clears immediately and the reticle expands briefly. Charged release uses the stronger feedback hook. |
| Recovery | Reticle dims while the replicated cooldown is nonzero or the pose is recovering. |
| Cancelled | Candidate feedback clears and the reticle gives one restrained tilt response. |

## Mobile swipe flow

1. A valid bottom-region touch emits `SwipeCandidate` and shows a soft ring at the finger.
2. Movement stretches one short rounded trail from the touch origin.
3. Camera ownership removes the candidate immediately.
4. Recognition flashes the trail, triggers one restrained haptic/audio hook, and the existing classifier emits the normal throw immediately.
5. The indicator holds for 0.1 seconds and disappears; release cannot produce a second throw.

The hint appears only on touch while a dodgeball is ready, at most three times per session. Two successful swipes suppress it immediately and persist `Onboarding.SwipeThrowLearned` through the existing player profile so it stays hidden in later sessions.

## Configuration

- `Config.ThrowUX.Reticle`: responsive size bounds, segment count, colors, transparency, and state scales.
- `Config.ThrowUX.Trajectory`: dot opacity/size, endpoint size, and screen smoothing.
- `Config.ThrowUX.Swipe`: touch-ring size, trail thickness/length, and cleanup timing.
- `Config.ThrowUX.Onboarding`: delay, duration, session cap, success threshold, and text.
- `Config.ThrowUX.Haptics`: controller motor, strength, pulse duration, and the semantic mobile `HapticEffect` preset for each cue.
- `Config.ThrowUX.Audio`: optional ID arrays and volume for charge start/build, full charge, swipe, releases, cooldown ready, and blocked input. The charge-build cue can also tune its starting and full-charge playback speed.
- `Config.Combat.Dodgeball.Preview`: trajectory segment/sample counts and FOV amount/speed.
- `Config.Combat.Dodgeball.BallFeel.ChargeSquash`: held-ball compression at full charge.
- `Config.ThrowUX.Debug.Enabled`: optional state/input/charge/cooldown/target/swipe readout.

## Required assets

No Studio-authored UI instances or images are required. The reticle, segmented ring, landing marker, swipe indicator, arrow, and hammer button are declarative React elements.

Publish the desired sounds and add their numeric IDs to the corresponding `Config.ThrowUX.Audio.*.AssetIds` arrays. Empty arrays intentionally make those hooks silent. No particle assets are required in this pass.

## Human playtest risks

- The 0.18-second hold threshold and authored windup animation must be judged together.
- Reticle min/max size needs checks on small landscape phones and distant TV viewing.
- FOV reduction, restore speed, and endpoint size need comfort testing during rapid repeated throws.
- Swipe opacity and trail length need real-thumb testing over bright and dark arena areas.
- Haptic motor support and perceived strength vary substantially by phone and controller.
- Target color/scale must remain noticeable without implying a guaranteed hit.

## Test checklist

- PC: click, short hold, charge threshold, full charge, release, cancel via menu/death, target acquisition, cooldown ready, fast camera motion.
- Phone: tap with tremor, charge while aiming, clean/diagonal/failed swipe, camera drag, movement plus throw, hammer proximity, safe areas, tutorial suppression.
- Tablet: repeat tap/charge/swipe tests and verify reticle, trail, endpoint, and button bounds remain readable.
- Controller: trigger tap/hold/release, full-charge pulse, right-stick aiming, disconnect mid-charge, haptic comfort, TV-size readability.
- All devices: spam inputs through cooldown, switch weapons, enter/leave vote UI, respawn, enable reduced motion, and confirm no duplicate actions or retained UI.
