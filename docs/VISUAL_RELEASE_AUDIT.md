# Visual and release audit - direction checkpoint

Owner request: 8 September 2026. Phase I direction checkpoint; **not release-ready**. Owner performs all place deployment and Git pushes. No uploads, publishing, purchases, billing changes, live-data resets, or deployments performed.

## Approval boundaries

The representative lobby home and landscape-phone direction is implemented and advisor-reviewed. **Owner direction approval is pending before broad propagation.** A separate **MANUAL VISUAL SIGN-OFF** remains required after the complete visual/content phase, before Phase II production/economy work. Neither approval has been given.

Preserve approved static arena art/layout, existing React roots, state ownership, commercial offerings and Showtime IDs. Fans/spinners require actual authored-hierarchy inspection before deciding behavior. Existing emotes are podium/preview performances; no in-match emote expansion assumed.

## Changes and evidence

All raw filenames below are under `.review/visual-release/`. Real lobby place 130584867985467, Windows Studio, existing authored character and stage, local mock profiles. Screenshots are actual renderings, not Figma exports. Phone images include the emulator's reserved/cutout regions; camera viewport is smaller than capture dimensions.

| Case | Before | Revised / verification |
|---|---|---|
| Desktop 1246x841, solo | `home-desktop-4-0.png` | `direction-v1-2-0.png`; final source `intermediate-home-4-0.png` after four-slot fixture returned to solo |
| iPhone 17 Pro landscape 874x402 capture, 750x362 camera, 750x304 root | `home-phone-baseline-3-0.png` | `final-composition-2-0.png`; final 14px progression/action frame gap |
| Four-slot presentation fixture | Source only baseline | `final-composition-5-0.png` phone, `final-composition-7-0.png` desktop; synthetic IDs -1/-2/-3, expected username lookup failures, **not real multiplayer** |
| Intermediate 1280x720, 662px usable height | No comparable baseline | `intermediate-home-6-0.png`; Party Code opens `intermediate-modal-2-0.png`, Back closes; desktop wheel scroll works `restore-local-test-state-2-0.png` |
| Local mock respawn | `nametag-respawn-before.result.json`: tag removed, preview rig survives | `nametag-respawn-after.result.json`: tag persists with ResetOnSpawn=false |
| Phone Join Party | Opened via native input | `phone-join-2-0.png`: emulated keyboard covers input; Escape exits; unresolved UI issue |

Implemented through existing owners/components:

- Lobby camera fits occupied party slots (local player always included, duplicates excluded, max 4). Three studs of name headroom reduced to 1.5. Inventory still uses its existing envelopes.
- Home backdrop changed from cyan to warm yellow, separating the cyan character. Other page colors preserved.
- Desktop season/daily/quest panels share the right column, freeing the character stage. Home alone switches to its existing scroll stack and bottom actions when fixed panels cannot fit (below 692px usable height). Global device threshold remains 500px.
- Smaller fitted desktop logo; cyan Join/Invite secondary controls, pink Play. Idle phone status line removed; active matchmaking status remains.
- Nametags anchor above actual rendered rig bounds with collision avoidance and 1px additional clearance. Authored template is still cloned; no replacement UI. ResetOnSpawn=false keeps renderer-owned tags alive through physical-character resets.
- Party Code's compact presentation and modal lifecycle now follow the home composition at intermediate heights. Quest list height uses its actual compact row height.

## Reference direction

Coherent early Fall Guys lobby/customiser family: [lobby](https://interfaceingame.com/screenshots/fall-guys-ultimate-knockout-lobby/), [customiser](https://interfaceingame.com/screenshots/fall-guys-ultimate-knockout-customiser/), [menu transition](https://interfaceingame.com/screenshots/fall-guys-ultimate-knockout-menu-transition/). Full images personally inspected; private copies under `references/`. Game UI Database was inaccessible; equivalent requested reference family was accessible at Interface In Game.

Observed: prominent character silhouette; pink primary/selection, cyan secondary actions; compact dark navigation; strong white edges and restrained shadows; purposeful grouping. Preserve OUCH logo, character, existing journeys and components. The chosen warm home color is our contrast decision, not a claim that the reference lobby uses that exact color.

The 4-second reference MP4 was played in native Media Player. Observed diagonal scene wipe with stable navigation, selected-tab change and distinct scene backgrounds. `references/motion-*.jpg` captures are sparse/uneven; not a measured timing study or dense frame sequence. Actual lobby idle and page/layout changes were personally observed; no full game motion acceptance claimed.

## Issue ledger

| ID | Type / player impact | Status |
|---|---|---|
| V01 | Artistic: tiny solo character, all 4 slots framed | Implemented; solo-to-four-slot fixture rendered on desktop/phone |
| V02 | Artistic: cyan silhouette blends into cyan background | Implemented warm home color; Gemini direction-approved; strong swirl texture/crown contrast still merits next-batch refinement |
| V03 | Artistic: scattered desktop panels, phone action adjacency | Implemented column/reflow/action roles and 14px compact frame gap; screenshots inspected |
| V04 | Functional: physical-character respawn deletes preview name | Reproduced local mock fixture, fixed, same fixture passes |
| V05 | Functional: intermediate-height Party Code overlaps navigation / inaccessible modal under old threshold | Compact presentation/modal conditions aligned; native open/Back verified at 662px usable height |
| V06 | Functional: desktop tutorial SKIP resembles button but is keyboard-only; glyph blank | Observed fresh mock; X works. Discoverable input presentation needs next-batch fix |
| V07 | Functional: phone keyboard covers Join Party input | Observed emulator; unresolved, no physical-device conclusion |
| V08 | Input uncertainty: phone progression swipe/wheel attempts did not move list | Canvas519px/viewport154px and scrolling enabled observed; desktop scrolling works. Touch behavior unresolved, must reproduce/repair before device acceptance |
| V09 | Content: emote craft incomplete/unverified | Source inventory only: Wave and 3 Showtime performances. Native Blender authoring still pending direction checkpoint |
| V10 | Content: fans/spinners behavior unverified | Source registry inspected; live authored hierarchy not inspected yet. Approved static map untouched |
| V11 | Credits consumer absent in searched source | Small attribution integration still pending |
| V12 | Runtime warning: live MinPlayers overrides below minimum rejected | Observed safe rejection; production disposition after visual sign-off |

## Advisor dispositions

- Baseline Gemini `.review/gemini-eaf6877d-27d5-4eed-99ec-bc3c472a4cb6`: accepted framing/contrast/hierarchy concerns; rejected new drawers/wholesale restructure solely from screenshot advice.
- Direction Gemini `.review/gemini-8a896ccd-6cd4-4f25-986f-c9888e0aeecc/review.txt`: **APPROVED**, important refinements. Accepted more phone action gap; implemented after reviewed screenshots. Nametag/crown contrast and nav balance remain next-batch artistic work. Its description of warm reference-lobby staging is inaccurate; retain independent reference observations above. The response file is complete; wrapper state says FAILED because printing the saved response raised Windows UnicodeEncodeError. No second API call made. Use PYTHONIOENCODING=utf-8 for subsequent wrapper invocations.
- First Claude `.review/claude-bdb3cbdd-4b55-4c80-ab85-9e4fb7610819`: requested changes for assumed missing safe-origin offset. Rejected as current-flow blocker: LobbyRoot is already CoreUISafeInsets, and DeviceSafe intersect CoreSafe relative to Core gives origin 0. Actual phone evidence `direction-v1.result.json`: DeviceRect 0,-58,750,304; CoreRect 0,0,750,304; root 750x304. Existing inset tests distinguish full-screen from already inset parents. Experimental label placement was independently revised after actual rendering.
- Follow-up Claude `.review/claude-9c88502c-0fff-4688-8c9e-7a6336dd18db`: **APPROVED**, no blocker. Accepted remaining performance/device caveat: bounding-box queries run for up to 4 rigs per frame; physical/mobile performance not measured. Do not skip hidden members' body bounds without preserving crown collision avoidance. Retain self-body collision entry because safe-rectangle clamping can move the preferred label. Do not add duplicate portrait state or unrelated refactors. Four-slot fixture was rendered after this review packet; physical multiplayer remains unverified.

## Coverage and limitations

738 headless tests pass (`headless-tests-final-gap.txt`); 9 shipped responsive specs also pass through the private Lune datatype harness (`run-responsive-spec.luau`). Shared and lobby Selene: 0 errors/0 warnings; changed-file StyLua and git diff checks pass. These do not establish input usability, remote teleport/payment behavior, persistence, or frame-time budgets.

Tested: Windows Studio desktop mouse/keyboard; phone emulator rendering, daily modal dismissal, Join opening/Escape; desktop progression wheel scrolling; intermediate Party Code open/Back; local mock respawn; synthetic party 1 -> 4 -> 1 projection. Touch scrolling unresolved. No physical phone/tablet, macOS, connected controller, or console tested. Tablet presets discovered but untested. VR excluded. Arena/results/long-error/progression/ownership/purchases and complete first/returning journeys remain pending.

## Workflow blockers and recovery

Figma canonical file qOQKzOXH6HIc8g1PHWvplh was initially empty. Partial editable desktop wrapper/nav 12:2, phone wrapper 12:3, component 12:12 and 6 source variables were created. **Starter-plan MCP quota exhausted; these are incomplete and not approval material.** Exact state `figma/checkpoint-state.json`. Owner must restore available Figma MCP quota/access; no billing action taken. Read current nodes before resuming. BuilderSans unavailable in Figma; Inter proxy explicitly labeled, final font truth is Studio.

Native Studio MCP and Computer Use worked. In-app browser runtime returned no available browser; no browser automation workaround used. Native Blender contains an unsaved owner scene, untouched; protect it before authoring. Media Player reference clip opened; no game assets imported.

Protected preexisting owner changes: deleted AGENTS.md, docs/RECOVERY.md, docs/SECURITY_AUDIT.md; modified docs/ART_STYLE.md. Exact initial patch `protected-work.patch`, baseline revision/status `baseline-git.json`. Exclude these from task commits.

Local test cleanup completed: simulator reset to default; lobby stopped in Edit; original saved PlayerData source restored and mock-disabled verified (`restore-local-test-state.result.json`). Source backup `ServerScriptService_Server_Modules_PlayerData.luau` is Windows CP1252. Repo PlayerData/Profile Template/Env unchanged; existing PrimaryDataKey remains STAGING_009. Namespace name alone does not establish isolation. No persistent storage test performed and no release configuration approved. Synthetic party packets affected only the local Play client and were discarded on Stop. Arena Studio remained Edit and untouched. No .rbxl edited or saved by repository tooling.

Next safe action: request owner approval of the actual desktop/phone direction; restore Figma tool availability in parallel. After direction approval, address the recorded tutorial/phone input and contrast issues, then continue full visual scope and native Blender emote work. Do not begin Phase II before separate completed-visual sign-off.
