# Visual and release audit - responsive lobby checkpoint

Owner request: 8 September 2026. Phase I direction checkpoint; **not release-ready**. Owner performs all place deployment and Git pushes. No uploads, publishing, purchases, billing changes, live-data resets, or deployments performed.

## Approval boundaries

The owner approved the visual direction and character framing, then requested substantial lobby layout and color-role refinements. Those refinements are implemented and advisor-reviewed below. A separate **MANUAL VISUAL SIGN-OFF** remains required after the complete visual/content phase, before Phase II production/economy work; that approval has not been given. The owner explicitly permits native PC control of Figma and useful custom asset uploads. Each standalone upload still requires the installed human gate, brought to the foreground for every request. No upload occurred in this lobby pass.

Preserve approved static arena art/layout, existing React roots, state ownership, commercial offerings and Showtime IDs. Fans/spinners require actual authored-hierarchy inspection before deciding behavior. Existing emotes are podium/preview performances; no in-match emote expansion assumed.

## Changes and evidence

### Current action-button and logo refinement

The owner accepts the surrounding comparison composition and requested a bounded correction to Join/Invite/Play sizing, text, color, matching sliced corners and the padded OUCH logo. Play must remain predominantly larger than the other two actions. This pass is implemented, runtime-verified in Studio and visually reviewed; owner acceptance of these new fixes is still pending.

Open `.review/visual-release/comparison/index.html`. **Previous review** now means the accepted `9bc2b2d` composition with dark secondary buttons; **Updated** shows these fixes. The camera framing, progression treatment and surrounding header composition remain the accepted baseline.

- Join/Invite reuse the authored cyan face and Play reuses its authored pink face. All three now render actual sliced images, with `SliceScale = 0.075` and asset-specific slice boundaries. The two source textures differ by one pixel in each dimension; the adjusted right/bottom boundaries preserve matching corners, approximately 14px, and the same border/shadow treatment across tested sizes. The previous Play slice setting had no effect because the image was empty.
- Play remains wider and taller: desktop 373x68 versus 328x52 secondary actions; landscape phone 190x56 versus 99x48; small phone 138x56 versus 71x48. Its label is larger. Join/Invite share one fitted text scale, use dark ink on cyan, and shorten to JOIN/INVITE in horizontal rows. Padding adapts to button width; the smallest tested secondary labels remain 16px. Play's text and square arrow center as one measured group, with optical vertical adjustment and allowance for the face's shadow.
- The existing logo's 1023x682 texture contains visible artwork in an 809x375 region (alpha threshold 8). `ImageRectOffset`/`ImageRectSize` select that region with a 2px guard; `Fit` preserves its proportions inside a header-bounded image box. The measured texture and alpha bounds are recorded in `button-logo-refinement/artwork-measurements.json`. No replacement raster or upload was needed. Roblox documents the image rectangle and slice properties in the [ImageLabel reference](https://create.roblox.com/docs/reference/engine/classes/ImageLabel).

Evidence under `.review/visual-release/button-logo-refinement/`: `final-2-0.png` desktop 1246x841, `final-5-0.png` iPhone 17 Pro landscape 874x402, `final-8-0.png` intermediate 1280x720, and `final-11-0.png` small landscape phone 568x320. `final.result.json` includes live button dimensions, text bounds/sizes, slice values and assertions for fitted text, readable labels and primary-button hierarchy. `tested-source.json` records exact equality between the captured Studio client modules and repository source. Comparison images are unchanged JPEG copies despite the raw MCP filenames ending in `.png`.

Validation: **745 headless tests, 0 failures** (`tests.txt`); **12 shipped responsive specs, 0 failures in Studio**; shared and lobby Selene have no errors or warnings; changed files pass StyLua and whitespace checks. The header regression now also checks the logo box remains inside the header at narrow, reflowed and desktop widths. These are local mock/emulator checks, not physical-device or full gameplay-journey acceptance.

Gemini `gemini-15d6cf5a-612f-47d9-bd3e-2d6d7853389d` **APPROVED** all four final captures with no findings. The preceding request `gemini-4bf71b5e-c7a5-48e7-88ba-e46ffb7618f8` returned `ServerError`; the final bounded retry used the corrected JPEG MIME type and revised intermediate labels. No cause beyond the reported server error is established. Native browser verification was paused when Computer Use detected owner input; all comparison links and unchanged image copies were checked locally.

Cleanup: device simulation stopped; both Studio places are in Edit; the lobby's temporary mock toggle is off and PlayerData matches the repository source exactly (`cleanup.json`). Existing release storage configuration is restored. No pushes, publishing or uploads occurred. The wider Phase I findings below remain open; next owner review can use the updated comparison.

### Previous responsive and color-role refinement

Open `.review/visual-release/comparison/index.html`: **Previous review / Updated** compares the owner's last reviewed yellow treatment against this pass. Original cyan baselines remain separately linked. Raw numeric suffixes are MCP request IDs and image-block indices, not scores or revision numbers.

| Actual local Studio view | Evidence under `.review/visual-release/` |
|---|---|
| Desktop 1246x841, solo mock | `lobby-responsive-final-4-0.png` |
| Landscape iPhone 17 Pro 874x402 capture, 750x304 core-safe root | `lobby-responsive-final-6-0.png` |
| Intermediate 1280x720, 662px usable height | `lobby-responsive-final-8-0.png` |
| Small landscape phone 568x320 | `daily-overflow-verification-5-0.png`; current source |
| Quest claimed / ready-to-claim presentation fixtures | `quest-state-contrast-4-0.png`, `quest-state-contrast-6-0.png`; projection only, no profile writes or grants |
| Header geometry and action sizes | `responsive-final-views.result.json`, `lobby-refinement-final.result.json` |
| Quest scrolling through Studio MCP input | `quest-scroll-input.result.json`; emulator input, not physical touch |

- `LobbyHeader` keeps controls in the existing core-safe root while a separate noninteractive React decoration covers the full viewport. It hides with the lobby, including the tutorial. The existing logo has a 220x100 image box on the tested phone; transparent source padding means visible artwork is smaller. Navigation glyphs retain square proportions. The header reflows to two rows below its measured minimum width.
- The home layout derives a fixed column, a shorter column, or explicit **SEASON / DAILY / QUESTS** tabs from available space. The shortened column is not an outer scrolling container; quest rows retain their own scroll area. Both quest and daily strips display direction cues only when their actual contents overflow, reversing at the end.
- Play uses the existing React button surface with a fixed 56px phone height and a square icon. Join/Invite remain at least 44px high and use ink secondary surfaces. Buttons reflow beside the progression panel rather than stretch across it.
- Claim is 44px high inside a 60px yellow header with allowance for its edge, shadow and hover treatment. The seven-day row fits at desktop/intermediate widths; small cards preserve readable horizontally scrolling cells or a current-day summary at the shortest height.
- Color roles retain the palette: ink body text on light quest/day surfaces and yellow bands, cyan framing, pink primary actions/selection, white lettering on dark/pink controls. Shared season detail labels use the same ink role. This is not yet an audit of every modal/shop/arena consumer.
- Existing party/camera state ownership, navigation callbacks, rewards and matchmaking actions remain in their existing adapters. Legacy arena `TopBar` consumers use the original default branch.

Current verification: **745 headless tests, 0 failures** (`lobby-final-tests.txt`); **12 shipped responsive specs, 0 failures in Studio** (`responsive-inplace.result.json`); shared/lobby Selene 0 errors and warnings. Tests establish layout/state regressions, not device acceptance or production readiness. Physical phone, keyboard obstruction and controller acceptance remain outstanding.

Advisor reconciliation: Claude `claude-0d6dc37c-4fcc-4f8d-a132-bd3c15399102` approved the selected consequential source after receiving the actual safe-area hook and legacy TopBar branch. Its predecessor's double-inset concern was rejected using measured Core/Full/Device rectangles. Initial refinement Gemini `gemini-9c4ef63e-b6af-42a6-932e-3927cedd5893`: accepted wide intermediate Play, crowding and pale-body contrast findings, implemented here. Final palette run `gemini-0e87aba9-1152-45f7-aa46-13e8be30fa54` **APPROVED** without blockers. Its clipped seventh-day finding prompted the final full-week width threshold and fixed card heights, then fresh runtime captures. The daily horizontal cue followed personal inspection after that review. Reviewer descriptions of unprovided tablet evidence are not accepted as tested coverage.

### Popup color-role follow-through

The same roles now apply to DailyRewardModal, SeasonPassModal/SeasonRewardsPanel and the lobby PartyMembersModal. Reward/member surfaces use White and Ink; cyan remains framing; pink marks selected/primary actions; Back uses Ink. ShopPriceButton has optional text color/stroke presentation props with original defaults and disabled treatment retained. Reward, premium purchase and party callbacks/authority are unchanged. Existing identifiers and offerings are preserved.

Actual captures: daily desktop/phone `modals-color-final-4-0.png` / `modals-color-final-6-0.png`; party desktop `modals-color-followup-6-0.png`; season desktop/phone `modals-color-followup-9-0.png` / `modals-color-followup-11-0.png`. Comparable party/season baselines: `modals-before-color-3-0.png` / `season-modal-before-4-0.png`. Additional phone evidence: `modal-interaction-check-3-0.png` reward preview, `modal-interaction-maximized-3-0.png` premium reward tab, and `party-phone-native-2-0.png` party panel after native Show/Hide verification. Some intermediate capture requests returned successful input without activating the target; subsequent screenshots exposed this. Only the verified paths above are acceptance evidence. MCP input was inconsistent on some phone targets, including after maximizing Studio. Native Computer Use successfully returned from the reward preview/list and opened Party Code, then showed and hid its code. This distinguishes tool-input misses from verified UI behavior; no physical touch acceptance is inferred.

Gemini `gemini-af727774-b579-49a9-ba13-fc714bcad5f0` **APPROVED** this bounded palette milestone, with phone modal breathing room still requiring device acceptance. Accepted optional concern: compact cosmetic name badges can become tight; review this with the broader inventory/season device pass. This does not approve the full visual phase.

Known new finding V13: mobile modal dimming ends at the core-safe rectangle, leaving bright edge strips. This is now explicit remaining work, not claimed fixed. Existing root clipping and backdrop ownership need a coordinated solution across modal consumers. Roblox documents separate noninteractive ScreenGui content for backgrounds that extend beyond insets: [ScreenGui reference](https://create.roblox.com/docs/reference/engine/classes/ScreenGui).

Settings color roles and player-accessible attribution remain pending. The generated ThirdPartyCredits module still has no gameplay mapping/consumer; the existing scrolling Settings page is the discovered integration seam. Figma partial compositions still need native component work. No raster uploads were necessary for these flat React surfaces; custom content should use the installed gate when it improves actual production art.

### Previous direction checkpoint

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

Prior checkpoint: 738 headless tests passed (`headless-tests-final-gap.txt`); 9 shipped responsive specs also pass through the private Lune datatype harness (`run-responsive-spec.luau`). Shared and lobby Selene: 0 errors/0 warnings; changed-file StyLua and git diff checks pass. These do not establish input usability, remote teleport/payment behavior, persistence, or frame-time budgets.

Tested: Windows Studio desktop mouse/keyboard; phone emulator rendering, daily modal dismissal, Join opening/Escape; desktop progression wheel scrolling; intermediate Party Code open/Back; local mock respawn; synthetic party 1 -> 4 -> 1 projection. Studio MCP mouse-scroll input now moves the phone quest list and updates its cue; physical touch remains unverified. No physical phone/tablet, macOS, connected controller, or console tested. Tablet presets discovered but untested. VR excluded. Arena/results/long-error/progression/ownership/purchases and complete first/returning journeys remain pending.

## Workflow blockers and recovery

Figma canonical file qOQKzOXH6HIc8g1PHWvplh was initially empty. Partial editable desktop wrapper/nav 12:2, phone wrapper 12:3, component 12:12 and 6 source variables were created. **Starter-plan MCP quota exhausted; these are incomplete and not approval material.** Exact state `figma/checkpoint-state.json`. Native Chrome access was authorized and successfully used to inspect the same canonical file and edit both desktop and phone backgrounds to source Yellow. MCP quota is still exhausted; native editing is available, so no owner quota/billing action is required. The compositions remain incomplete. BuilderSans unavailable in Figma; Inter proxy explicitly labeled, final font truth is Studio.

Native Studio MCP and Computer Use worked. In-app browser runtime returned no available browser; after reading its troubleshooting guidance, the authorized Computer Use fallback successfully accessed Figma through the existing Chrome tab. Native Blender contains an unsaved owner scene, untouched; protect it before authoring. Media Player reference clip opened; no game assets imported.

Protected preexisting owner changes: deleted AGENTS.md, docs/RECOVERY.md, docs/SECURITY_AUDIT.md; modified docs/ART_STYLE.md. Exact initial patch `protected-work.patch`, baseline revision/status `baseline-git.json`. Exclude these from task commits.

Local test cleanup completed: simulator reset to default; lobby stopped in Edit; original saved PlayerData source restored and mock-disabled verified (`cleanup-responsive-checkpoint.result.json`). Source backup `ServerScriptService_Server_Modules_PlayerData.luau` is Windows CP1252. Repo PlayerData/Profile Template/Env unchanged; existing PrimaryDataKey remains STAGING_009. Namespace name alone does not establish isolation. No persistent storage test performed and no release configuration approved. Synthetic party packets affected only the local Play client and were discarded on Stop. Arena Studio remained Edit and untouched. No .rbxl edited or saved by repository tooling.

Next safe action: finish the current responsive checkpoint, then continue the recorded modal/tutorial/phone-input issues, complete canonical Figma compositions, and proceed through full visual scope and native Blender emote work. Direction is approved; completed-visual sign-off is still pending. Do not begin Phase II before separate completed-visual sign-off.
