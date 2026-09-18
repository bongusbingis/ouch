# Pre-mutation hierarchy and count report — HANDOFF 12.1 precondition

Captured read-only in the connected arena place (PlaceId 121997450145716, Edit mode, Play stopped)
immediately before the section 12.1 replacement transaction, 2026-09-16.

## Workspace.LegacyCourses

97 immediate children: 7 Models and 90 Keyframes. No other classes.

| Model | Descendants | Disposition under 12.1.3 |
|---|---|---|
| WhirlPool | 313 | DESTROY |
| DiscJockey | 447 | DESTROY |
| KnockKnock | 774 | DESTROY |
| BumperBay | 334 | DESTROY |
| TiltTrip | 469 | DESTROY |
| Downpour | 537 | DESTROY |
| SummitSplash | 275 | PRESERVE (authored source; never retired) |

`CrossCurrent` has no parked model, exactly as 12.1 states; only its code/config references retire.
The 90 Keyframes and `Workspace.LegacyCourses` itself are never touched.

## ReplicatedStorage.Assets.Maps.Splashdown (templates)

7 Models, all promoted before the transaction:

| Template | SpecHash | Descendants |
|---|---|---|
| BallBarrage | 7a46da9c | 272 |
| WhirlpoolWaltz | 78e562b8 | 278 |
| DoorDash | aae4c298 | 462 |
| TumbleTunnels | d390ff50 | 334 |
| TiptoeTrials | 0f8e9510 | 318 |
| PistonPeak | e164c528 | 327 |
| SummitSplash | dcece9ec | 320 |

No template carries a retired course id, so 12.1.5 has nothing to remove there.

## ServerStorage.SplashdownStaging

7 staged Models, re-verified immediately before `promote` per the 1.4 staging warning:

| Staged | SpecHash | BaseParts |
|---|---|---|
| BallBarrage | 7a46da9c | 143 |
| WhirlpoolWaltz | 78e562b8 | 142 |
| DoorDash | aae4c298 | 221 |
| TumbleTunnels | d390ff50 | 163 |
| TiptoeTrials | 0f8e9510 | 160 |
| PistonPeak | e164c528 | 162 |
| SummitSplash | dcece9ec | 199 |

Every staged hash equals the hash recorded for that course in HANDOFF 1.3/1.4, and every staged hash
equals its already-promoted template's hash.
