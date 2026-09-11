# UI/UX redesign completion — 2026-09-10

The seven-item redesign is implemented, including the work left dormant by Fable. The two Figma panels and both licensed icon atlases were approved by the owner through the installed asset gate, moderated, and integrated under group **291738800**. This is an implementation and verification record, not a release approval.

The approved plan remains `.review/production/2026-09-10-redesign/plan.md`. The live style reference is [DESIGN_TOKENS.md](DESIGN_TOKENS.md). Original Figma sources and provenance remain under `assets/source/figma/`. The low-fidelity seven-item mock is `completion/approved-layout-mocks.png` under the evidence directory below.

## Delivered scope

| Brief item | Final behavior |
| --- | --- |
| 1. Shop | Header toolbar, Bonks balance and Get Bonks action; storefront inside a designed well. Existing Passes, Featured, Crates and For You cards remain as approved. |
| 2. Mode selection | Generic avatar viewports removed. FFA, TDM and configured-but-disabled Infection each have their own labelled artwork binding with the requested `123456789` stub. VOTE uses the shared Control radius. Count badges and labels reflow on short landscape and portrait. |
| 3. Live standings | Compact leader/top standings plus your highlighted row; leader crown and proportional team scores. Short viewports show at most two rows. Hold Tab/Select opens the full board without unlocking the cursor. Release, text focus and window focus loss close it. Touch has the strip target and a 44 px close control. All 20 fixture rows remain reachable on small screens. |
| 4. Corner/slice consistency | Page R16, controls R12, nested tiles R8; common page/well slices at 0.5 and existing action slices at 0.09. Remaining old page images in shared modals now use the page token. Crate reveal uses the shared close control, white outline and outlined title/name. |
| 5. Inner containers | Approved Figma Well applied to Shop, Backpack, Settings groups, quests, daily rewards, party code/members, Join entry, season preview/status, crate preview/odds and arena standings/scoreboard. `WellScroll` leaves artwork fixed while content scrolls. |
| 6. Reward/effect icons | 22 licensed semantic icons replace procedural effect/sound glyphs throughout Backpack, crate odds/preview/reveal and season rewards; quest definitions use the same icon registry. Existing skin/outfit 3D previews are retained. |
| 7. Quests | Blue header, themed icon tiles, shared wells and Tile-radius rows. Portrait home spacing no longer collides with the play/status area. |

Simple native controls, transparent overlays, small rows, progress fills and circular emote geometry retain native rendering where the simple geometry is equivalent. This is not a claim that every native UI instance was removed. Shop offer card presentation is intentionally preserved by item 1.

## Approved assets and reproducibility

| Artifact | Approved Decal ID | Verified Image texture ID |
| --- | --- | --- |
| Page panel | 131449610091380 | 125378628790140 |
| Inner well | 74795093768394 | 138307870774315 |
| Phosphor atlas, 19 icons | 130070129394053 | 125312270475689 |
| Material Symbols atlas, 3 icons | 109049105652853 | 105358867565806 |

Gate request IDs and SHA-256 records are retained in the asset manifests. Studio `InsertService:LoadAsset` readback verified each approved Decal's underlying `Texture`; UI binds those Image IDs. All four uploads reached approved/complete states. Their creator is the user-selected group, 291738800.

`tools/prepare_redesign_assets.py` reproduces atlases, provenance and credits. `tools/sync_redesign_assets.py` refuses stale/unapproved bytes or a Decal/texture mapping that does not match the approved record. It generates `RedesignArtwork.luau` and the canonical semantic registry. Phosphor uses MIT; Material Symbols uses Apache-2.0. Original SVGs, notices, hashes and generated in-game credits are retained.

The gate initially failed to recognize the API's `Approved` spelling, documented in the [official Assets v1 schema](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/cloud/assets/v1.json). A narrow normalization now accepts known moderation spellings, leaves unknown states pending, and never treats approval without an asset ID as complete. Two regression tests cover this. The installed gate was updated; existing known operations were resumed without uploading duplicates.

Regenerating the four production PNGs preserved every approved SHA-256. An isolated binding probe accepted the verified Image IDs and rejected stale bytes, pending moderation and a mismatched Decal mapping; `completion/binding-validation.json` records those checks.

## Verification and evidence

Evidence root: `.review/production/2026-09-10-redesign/completion/`. Open `index.html` there for the screenshot gallery. Captures are native Studio screenshots, not composited mockups.

| Check | Result / scope |
| --- | --- |
| Headless game suite | **774 passed, 0 failed**; `lune-final.txt`. |
| Offline workflow tests | **50 passed**, including all eight gate transport/moderation regressions; `workflow-tests-final.txt`. No credential or production-transport test. Asset validation also passed. |
| Selene | **0 errors**, 0 parse errors; two pre-existing shadowing warnings in `test-crate-services.luau` at lines 79 and 274; `selene-final.txt`. |
| StyLua | Changed Luau files pass. A whole-repository check exposes existing formatting/line-ending differences outside this scope; the repository was not reformatted wholesale. |
| Desktop Studio | 1920×1080 Shop, Backpack Effects, Settings, quests/home, crate odds/reveal, Party, Join, Season, Daily, FFA/TDM boards and mode selection inspected. |
| Phone Studio | Landscape 832×419 and 667×375; portrait 440×860 viewport / 440×956 capture. Fixed label overlap, home overlap and scoreboard overflow during the screenshot/edit loop. |
| Input | Actual desktop Tab hold/release leaves `MouseBehavior=LockCenter`; text-box focus closes the board. Actual desktop vote click changes the selected mode through its callback. Actual Open 1 click spends 750 mock Bonks (1000→250) and opens an icon-backed reward reveal. No Robux purchase was invoked. |
| Long content | Twenty synthetic standings, long display name, tied scores, local player outside the top ranks, respawn labels, and bottom-of-scroll visibility checked. |

Lobby navigation fixtures invoked the actual application's state setters. Arena fixtures mounted the real UI components with synthetic standings; these are not 20 connected players or a multiplayer capacity test. Desktop vote previews can show the underlying active-match toolbar/menu because the fixture did not replace the server phase. Small-phone final vote was captured during initial voting. The fixtures do not establish server vote or matchmaking behavior.

Capture-time source hashes and normalized Studio readbacks are retained in `final-source-proof.json`, `source-list.json` and the review packets. CRLF and trailing whitespace are normalized only for Studio source equality. Final formatting changed two files without changing behavior; the arena packet uses fresh captures and updated hashes after formatting. Earlier screenshots retain their original provenance.

Portrait was tested by temporarily selecting Sensor orientation. Both places are restored to their existing **LandscapeSensor** setting. Physical touch/gamepad, window focus-loss input, every hover state, real profiles/receipts and published-server behavior were not verified by this pass. The Studio input bridge could not inject the required controller/touch events; those are explicit coverage limits, not passes.

## Review and handoff status

Gemini milestone review was attempted twice for the lobby and once for the arena. All three returned **503 UNAVAILABLE**, without a verdict. Failed records are `.review/gemini-9688b754-7b32-448f-aa73-b65a53e872e5`, `.review/gemini-fe829b06-372e-41a5-a5b8-7ab6f3285471` and `.review/gemini-8e48b8ce-6701-4624-be98-8b9b1bec3a58`. `completion/lobby-review.json` and `completion/arena-review.json` contain the reviewable cases and named comparators, ready to rerun when the service is available.

There is no final owner visual acceptance and no full release-purpose advisory pass. [VISUAL_REVIEW.md](VISUAL_REVIEW.md) therefore still blocks a release claim; this record does not supersede unrelated release-candidate issues. Mode key art remains a labelled stub exactly as requested.

Both Studio sessions were stopped; temporary navigation/render fixtures and local texture previews were removed. `Debug.MockProfiles` is false. Source overrides were restored to repository code, approved Image IDs remain wired, and device simulation was stopped. No place publish, push or deployment was performed.

Implementation commits on `tooling/agent-workflow`: `2e319b1` (approved assets, provenance and gate compatibility) and `628ab92` (UI integration and responsive/input fixes). Fable's original implementation commits remain intact. The unrelated `.claude/` directory is left untouched.
