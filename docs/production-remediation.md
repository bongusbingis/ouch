# Production remediation

Implementation ledger for the gameplay audit, production-QA extension, final Studio pass, and additive commerce work. Original finding statements below are preserved. Checked items have an implementation and targeted verification; they do not imply that platform billing, multiplayer, device hardware, or deployment acceptance has passed. Those release gates are listed separately.

Existing visual identity, state owners, authored assets, and unfinished-content exemptions remain constraints. Mobile acceptance now targets landscape only, as directed by the user; portrait architecture is retained.

## Execution order

1. Required Studio assets and readiness isolation.
2. Receipt durability and combat authority.
3. Movement, elimination, spawn lifecycle, and deterministic input.
4. Progression, entitlements, season, and claim reliability.
5. Match information and input/modal ownership.
6. Responsive geometry, settings, shop, presentation consistency, and preview coverage.
7. Repository checks, both in-place suites, and Studio regression checks.

## Original findings

- [x] F1: Receipt acknowledgement only after durable persistence; concurrent/retried receipts grant once.
- [x] F2: Validate charged throws against server-observed charging time.
- [x] F3: Reject combat/equip inputs from players excluded from the active round.
- [x] F4: Obstructions block catches.
- [x] F5: Jump-pad launches require contact with the pad rather than a remote fall ray.
- [x] F6: Remove jump-pad forces on elimination and lifecycle cancellation.
- [x] F7: An invalid catch must not consume the valid hammer action in the same tick.
- [x] F8: Unresolved paid entitlements must not silently underpay progression.
- [x] F9: Prevent expired-season prompts and honor delayed paid receipts.
- [x] F10: Provide a reachable season reward claim interaction (reward content remains exempt).
- [x] F11: Daily dialog dismissal, focus, back handling, and background input barrier.
- [x] F12: Buffer combat inputs only while their action is legal.
- [x] F13: Fully canonicalize input ordering, including same-player/same-kind ties.
- [x] F14: Release ragdoll state when players/characters leave.
- [x] F15: Bound and safely flush pending progression; expose persistence limitations.
- [x] F16: Retry failed season hydration without stale callbacks.
- [x] F17: Refresh daily/quest state across server-day rollover.
- [x] F18: Daily/quest claims expose pending, success, and failure states.
- [x] F19: Quest text and rewards remain readable at supported phone sizes.
- [x] F20: Party invite/join controls meet the configured minimum target size.
- [x] F21: Rate-limit before expensive validation and enforce declared action limits.
- [x] F22: Acquire platform carry from support contact, retain airborne carry from prior support, and cancel stale rides.

## Production-QA extension

- [x] A1: Remove player-facing settings examples and expose applicable real settings.
- [x] A2: Shop details focus falls back to an enabled action.
- [x] A3: Repair stale story fixtures and cover shipped missing/error/empty/disabled states.
- [x] B1: Apply the chosen full-page panel alignment consistently while retaining Shop width.
- [x] B2: Repair small sliders/toggles/shop/back/onboarding controls and reserve layout space for their targets.
- [x] B3: Render focus feedback for image-less buttons/toggles.
- [x] B4: Notification/join/crate modals share appropriate barriers and selection ownership.
- [x] B5: Notify settings subscribers when a profile replica arrives.
- [x] B6: Settings changes receive an acknowledgement and recover from rejected writes.
- [x] B7: Route UI feedback through the user's audio settings.
- [x] B8: Present shop refresh progress and failures.
- [x] B9: Give empty inventory categories an intentional state without treating unfinished content as a defect.
- [x] C1: Consolidate repeated design constants without introducing new colors.
- [x] C2: Resolve and apply the chosen Inventory/Settings title-bar treatment.
- [x] C3: Use consistent terminology and number/currency formatting.
- [x] C4: Restore visible crate reveal burst rays.
- [x] C5: Derive compact settings layout on the first frame; assess preview cost in Studio.

## Final Studio amendments

- [x] D1: Arena includes the existing CharacterRig preview asset; preview preparation cannot stall React effects.
- [x] D2: Restore the documented native ArenaSpawn and verify streaming/retry readiness.
- [x] D3: Present active match mode/objective, scores, clock, and respawn information from authoritative projections.
- [ ] D4: Resolve aerial-versus-ground spawn intent and validate overlap, rotation phases, and protection on landing.
- [x] D5: Inventory tabs/content do not overlap in short landscape.
- [x] D6: Daily reward header renders ahead of its background.
- [x] D7: Daily amounts and party code remain readable across device orientations.
- [x] D8: Native movement controls do not cover lobby menus and return for playable onboarding.
- [x] D9: Required shared UI asset contracts are checked in both places' in-place suites.

## Decisions

The user approved the existing combat intent/codec and acknowledged settings request paths with compatibility checks; bounded match-award records in PlayerData and season archives in BattlePassService with migrations/tests; and implementation judgment for spawn, alignment, HUD, and loading ownership while preserving the visual style. The implementation uses grounded spawns, consistently positioned page panels, authoritative match HUD projections, and the existing loading owner. Settings uses a transparent title background. Inventory retains its original charcoal title mask because the authored background image already contains a title; removing the mask produces duplicate text.

The user subsequently authorized complete existing-pass implementation, Effects Crate readiness, a crate-details redesign, and a justified Bonks pricing pass. These are additive amendments. Robux prices come exclusively from client MarketplaceService product information, including regional prices. Catalogs and stories contain no configured Robux prices or fallback amounts. Only Bonks pricing belongs in config. Numeric Marketplace responses in automated tests are fixtures, not player-facing price previews.

Each playtest was allowed to load before hiding the leaderboard. Native Tab worked in the lobby. MCP virtual input rejects that reserved CoreGui key, and native app selection could not reliably target the arena window; arena checks used a playtest-only PlayerList hide. No production leaderboard behavior was changed.

## Implemented behavior and evidence

### Persistence and progression — F1, F8–F10, F15–F18

- MonetizationService serializes receipts per player, journals individual subgrants and the grant payload, resumes partial bundles, and acknowledges only after PlayerData observes the receipt in LastSavedData. Grant/reveal events follow that durable confirmation. Unknown products and save failures remain retryable. Shared engine regressions cover concurrent receipts, unsaved grants, partial retries, and session loss.
- PlayerData owns versioned pending match awards, bounded at 64 pending and 128 completed records. MatchAwardService resolves boost amounts once, commits career and original-season progress once, and retries recovery in both places. Unresolved entitlements keep awards pending. Capacity exhaustion excludes further earning rounds and exposes recovery status rather than silently dropping progress.
- BattlePassService retains up to 64 season archives, protects unsettled paid claims, and resumes only missing tier grants. Expired products cannot start new prompts; delayed receipts settle against their original season. Migrations, partial commits, rollover, and delayed settlement have automated coverage.
- Season claims are reachable from the splash card. Season, quest and daily stores use bounded requests, retry hydration, refresh across rollover, reject stale responses, and expose claim progress/failure. Settings tests independently cover acknowledgement races and replica arrival.

### Combat and movement — F2–F7, F12–F14, F21–F22

- Server-observed charge uses the existing intent path and codec. Full charge requires elapsed server charging time; legacy/forged release values cannot create charge. Death, weapon/context changes, cancellation, and loss of possession clear it. Excluded players cannot submit combat or equip actions. Catch line of sight, invalid-catch action budgeting, legal input buffering, canonical ordering, and early rate limiting have regressions.
- Actual Studio hold/release recorded 0.7 seconds of server charge and a normalized release of 1. A direct forged full-charge release without BeginCharge recorded 0. An excluded-player combat/equip attempt produced no release and retained Dodgeball. Desktop right-click cancellation cleared charge and produced no throw after left release. A right-click cancellation attempt in the touch simulator was not used as desktop-input evidence.
- Platform carry requires real support contact. Airborne continuation requires prior support and has height/time bounds; elimination, root replacement, teleport discontinuities, anchoring, and oversized deltas cancel it. Carry applies position only in the horizontal plane.
- The reported elevated-hover reconstruction reached the floor in Running state with zero lateral drift. A real standing/jumping platform ride retained relative position within approximately 0.152 studs and landed in Running state.
- Jump pads now require contact, and float forces use world coordinates with bounded lifetime and lifecycle cleanup. A live drop did not launch at the old remote-ray heights; it launched at contact and retained its force through the airborne arc. A startup FloorMaterial lag found during QA was fixed and rerun successfully. Elimination during an actual boosted jump removed both force and attachment. Ragdoll removal/state restoration has engine coverage.

### Player UI and interaction — F11, F19–F20, A1–C5, D3, D5–D8

- Real settings replace example rows; writes acknowledge accepted values, serialize rapid commits, and recover from rejection. Shared UI feedback respects the user's audio settings. Focus is visible on image-less controls, modal barriers prevent background activation, and layered close/focus behavior is retained.
- Shop details now uses reward-focused copy, rarity groups, per-item next-open odds, pity guarantees, owned-item refunds, and single/batch Bonks or single Robux actions. Restricted/unresolved policy or inactive cards disable purchase actions, including when a modal is already open. The server checks policy again.
- The modal focus repair coalesces callbacks and yields between frames, ignores hidden/disabled ancestors, and respects a higher ScreenGui display order. The preview focus loop that stalled Studio was reproduced after the fix with two competing dialogs: higher-dialog selection, trapping, and restoration all passed. Temporary test roots were removed.
- Short landscape geometry reserves full 44-pixel targets and complete content rows: navigation labels, horizontal splash actions, daily rewards, party code, quest title/progress/reward, inventory tabs/cards, settings label/description/control, shop cards, and crate odds/actions. Phone checks used a 666×374 viewport with approximately 316 pixels of usable vertical space. The existing portrait branches remain intact.
- Latest live lobby screenshots cover splash, inventory, settings, shop and Effects details; arena screenshots cover authoritative HUD, shop and settings. Shop also passed visual checks at 1365×768 desktop and 1375×1032 tablet viewports. These are Studio viewport checks, not hardware performance measurements.
- The match HUD derives mode, objective/target, score scope, score, clock, respawn deadline and recovery/exclusion information from authoritative projections. FFA copy now states the actual first-to-15 objective. Repeated number grouping is shared through NumberText, including purchase/reveal and post-match totals.
- Lobby TouchControlsEnabled was false in the menu, true after starting playable onboarding through its existing service, and false after cancellation returned to the lobby. No stock control-module internals were changed.
- Stories now cover combat menu, economy modals, onboarding, settings controls, daily/quest states and match HUD. Shop fixtures cover loading/refresh/error/empty/unavailable/restricted states; details cover guaranteed, pending and unaffordable states. ShopPage, ShopDetails, EconomyMenuModals, CombatMenu, SettingsControls, MatchHUD and CrateReveal mounted/unmounted in a normal client context with no React/runtime errors. Story price metadata is omitted rather than fabricated.
- Inventory preview preparation is deferred outside React effects. Previews share a capped update loop and pause when hidden, disabled, clipped or offscreen. A live probe measured two visible preview objects moving, then zero moving after disabling their ScreenGui. All 13 shipped script impact effects executed through CosmeticEffectFactory without warnings; after eight seconds, active animations and temporary instances returned to zero and the update loop stopped. Generic effect/sound badges remain category representations, not exact effect recordings.

### Authored assets and readiness — D1–D2, D4, D9

- The existing lobby CharacterRig was copied into the arena through Studio. Shared preview asset contracts are mapped to both places. Required asset existence remains asserted rather than silently hidden.
- ArenaSpawn was restored as a neutral, enabled native spawn on the permanent map. Fourteen FFA/team spawn markers were grounded in Studio. Each marker was tested individually: Running, root approximately 2.622 studs above the floor, and zero lateral drift. ArenaService chooses the greatest available clearance from live players and clears velocity on teleport.
- Loading retry restarts streaming/preload work under a new generation while retaining initialized UI, vote and simulation ownership. An isolated copy of the real loading owner was forced through initialization timeout, retried, and recovered with UI/simulation flags preserved and stream/preload readiness true. The production owner and its listeners stayed intact. Real streaming outages and lobby-to-arena arrival remain staging gates.
- D4 remains open only for occupied multiplayer spawn/rotation/protection acceptance. The grounded-spawn implementation and individual marker tests are complete.

## Validation results

- [x] Headless: **655 tests, zero failures**. Baseline was 626 tests with six existing failures.
- [x] Selene: shared, arena and lobby — zero errors, warnings or parse errors.
- [x] StyLua: shared, arena and lobby checks pass.
- [x] `git diff --check` passes.
- [x] Arena Studio engine subset: **180 passed, zero failed**.
- [x] Lobby Studio engine subset: **26 passed, zero failed**.
- [x] Targeted Studio movement, charge, exclusion, cancellation, loading recovery, onboarding-control, modal-focus, preview cleanup and landscape UI checks described above.
- [ ] Full saved-place cloud suites for both deployment artifacts.
- [ ] Multiplayer/network/real-device/platform-purchase/teleport release matrix below.

The Studio subset excludes Environment, BallService and MatchServiceSmoke. Those tests require an isolated server with no live player/match; Environment additionally asserts a non-running server context. Studio Edit MCP reports a client/player context and is not an equivalent substitute. No tests or environment assertions were weakened to make this subset pass.

Four baseline failures were catalog gaps: the omitted exclusive collection mapping, its preview definition, the inactive valid Effects product, and that product's receipt routing. The other two asserted a configured Robux price ladder or a cosmetic pass at each booster price point. Those assertions were stale under the user's explicit Marketplace/regional-pricing requirement; they were replaced with no-configured-price and concrete-entitlement assertions. Existing product identities, exclusivity and grant validation remain tested.

## Additive commerce amendment

- [x] E1: Reconcile configured passes with Marketplace, complete grants/retry/boost behavior, and document missing platform/content setup.
- [x] E2: Activate the valid Effects Crate product and verify pool visuals, equip/reveal, duplicates, pity, receipt durability, and policy restrictions.
- [x] E3: Redesign crate details around rewards, clear odds/guarantees, responsive controls, focus, and actual next-opening probabilities.
- [x] E4: Model Bonks sources/sinks and update balance with justification while preserving existing balances and product reward identities.
- [x] E5: Remove configured Robux amounts and test client Marketplace prices, missing metadata, off-sale products, and changed regional amounts.

Marketplace read-only checkpoint (September 6, 2026): all three existing real passes report off sale. EffectsCrateOpen is live in the correct universe and its code status is now Active. Effect Collection has an explicit three-effect grant and remains Preview until a real platform ID is supplied. No platform sale settings or Robux prices were changed.

The Bonks implementation and before/after justification are in [economy-balance.md](economy-balance.md). New profiles start with 1,000; match completion/win awards are 75/100; Effects costs 500 before the featured discount; guaranteed Common/Rare/Legendary items cost 1,000/2,500/7,500. Existing balances and paid-product grant quantities are preserved. The still-active live Effects price override is 750, so its featured price observed in Studio was 637. Releasing the baked 500/featured 425 balance requires updating or removing that override.

## Release gates

1. **Saved assets and deployment:** retain/save the authored arena changes from Studio, then run both full saved-place cloud suites against the actual merged deployment artifacts. The repository contains no rewritten place binaries. Nothing was published or committed during this task.
2. **Platform setup:** put the three existing passes on sale with intended Marketplace descriptions/prices, if ready to sell them. Supply an Effect Collection ID only if that preview should launch. Update/remove the live Effects Bonks override for the new balance. These are platform configuration steps, not source-code price edits.
3. **Billing and policy:** exercise real duplicate/retried receipts, interrupted grants, pass purchase/rejoin reconciliation, regional Dynamic Price Check settings, off-sale behavior, and eligible/restricted accounts in an isolated staging experience. Fixture success is not a real-money billing result.
4. **Multiplayer and persistence:** run occupied/near-simultaneous spawns, team waves, every mode, player departure during Results, reward recovery after cross-place rejoin and server shutdown, and lobby→arena→lobby party return. Confirm landing protection and platform carry at multiple rotation phases with nearby players. This closes D4.
5. **Latency and assets:** repeat combat, elimination/effect dedup, loading/streaming retry, and teleport recovery at 0/100/150/200 ms latency, including missing/late characters. Listen to the configured sounds and inspect impact effects in actual multi-player combat.
6. **Hardware/input:** validate touch and gamepad navigation/focus, text preferences/reduced motion, supported notched landscape phones, and low-end CPU/GPU/memory budgets. Studio's preview cleanup test does not establish a frame-time budget. StarterGui currently reports Sensor; apply the intended landscape orientation lock as a release setting without deleting portrait code.
7. **Economy measurement:** review the earn/spend, wallet, duplicate, pass fulfillment and retention cohorts listed in [economy-balance.md](economy-balance.md) before further price tuning. Season reward content, costumes and emotes retain the user's unfinished-content exemptions.

## Workspace handoff

The existing dirty working tree was preserved; its starting patch is `/tmp/ouch-remediation-start.patch`. Final headless output is `/tmp/ouch-remediation-tests.log`. Both Studio windows are in Edit mode and both device simulators are reset to their default viewport. Temporary verification scripts, cloned loading owner and preview roots were removed. Authored asset changes remain in the open Studio edit data model; save/publication/import are still the release steps above. The user's `.rbxmx` asset was not read or modified.
