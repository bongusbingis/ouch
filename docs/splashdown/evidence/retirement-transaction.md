# HANDOFF 12.1 replacement transaction and 12.3 verification — measured record

Connected arena place 121997450145716 (Match Place), branch `feature/splashdown-hazard-kits`,
2026-09-16. Pre-mutation hierarchy and counts are in `retirement-pre-mutation.md`.

## 12.1.2 — promote

`CourseAuthoring.promote` was called from the Studio Edit Command Bar with all seven ids and the
seven hashes re-verified in `ServerStorage.SplashdownStaging` immediately beforehand. It returned
`ok=true` with the seven ids, and its new set-equality assertion passed in both directions.

| Template | SpecHash | BaseParts after promote |
|---|---|---|
| BallBarrage | 7a46da9c | 143 |
| WhirlpoolWaltz | 78e562b8 | 142 |
| DoorDash | aae4c298 | 221 |
| TumbleTunnels | d390ff50 | 163 |
| TiptoeTrials | 0f8e9510 | 160 |
| PistonPeak | e164c528 | 162 |
| SummitSplash | dcece9ec | 199 |

Every part count equals the staged model's; `PreviewOnly` is nil on all seven.

## 12.1.3 — retirement

Each target was resolved by full path and class-checked before any destroy:

~~~text
Workspace.LegacyCourses.WhirlPool    Model  parentIsLegacy=true
Workspace.LegacyCourses.DiscJockey   Model  parentIsLegacy=true
Workspace.LegacyCourses.KnockKnock   Model  parentIsLegacy=true
Workspace.LegacyCourses.BumperBay    Model  parentIsLegacy=true
Workspace.LegacyCourses.TiltTrip     Model  parentIsLegacy=true
Workspace.LegacyCourses.Downpour     Model  parentIsLegacy=true
Workspace.LegacyCourses.SummitSplash Model  PRESERVED
Workspace.LegacyCourses.CrossCurrent not present (never had a parked model)
~~~

`CourseAuthoring.retireLegacy` returned all six ids. `Workspace.LegacyCourses` went from 97 children
to 91: the 90 Keyframes and the preserved `SummitSplash` source model. The folder itself was never
touched, and `ServerStorage.SplashdownAuthoringSources.SummitSource` is intact.

The hardened guard was proved live before the destroys: `retireLegacy({"NotACourse"})` raised
`NotACourse is not a retireable legacy course; nothing was destroyed` rather than silently doing
nothing, which is also what confirmed the freshly synced module was the one running.

## 12.1.5 — templates and previews

`ReplicatedStorage.Assets.Maps.Splashdown` held exactly the seven new ids before and after; no
template, preview or fixture carried a retired id, so nothing had to be removed there. Historical
screenshots and JSON under `docs/splashdown/evidence/` were not touched.

## 12.3 — headless

~~~text
lune run src/scripts/lune/run-tests.luau   ->  984 tests, 0 failures
git diff --check                           ->  exit 0, no whitespace errors
~~~

## 12.3 — Studio TestEZ, the final bootstrap

`docs/splashdown/probes/run-final-verification.server.luau`, installed as an ordinary temporary
Script, in four Play sessions. Seven full course audits in one session is tens of millions of graph
edges and Studio kills a script that long, so the courses were batched; the kit and contract specs
ran once. **239 passed, 0 failed, 0 skipped, no errors.**

| Batch | Specs | Passed |
|---|---|---|
| 1 | Server/RotatingComposition, Server/CarryMotion, Server/HazardKits, Assets/SplashdownCourses, Assets/SplashdownQA over BallBarrage + WhirlpoolWaltz | 95 |
| 2 | Assets/SplashdownQA over DoorDash + TumbleTunnels | 56 |
| 3 | Assets/SplashdownQA over TiptoeTrials + PistonPeak | 56 |
| 4 | Assets/SplashdownQA over SummitSplash | 32 |

That is 25 kit assertions, 14 contract assertions (two per course over the seven in `CourseOrder`),
24 QA assertions per course for 168, and the 8 set-wide lifecycle/malformed fixtures once per batch
for 32. `SplashdownCourses.spec`'s stale "five" description and its behaviour were NOT changed; it
iterates `CourseOrder` and now yields 14.

The 8 new set-wide fixtures in `SplashdownQA.spec` are the 12.3 items that did not previously exist:

1. boots every registered template through the real course validator
2. lets two independently cloned courses coexist without sharing anything
3. leaves no root, constraint, detached part or ghost behind after a destroy and re-clone
4. rejects a course whose declared CheckpointCount disagrees with its folder
5. rejects a course that cannot seat a full queue on its start pads
6. rejects a course with no hazard at all
7. rejects a course whose boundary ring has been emptied
8. rejects a door course whose row is one slab short of its configured quota

Each malformed fixture mutates the live Play-session template, asserts the real
`SplashdownCourses.instantiate` path throws, reverses the mutation and asserts the course resolves
again — so a fixture cannot leave the set broken for the next one, and the Edit-mode template is
never at risk because Play's DataModel is a throwaway copy.

## 12.3 — three-course match flow through the existing admin seams

`docs/splashdown/probes/run-match-flow.server.luau`. `MatchService.restartForAdmin("Splashdown")`
(the call `sb-match-restartServer` makes), then `SplashdownService.stateForAdmin()`,
`.setNextCourseForAdmin(courseId)` and `.advanceForAdmin()`. No new flow code.

| Round | Course | Chosen through the seam | Live BaseParts | SpecHash | Checkpoints (actual/declared) |
|---|---|---|---|---|---|
| 1 | SummitSplash | no — drawn | 199 | dcece9ec | 4 / 4 |
| 2 | DoorDash | yes | 221 | aae4c298 | 5 / 5 |
| 3 | PistonPeak | yes | 162 | e164c528 | 6 / 6 |

Sequence progressed `SummitSplash > TumbleTunnels > BallBarrage` (the draw) to
`SummitSplash > DoorDash > PistonPeak` as each selection landed. Every live model's BasePart count
equals its template's.

Round 1's course is the drawn one because `setNextCourseForAdmin` writes `sequence[roundIndex + 1]`
and `roundIndex` is already 1 by the time a Studio session's match reaches Intro; the Idle window
after `restartForAdmin` is not reliably observable. Rounds 2 and 3 were chosen through the seam.

**No completed run is claimed.** Each racing phase was closed through the seam's own close with zero
racers credited — a DNF close, not a falsified completion. `advanceForAdmin` was used on Intro and
RoundOver phases and once per round to close Racing; no finish, checkpoint credit or time was
fabricated.

`setNextCourseForAdmin("CrossCurrent")` returned `false, "unknown_course"`. No retired id has a
template. All seven templates booted with no missing-template error.

**One observed warning class, and why it is not a regression.** The compressed run printed
`Infinite yield possible on ...__hazards:WaitForChild("Origin")` for DoorDash's six rotating groups.
`RotatingPlatforms.trackGroup` deliberately waits off the main thread for `Origin` and `Assembly`
("Origin and Assembly stream in independently of their parent Folder"), and a course destroyed ~1.5
seconds after standing leaves that wait pending forever, so the engine prints its 5-second notice and
the generation guard drops the build. A normal untouched session was then run with DoorDash standing
for 60 seconds: **zero such warnings, zero Splashdown errors**, all six groups present with Origin
and Assembly, and the kits measurably driving geometry — `02_SlideSwipe` and `06_CrossFinish` turning
1.98 of a LookVector per 1.2 s, `03_BeltBrawl` moving 6.96 studs, `05_MaceMarch` swinging 19.18 studs
and three parts carrying conveyor velocity. The warnings are an artifact of the artificially short
rounds, not of the transaction.

## 12.3 — default-arena regression (section 3.1's frozen systems)

`docs/splashdown/probes/run-arena-regression.server.luau`, measured at server boot before the
Splashdown venue parks the arena interior. `Debug.StudioQueue` is `"Splashdown"`, so a Studio session
always plays a Splashdown match and `restartForAdmin("FFA")` cannot hold the arena venue open; the
arena's own live window is the first seconds of the session.

- `Assets.Arena.Scriptables` is a tagged `ScriptableRoot`; `Arena.Map.Model` has 262 children.
- **`missingExactNames` is empty.** Every name in `MapFeatures.Fan.EnabledNames` and
  `MapFeatures.Spinner.EnabledNames` resolves to a real BasePart.
- Name-driven counts: Fan 4, Spinner 6, Disc.Hub 9, Disc.Plate 9, SwingPanel.Axle 6,
  SwingPanel.Panel 6, Bumper 54.
- 65 of 94 sampled hazard parts moved within 1.5 s, so the kits are driving the authored geometry,
  not merely registered.
- Shared values unchanged: gravity 120, Fan 65 / 0.65, Spinner knockback 42, Bumper knockback 36,
  Rotating CarryHeight 16, Disc 45 deg/s, SwingPanel period 2.8 s.

**Client carry path unchanged.** The arena's own `InnerRing` and `OuterRing` Origins carry no
`ServerCarries`, no `RotationSpeed` and no `RotorCarries` attribute — the client carry path they have
always used. Every Splashdown course's rotating groups carry `RotationSpeed = 0` (HANDOFF 13's rule)
and `ServerCarries = true` only on the groups that actually carry riders, which is the opt-in Gate 2
contract. No second solver was enabled anywhere.

**Frozen files, by diff against the pre-transaction HEAD `34be9fc`:** `SplashdownService.luau`,
`SplashdownCourses.luau`, `DoorRows.luau`, `VenueService.luau`, `RaceRound.luau`,
`CourseSequence.luau`, `DoorPlan.luau`, `Queues.luau`, `GameModes.luau`, `MapFeatures.luau`,
`Network.luau`, all of `places/lobby/**`, `src/shared/UI/**`, `STYLE.md` and `SHOP_REDESIGN_PLAN.md`
are **all unchanged**.

## 12.3 — rebuild-from-source hash parity

All seven courses were rebuilt from the section 4 source exports through `CourseAuthoring.stage`,
in two Command Bar calls, after the transaction:

~~~text
BallBarrage    7a46da9c / 143   == template 7a46da9c
WhirlpoolWaltz 78e562b8 / 142   == template 78e562b8
DoorDash       aae4c298 / 221   == template aae4c298
TumbleTunnels  d390ff50 / 163   == template d390ff50
TiptoeTrials   0f8e9510 / 160   == template 0f8e9510
PistonPeak     e164c528 / 162   == template e164c528
SummitSplash   dcece9ec / 199   == template dcece9ec
attributeErrors 0, routeErrors 0, boundsViolations 0
~~~

Every hash and part count matches the promoted template exactly: there are no untracked Studio-only
nudges in any of the seven.

The source exports themselves still hash to their recorded values
(`docs/splashdown/evidence/source-hashes.json`), re-computed on disk:

~~~text
kit-source.rbxmx     e9e69d1defddda53ba439cf78660d1b668c489913c309b771cda7fcb7d9f7eec  2300045 bytes
summit-source.rbxmx  a7f21b8965d272c41944bc8919ab7ac8007700a370e7c87f1b85a25cc475ab0f  1444428 bytes
arena-sources.rbxmx  d3ffff472b0c976b862b9aab33e7e517b55d2228797dc75b9d5d3b2dd49710c8    24535 bytes
~~~

## Place left clean

`ServerScriptService` holds only `Server`; `Server.Scripts` holds only `SimulationServer`. Every
temporary probe, fixture, preview, selection value and result value was removed.
`Assets.Arena` is back to `Map, Scriptables, PlayerSpawns, TeamSpawns, MapOrigin` with no live
course. `ServerStorage` holds only the place's own contents plus the authoring pipeline's documented
`SplashdownAuthoringSources`, `SplashdownStaging` and stage-report values.
