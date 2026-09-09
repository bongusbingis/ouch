# OUCH production readiness — implementation specification

Prepared 9 September 2026. Target: **Saturday, 12 September 2026; 30,000–50,000+ concurrent players**, as specified by the owner. Launch hour and physical test hardware remain unconfirmed. This is a planning deliverable; no gameplay, assets, deployment, or fresh runtime acceptance was completed by preparing it.

## 1. Mandate, priorities and authority

The next GPT-6 Astra task is the authoritative project lead: planning, architecture, implementation, orchestration, Git, Rojo, reviewer reconciliation, final technical decisions and final art direction. Execute this spec through the existing project owners and workflow. Do not spend the next context window reconstructing the conversation or researching token routing.

**Engagement, retention and monetization are the highest product priorities.** Translate those priorities into a satisfying first match, responsive and readable play, reliable parties/replay, desirable finished content, understandable progression, honest purchasing and durable rewards. Reliability, accessibility and scale are prerequisites for those outcomes. A test count or attractive screenshot does not establish success, profitability or readiness for this audience.

Use the craft expected of a senior engineer, UI artist, UX designer and creative director: coherent presentation, deliberately authored content, robust state ownership, measured performance, failure recovery and evidence tied to the actual release. “AAA” is a quality standard, not authorization for a new engine, wholesale rewrite, or a promise of commercial success.

**Delivery rule from the owner's latest clarification:** ship the best player experience as soon as possible using the smallest readable implementation that works reliably at the expected traffic. Pragmatic duplication, a direct conditional, a local adapter or an imperfect existing pattern are acceptable when they save time without meaningful player, purchase, data or operational consequences. Invisible code elegance does not need the same polish as gameplay/UI. Do not turn general best practices, architecture purity, blanket type cleanup, coverage percentages, exhaustive test permutations or marginal optimizations into release requirements. Fix demonstrated defects and credible high-impact failure paths; stop expanding backend work once that evidence is sufficient. Explain a proposed refactor in terms of the specific player failure it prevents, why a smaller fix is insufficient and the time tradeoff. UI/content implementation must run alongside the narrow integrity/capacity work from the first implementation day.

### Scope and previously settled decisions

- **UI and UX remain fully in scope**, including redesign where inspection shows a real production benefit. The approved lobby is the accepted baseline; fix remaining inconsistencies and player friction throughout the game. Do not redesign accepted work for novelty or classify unreviewed screens as approved.
- **Gameplay and content creation to fill existing gaps are in scope.** Bring smaller authored arena elements to life, improve primitive interaction/feedback, rebuild the existing emote performances, and create assets when they improve quality. Do not reduce this to an infrastructure audit.
- **The human-authored static arena layout is protected.** Preserve its course composition and strong mesh/texture art. This does not prohibit intended movement, interaction, local effects or improvements to individual smaller features. Material changes to the static layout/art or fundamental gameplay need owner direction.
- Fall Guys remains the sole high-level visual reference: saturated toy materials, strong silhouettes, rounded forms, playful motion and clear interactions. Create original work; do not copy its protected characters, branding, icons or exact layouts. Epic Games is the requested production-quality comparison, not a second visual direction.
- Bonks pricing, emote rarity, release catalogue and crate configuration are in scope when justified by actual earning/drop rules. Preserve existing game passes and developer-product identities/promises. Inspect and verify their benefits; **do not assume they are complete**. Creator Hub commercial setup, new/repriced/repackaged offerings and real purchases remain owner work. Ask with a concrete finding when a necessary correction crosses this boundary.
- The owner approved the previous visual review. Do not request that same approval again. Material new/changed visual surfaces receive focused review; final release acceptance still requires current evidence for the whole candidate.
- Local source, tests, fixtures, builds and commits are authorized for the implementation phase. **All pushes, release PRs, staging/production deployments and place publishing are owner-only.** Preserve existing place CI. Standalone asset uploads use the installed human approval gate; bring every request window forward and refocus it. Never click production approval or bypass the gate.
- PC access is authorized for the established workflow. Protect unsaved Studio/Blender work. If a necessary PC operation falls outside that workflow, ask what is needed and why. Unavailable tool capability is a real blocker even with user permission; record it and continue independent work.
- Earlier `AGENTS.md` instructions were revoked. Do not restore them or retrieve their Git version as instructions. Preserve the owner's current deletions and `ART_STYLE.md` changes.

### Source of truth for this continuation

Workspace: `C:\Users\jackc\Desktop\ouch`; current branch `tooling/agent-workflow`. Approved source revision: `faedbc3cd4be7b0e5a4a521511b30fdf3e3687f2`; handoff record followed in `8cdd931`. Reconfirm current Git state before work.

Read this spec, [RELEASE_HANDOFF.md](RELEASE_HANDOFF.md), [ART_STYLE.md](ART_STYLE.md), [TOOL_ROUTING.md](TOOL_ROUTING.md), [VISUAL_REVIEW.md](VISUAL_REVIEW.md), [ASSET_PIPELINE.md](ASSET_PIPELINE.md), then selected source for the assigned package. The historical issue ledger is [VISUAL_RELEASE_AUDIT.md](VISUAL_RELEASE_AUDIT.md). The long original requirement is `.review/visual-release/original-request.md`; consult relevant sections if needed, rather than rereading the entire old task. Later owner directions captured here supersede stale references to Figma MCP, medium Claude effort, a still-pending initial visual checkpoint, or the old relative “48 hours” date.

Do not stage, restore or overwrite these pre-existing owner changes:

```text
 D AGENTS.md
 M docs/ART_STYLE.md
 D docs/RECOVERY.md
 D docs/SECURITY_AUDIT.md
```

## 2. Baseline and confidence

| Area | Established evidence | What remains unproven |
| --- | --- | --- |
| Lobby visual baseline | Owner-approved comparison at `.review/visual-release/comparison/index.html`; exact approval and screenshot hashes in `owner-visual-approval.json` | Other screens/states, physical devices, content and full release acceptance |
| Buttons/logo | White lettering on cyan Join/Invite; larger pink Play; matched sliced corners; measured visible logo crop and optical alignment | Regression at new sizes/states or after shared changes |
| Historical checks | 48 Python regressions and 745 Luau tests passed at the approved checkpoint; relevant Selene/StyLua passed | Current implementation and published-service acceptance; prior 12 Studio responsive specs predate the final captures |
| Services | Party/claim recovery, admission/readiness, ProfileStore sessions, receipt save-before-ack, policy gating, reward journals and analytics already exist | Fault, contention, shutdown, actual payment and large-scale behavior |
| Authored places | Lobby ID `130584867985467`; arena ID `121997450145716`; both last left in Edit | Current Studio instance IDs, saved base provenance, published versions and capacities |
| Local full builds | Builder requires one complete base `.rbxl` in each place directory | **Neither base exists in this checkout.** Full release artifacts cannot yet be reproduced from it |
| Content | Static arena art is strong; existing Wave and three Showtime entries have procedural preview/podium motion | Polished authored emotes, completed fans/spinners and every production asset permission |
| Devices | Studio captures at desktop 1246×841, phone 874×402 with smaller core-safe area, 1280×720 and 568×320 | Physical phone/tablet, real controller/console, mobile keyboard and sustained device performance |
| Data cleanup | `.review/visual-release/consistency-pass/cleanup.json` and `restored-player-data.luau` record mock removal and exact source restoration | Real persistence validation and owner-confirmed release namespace |
| Advisors | Earlier useful reviews and dispositions retained | Latest Gemini attempts returned 503; latest Claude max attempt timed out at 900s. Neither is a current pass |

Keep distinct statuses: **source-confirmed defect**, **source risk needing reproduction**, **historically runtime-verified**, **implemented**, **visually reviewed**, **owner approved**, **asset ready**, **release verified**, **blocked**. Do not compress these into a misleading green checkbox.

## 3. Fixed delegation and tool ownership

Use **GPT-6 Astra, Extra High (`xhigh`)** for the lead task. This is a recommendation for the combined visual, systems and scale reasoning here; it is not an instruction to maximize reasoning on every mechanical edit. The setting is supported by the [official Astra model reference](https://developers.openai.com/api/docs/models/gpt-6-astra).

| Responsibility | Assigned owner / route |
| --- | --- |
| Every visual review, design judgment, ambiguity and strong reasoning task | Astra, with relevant independent advisors; implementation size does not make visual judgment trivial |
| Precisely specified edits, file preparation, straightforward inventories and mechanical checks | GPT-5.3-Codex-Spark when exposed; otherwise disclose a lightweight-model substitution. No model-availability research detour |
| Architecture, networking, replication, persistence, transaction correctness, difficult debugging, risky refactors | Claude **subscription CLI**, advisory only, **max** effort through `tools/reviewer.py claude` |
| Consequential UI, artwork, animation/3D/VFX, consistency and source-versus-Studio visual reviews | Gemini through `tools/reviewer.py gemini`; advisory only |
| UI/HUD/menu design, components, tokens, 2D assets and particle art | **Figma through direct browser/Computer Use. No Figma MCP.** Canonical file: [OUCH Figma](https://www.figma.com/design/qOQKzOXH6HIc8g1PHWvplh/Untitled) |
| Modeling, animation, materials, UVs, collision, LODs, exports | **Native Windows Blender through Computer Use. No Blender MCP or headless fallback** |
| Actual integration, gameplay, devices, asset appearance and final runtime truth | Roblox Studio MCP against the explicitly identified place |
| Asset-content upload | Installed external gate with the owner's exact frozen-content approval |
| Deployment/commercial configuration/final launch | Owner |

Claude/Gemini never receive repository write authority. Send selected files/diff/test output or concise visual packets, not the whole repo. Claude uses installed `claude -p`, stdin, a fresh neutral directory and the wrapper's verified isolation options; never `--bare`, Anthropic SDK, or PAYG credential lookup. Child environment removes `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN`. Keep max effort; do not reduce advisor depth/cadence to save Codex usage.

`tools/workflow.json` currently sets Gemini `gemini-3.7-flash`, Claude max, 900-second timeout and a 250,000-byte packet limit. Gemini uses `google-genai` and keyring service `roblox-agent-gemini`, username `api-key`. This is the established usable configuration, not a claim that the Google subscription guarantees API Pro quota. Do not silently change models or credentials.

Run technical reviews at service-contract/fault-test milestones and final integration. Run visual reviews on coherent screen/content batches with desktop and mobile context. Tiny specified corrections still get Astra's actual Studio inspection and peer comparison, then join the next meaningful advisor milestone. If reviewers fail, retain request/result state, give a bounded fresh attempt on a relevant new packet, continue independent work, and report unresolved review coverage. No blind repeated submissions or fabricated approvals.

Use bounded parallel agents for independent service/content/economy analysis or nonconflicting implementation. One agent owns each shared edit; one driver controls the desktop. Give each agent exact deliverables, paths, acceptance and exclusions. Astra reconciles their findings. Do not launch idle agents or turn every lookup into delegation.

Figma already contains partial editable compositions/components; inspect before creating more. Use native components, variables, styles and auto-layout; synchronize changed canonical designs with actual Studio results. Blender must be inspected visibly, saved early under `assets/source/blender/`, saved at meaningful milestones and reviewed after consequential actions. Deterministic Python entered through Blender's visible UI is allowed. Export to `assets/models/`; preserve the owner's scene. No claim of a successful click, export or animation without verification.

## 4. Launch capacity contract

### Demand model to establish immediately

Configured match capacity is 20, party size 1–4; FFA and TDM are enabled, Infection disabled. At full arena occupancy, 30k–50k arena players represent roughly **1,500–2,500 simultaneous arena servers**, before lobby population and underfilled matches. This is arithmetic, not a verified platform allocation or the actual population split. Check published place capacities, spawn counts, eligibility and protocol compatibility.

The queue uses one `AllPlayers` sorted map and a global worker lease. One `_process()` creates one match while doing sequential cloud operations. The lease expires after 10 seconds without renewal; candidate prefix is 100, claims 30 seconds, polling 2 seconds. Conditional party claims already mitigate races. Multiple lobby workers and queue-change callbacks mean **2-second polling is not a global hard throughput cap**.

Same-arena **PlayAgain can retain eligible players and bypass the global queue**. FindMatch returns through lobby queue-on-arrival. Measure the actual path mix; do not equate CCU directly with queue demand. Use `queue arrivals/sec = global requeue population / mean requeue interval + fresh queue entries/sec`, with separately measured terms.

| Illustrative all-player global-requeue scenario | Players entering queue/s | Full 20-player matches/s | Maximum ideal mean serialized time/match, before headroom |
| --- | ---: | ---: | ---: |
| 30k every 10 minutes | 50.0 | 2.50 | 400 ms |
| 30k every 5 minutes | 100.0 | 5.00 | 200 ms |
| 50k every 10 minutes | 83.3 | 4.17 | 240 ms |
| 50k every 5 minutes | 166.7 | 8.33 | 120 ms |

These are scenarios, not measured round/session lengths. At twice the last scenario, demand is 333.3 queue entrants/s or 16.67 full matches/s: only 60 ms ideal serialized time per match. A 50k-player arrival ramp over ten minutes alone represents 83.3 fresh arrivals/s before measuring how many queue. Include bursts and fresh arrivals explicitly; do not double-count them or claim synthetic traffic is real CCU.

**P0 decision:** measure the existing critical section, request units, lease contention, queue age and assignment rate before selecting batching, renewable leases or partitioned workers. If measured serialized work cannot meet the envelope, implement a bounded scaling change through existing repositories and party authority, with Claude review. A renewal improves exclusivity, not throughput. A shorter poll alone does not remove serialization. Any partition design must specify party affinity, fairness, cross-partition handling, stale-ticket recovery and mixed-version compatibility before code.

Budget MemoryStore across candidate rows read, party/presence refreshes, claims, worker contention, records and retries. Roblox documents a universe-level allowance of `1000 + 120 × CCU` request units/minute; returned range items and some operations consume multiple units, and structure/partition limits also matter. A large aggregate quota does not prove a hot queue key is safe. Use current dashboard limits and measured operations. [Memory stores](https://create.roblox.com/docs/cloud-services/memory-stores)

Build equivalent budgets for DataStore/session saves, MessagingService topics/subscriptions/publications, teleport reservation and analytics. `UpdateAsync` consumes read/write budgets and failed writes can have ambiguous commit outcomes; blindly replaying grants is unsafe. [DataStore limits and errors](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits)

### Initial measurement targets — confirm against the actual experience

These are **proposed probes, not established product requirements, measured results or universal AAA standards**. Establish a quick baseline on the intended devices and a credible traffic mix, then record the useful targets for this release. Do not spend days building a benchmark platform or block launch over an arbitrary count. A visible hitch, stuck flow, sustained leak, incorrect reward or demonstrated inability to handle the stated traffic matters; an unexplained numeric threshold does not. Do not reinterpret a real failure as a pass merely to hit the date.

- Queue: at the agreed steady arrival envelope with sufficient population, p95 assignment ≤15s and no continually growing backlog; low-population cases follow the existing 0/8/16/24/30s expansion and distinguish waiting for players from a stalled worker. A five-minute 2× burst must drain within five minutes after normal load returns. Zero duplicate active assignments, lost valid tickets or permanent starvation.
- Per-server gameplay: full 20-player target with all release features active; server p95 simulation/frame work within 16.7ms and no sustained dropped simulation. Record p99 and longest stalls. Target desktop 60 FPS and the agreed lower-performance physical phone 30 FPS, using frame-time distributions and sustained play rather than an idle average.
- Reliability: every retained player has a bounded loading/teleport/purchase recovery path. Define explicit attempt and overall deadlines at the owning service; initial UX target is useful feedback immediately and an actionable recovery option within 30 seconds of a stuck transition. Do not force a 30s platform retry when the preceding teleport may still be active.
- Endurance: begin with a representative sustained session (provisionally 60 minutes) and repeated round/preview/modal cycles sufficient to reveal accumulation; extend only when a finding warrants it. No crash, stale control/camera owner, accumulating connections/rigs/effects or sustained memory growth after caches warm. Record actual duration/cycles and counts; expected asset caching is not automatically a leak.
- Network: baseline, 100/200ms measured RTT, then a documented jitter/loss case (provisionally 30ms jitter/1% loss). Record whether simulator controls specify one-way delay or RTT. Authoritative outcomes must remain coherent; cosmetic packet loss must not decide scores/rewards.
- Loading: provisional usable-lobby targets ≤10s cold and ≤5s warm on an agreed device/network; separate download time, profile load, assets and scene readiness. Failure must preserve recovery even when these targets cannot be met.

Use existing test seams for a bounded deterministic/fault harness at the agreed credible demand mix and burst; the illustrative table does not require four separate scale projects if actual replay behavior rules scenarios out. Corroborate timing and operation costs in an owner-deployed isolated published environment; do not flood live services or create fake accounts to imitate 50k players. A one-PC simulation cannot certify 50k real clients. Final recommendation must state the highest tested envelope, platform-dependent uncertainties and an owner-controlled rollout/hold strategy.

## 5. Work packages and acceptance

P0 means release-blocking integrity, core access or capacity work. P1 means launch content/quality; **P1 is not permission to defer owner-requested content**. R13 explicitly separates optional deeper measurement from its launch essentials. New optional features are P2 only after explicit triage. Each required package needs adequate evidence or an owner-recorded scope decision, not an enterprise-grade subsystem or every conceivable test.

### R01 — Reproducible candidate and environment identity — P0

**Deliver:** identify current Studios, source/base provenance, exact lobby/arena build inputs, intended persistent namespaces and candidate manifest. Restore access to the complete authored base files through an appropriate saved Studio/export or owner-provided source path, protecting unsaved work. Never manufacture a blank place to make the build green.

**Source:** `src/scripts/lune/build-place.luau`, `arena.project.json`, `lobby.project.json`, `src/server/Env.luau`, `src/server/Modules/PlayerData.luau`, `.github/workflows/cicd.yml`.

**Accept:** both complete builds reproduce from named inputs into fresh `.review/release-candidate/<revision>/` directories; hashes and manifests match tested content. Verify native Windows builder execution, including its `pwd -P` subprocess, once bases exist. No mock storage or fixtures in the candidate. `PrimaryDataKey = STAGING_009` alone proves neither isolation nor production suitability; owner confirms namespace and continuity. Confirm active S1 dates, `LandscapeSensor`, place IDs, game mode capacity and source/package versions. Full builds currently remain blocked on the missing bases.

**Owner/review:** Astra build/persistence lead; owner provides unresolved production identity. Dependency for published QA and R14.

### R02 — Matchmaking capacity and recovery — P0

**Deliver:** measured demand/service budget and the smallest justified scaling implementation from section 4. Preserve party identity, conditional claims, stored match-before-assignment, return regrouping and existing reconciliation.

**Source:** `places/lobby/server/Modules/Matchmaking/{MatchmakerService,MatchRepository,QueueRepository,PartyRepository,PartyService,PartyBus}.luau`, `places/lobby/shared/Matchmaking/Config.luau`.

**Accept:** concurrent workers race; a worker dies after claim/reservation/record/partial assignment; cloud calls exceed lease duration; queues contain stale/claimed tickets ahead of valid players; messages are delayed; leader leaves; party reconnects; cancel races assignment. One active assignment per party, intact parties, eventually released claims, finite recovery and oldest viable parties served. Cover solo/four-player populations and the credible 30k/50k demand mix, a burst and lower-population behavior. Measure requests and errors under retries. Capacity changes must work during old/new server coexistence or have an owner-executed drain procedure.

**Owner/review:** Astra networking lead; Claude max at design and integrated fault evidence. May run independently of visual/content work. No unsupported architecture guess.

### R03 — Remote contract and gameplay authority — P0

**Confirmed defect:** `MatchmakingScript.server.luau:68` declares per-action budgets, but `src/shared/Network.luau:148` reads only validation and the overall rate limit. The global PartyRequest 8/s limit and join-code failure lockout exist; action-specific rules are inert.

**Deliver/accept:** enforce the declared contract before expensive work: JoinByCode 2/5s, StartMatchmaking 2/5s, KickMember 2/5s, DevSoloPlay 1/10s, intended default 6/s. Test independent player/action buckets, malformed/unknown actions and disconnect cleanup. Bound abuse logging. Preserve the existing wire protocol and owner services.

Audit exposed gameplay/economy requests for authoritative identity, phase, ownership, amount, range and finite numeric validation. Exercise repeated/reordered requests and an abusive sender alongside legitimate players. Existing combat queue bounds and catchup clamps remain; fix demonstrated gaps without replacing transport/prediction. Confirm creator/debug tools cannot grant ordinary users authority in the published candidate.

**Owner/review:** Astra networking lead + Claude max; selected network/remote specs, then runtime two-client behavior.

### R04 — First session, social loop and bounded transitions — P0/P1

**Deliver:** one state/ownership table for fresh join → tutorial or skip → lobby/party → queue → transport → arena readiness/vote → match → results → replay/find match/lobby. Include returning players and every failure state. A player should understand the next useful action without a developer explanation.

**Known seams:** `OnboardingOverlay.luau:376` has a touch button while desktop/controller skip is an ImageLabel at `:412`; glyph fallback does not cover all blank-label states. OnboardingClient owns the action. `OnboardingService.cancel()` has no discovered non-debug real-match caller; decide transition policy from actual behavior before wiring it. `TeleportRetryCoordinator.luau` lacks an elapsed-attempt watchdog; current recovery depends on platform callbacks/departure. This is an unbounded-state risk, not a reproduced platform hang.

**Accept:** clickable/tappable skip plus readable X/B presentation; correct input switching and disabled/celebration states. Tutorial checkpoints survive reset/rejoin as intended; party queue/failed teleport does not strand tutorial controls/camera. Published tests cover partial party transfer, Flooded, stale failure callback, preflight refusal, disconnected leader, Retry/Stay, rejected admission, missing client readiness and delayed profile. No duplicate active teleport, obsolete attempt revival or indefinite UI state. Preserve existing admission, readiness, vote extension and reward preflight.

Use available fresh testers immediately; 5–8 short first-time sessions is a useful provisional sample if practical, not a recruitment gate. Record observed confusion and time to first meaningful action, and repair repeated friction. Small qualitative samples guide fixes; they cannot predict D1 retention or profitability.

**Owner/review:** Astra UX and lifecycle leads; Claude for state changes, Gemini for consequential presentation. Published teleport testing depends on owner deployment: Studio playtesting cannot validate TeleportService. [Teleport documentation](https://create.roblox.com/docs/projects/teleport)

### R05 — Persistence, grants and transaction failure — P0

**Deliver:** explicit durable-state contract across profile loading, write leases, receipts, Bonks spending, match awards and shutdown. Preserve ProfileStore ownership, receipt tombstones and save-before-PurchaseGranted. Write leases count outstanding work; they are not transaction mutexes.

**Source risks requiring reproduction:** `CrateService.rollBatch` mutates rewards/pity before its final Bonks debit; an exception after an earlier successful roll is caught without settlement/rollback. Receipt rolls mutate before their durable journal is complete. Concurrent spend/grant paths and response-loss retries need a defined transaction boundary. Do not call this a proven exploit until fault injection establishes it.

**Accept:** failure before mutation changes nothing; failure after partial work either commits exactly the defined partial result or rolls back atomically; no free batch, negative wallet, duplicate refund or rerolled saved receipt. A lost reveal must not encourage buying again to recover an already-paid reward. Specify stable operation/retry identity where required. Receipt replay after failed/ambiguous save, departure and earlier-server completion grants exactly once. Exceed 64 pending/detail entries safely; old receipt replay still deduplicates. Measure permanent tombstone size without deleting deduplication history.

Verify direct item/outfit purchase, daily/quest/season/match reward replay and concurrent operations. Test profile load cancellation/error/session takeover, teleport after acknowledged checkpoint, leave during a lease, rapid rejoin and shutdown with outstanding work. Confirm saved state in an isolated persistent run. Inspect exact ProfileStore version/shutdown coordination before prescribing an alternative drain mechanism. No live reset or migration.

**Owner/review:** Astra economy/persistence leads + Claude max. Extend existing receipt, match-award and grant tests using actual service modules with injected boundaries.

### R06 — Paid random eligibility and commercial boundary — P0

**Existing behavior:** policy is integrated into CrateService, ShopService, ShopViewModel and ShopClient. Active Bonks sales mean the pooled Bonks balance is indirectly paid; even earned Bonks do not bypass the current crate restriction. Current checks permit a malformed table missing the restriction field and bypass policy if active Bonks/crate product entries disappear. Address unknown/pending/failed responses and review historical purchased balances/paid earning sources when catalogue statuses change.

**Deliver:** explicit loading/permitted/restricted/unavailable contract through every relevant preview, card, CTA, batch selector, upsell, prompt return, direct request and receipt path. Restricted paid-random interactions are disabled authoritatively; preserve useful existing deterministic non-random gameplay/shop behavior. **Do not invent a substitute shop, deterministic replacement or compensation path.**

**Decision required before affected fulfillment changes:** the current restricted or retired crate receipt substitutes the crate's Bonks base price (currently 500). That existing fallback conflicts with the owner's no-substitution direction. Preserve evidence and present the exact already-paid/retired/policy-changed cases for an owner-approved commercial disposition. Do not silently retain it as compliant, remove fulfillment, invent refunds, permanently strand receipts, or mark them granted without delivering the agreed value. This is a real scope dependency, not a reason to postpone safe fail-closed pre-purchase fixes.

**Accept:** malformed/failed/pending eligibility never enables a new paid random transaction; no stale-profile grant after a yielding policy call; repeated policy requests are bounded. Permitted users see all possible outcomes and actual current numerical odds, including stateful pity, before committing. Client disclosure and server rolls share the same pool/version/distribution. Test restricted/permitted/failure fixtures through actual services, not just a stub dispatcher. Failed eligibility spends nothing on a new Bonks open. Policy lookup failures remain pending under the current receipt behavior; changes to existing restricted/retired receipt fulfillment require the owner disposition above. Do not silently switch that fallback to indefinite pending.

Roblox treats direct or indirect Robux-funded random items as paid random, requires numerical outcome disclosure, and restricts eligible interactions through PolicyService. The no-alternative rule here is the owner's choice. Verify against [paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items) and [PolicyService](https://create.roblox.com/docs/reference/engine/classes/PolicyService).

**Owner/review:** Astra economy lead + Claude max; Gemini checks state clarity. Actual commercial IDs/prices/promises and any purchase tests are owner verification. ProcessReceipt is fulfillment truth, not prompt-close events; platform external test purchases can cost real Robux. [Developer products](https://create.roblox.com/docs/production/monetization/developer-products)

### R07 — UI/UX production pass across the entire journey — P1, blockers P0

**Deliver:** a screen/state matrix and consistent component-family specification covering tutorial, lobby/navigation, party, inventory/equip/preview, shop/details/purchase states, settings/credits, progression/rewards, queue/errors, loading/vote, arena HUD/menu/scoreboard and results/replay. Evaluate actual interaction and rendered states; create/revise Figma components and assets where useful.

**Known fixes to complete:**

- `JoinCodeModal.luau` considers safe insets but not keyboard geometry; proportional positioning and refocus-on-FocusLost need keyboard-aware review. Keep six-digit sanitation and server guards; do not fight deliberate keyboard dismissal. Input, validation, submit and cancel must remain visible/reachable during keyboard open, paste, slow response, rejection and orientation change.
- V13 modal dim layers currently terminate at core-safe bounds. Coordinate a full-viewport decorative backdrop with the existing modal owner while keeping interactive content inset-safe. No background click-through or duplicate focus owners. Existing modal focus restoration/selection groups should be extended, not recreated.
- V06: make the visible desktop/gamepad SKIP surface actionable through the existing callback, preserve X/B bindings and provide readable fallback when an existing InputActionLabel renders blank. Keyboard skip working alone does not fix a misleading visible control. V08 physical scroll acceptance and V11 Settings/credits remain open. Verify V12's rejected LiveConfig `MinPlayers` path as a source/config compatibility issue; do not simply enable an unsupported setting.
- Revisit shop/inventory/progression rows at long names, large text, all ownership/loading/disabled/empty/error states. Empty mode ThumbnailId values require inspecting the actual vote fallback; do not call them broken from config alone.

**Family-level acceptance:** named peer controls agree on purpose, color role, typography, text inset, visual weight, sliced corner radius, border/shadow and interaction states. Large light surfaces may use dark body text; that does not authorize dark lettering on bright action buttons when that family uses white. Play stays the dominant lobby action. Respect visible artwork bounds and optical alignment rather than assuming the logo fills its texture. Layout reflows when components cannot fit; do not squash controls or hide overflow silently. Scroll cues reflect real overflow and current position. Insets, cutouts, keyboard, controller focus and input switching all alter layout/presentation correctly.

Review seven existing categories: family consistency, hierarchy, typography, geometry, color roles, assets and states. Use at least two named peers, real before/after full-screen captures and detail views where needed. The validator checks completeness/freshness, not aesthetic truth. Astra personally inspects every changed visual; Gemini provides independent milestone critique. Repeat fix → runtime review → critique → fix until the affected composition works on PC and mobile. No promise that automated gates catch every artistic flaw.

**Owner/review:** Astra UI/UX and creative lead + Gemini; Claude when input/lifecycle architecture changes. Focused owner approval for material new treatments; preserve the accepted lobby where it already succeeds.

### R08 — Arena liveliness and interactive content — P1

**Creative brief, not an implementation prescription:** the upward-facing fans should visibly convey cartoony upward airflow and support the intended experience of jumping between them. The inactive spinners should have lively spinning/impact character. Improve comparable primitive elements and make interactions readable and satisfying while preserving the human-authored static arena layout.

**First deliverable:** Studio inventory of each relevant authored instance, its actual hierarchy, transforms/pivot, geometry, materials, anchoring, collisions, constraints, attributes, scripts and existing behavior. Record screenshot/video, current player outcome and intended experience. Do not invent forces, axes, hitboxes, damage, scripts, particle/beam types or networking ownership from names/screenshots.

`RotatingPlatforms.luau` currently has an authored Origin/Assembly convention and synchronized-time motion; MapFeatureRegistry, PlatformRider and MovementGuard already exist. These are inspection leads, not proof that fans or impact spinners belong to the same mechanism. Choose implementation only after inspecting actual content and existing systems; ask if a core gameplay/architecture decision remains unresolved.

Complete one representative fan and spinner end to end before applying the validated approach to all intended instances. This is integration risk control, not a plan to ship one example and defer the rest. Produce an instance-to-behavior/content manifest and account for all in-scope elements.

**Accept:** the fan demonstrates the intended functional upward traversal response and the spinner its intended contact/impact response, with exact mechanics selected only after inspection. Cosmetic motion alone does not complete these requests. The player response is clear and enjoyable in motion; contact/entry/exit/repeated interaction, multiplayer/late join, reset and streaming are coherent; no movement correction fights, stale effects or unfair device-dependent outcomes. VFX/audio support navigation/combat without obscuring opponents. Review at normal camera distance, low graphics and full feature concurrency. Do not alter static course layout to conceal a behavioral problem. A reduced scope requires explicit owner disposition.

**Owner/review:** Astra gameplay/creative leads; Blender/Figma as needed; Claude for authoritative behavior, Gemini for motion/readability, Studio final integration.

### R09 — Rebuild emotes as desirable release content — P1

**Deliver:** polished Wave, ShowtimeTwirl, ShowtimeFlex and ShowtimeBounce performances, plus only a justified number of additional Bonks catalogue entries if quality, time and economy support them. Preserve existing IDs/ownership/promised benefits. No arbitrary catalogue inflation or new pass packaging.

**Important source fact:** current VictoryPose is procedural; VictoryRig anchors a clone, removes Animator/joints and drives an attachment graph. Assigning an uploaded AnimationId alone will not complete this integration. Inspect the actual rig, costume mounting, preview and podium consumers. Author one representative full performance in Blender and prove a compatible export/playback contract before expanding. Evaluate authored pose data versus a narrowly scoped animation playback adapter using actual requirements; do not choose a rig/format/system rewrite by assumption.

**Accept:** distinctive silhouette/personality, anticipation, weight, main action, follow-through and satisfying settle/loop. No generic twitching, floor penetration, camera escape or costume clipping. Inspect the full timed performance, start/stop/repeat, selection/equip/ownership, reset/respawn and interruptions applicable to the discovered system. Preview matches results/podium presentation and relevant remote-player visibility. Reduced motion gets a deliberate static/quiet treatment. Existing scope is preview/podium; do not silently add in-match activation or gameplay advantages.

Deliver saved `.blend` sources, export contract, production content, provenance, honest temporal review evidence and actual Studio playback. If uploaded animation/audio is needed, R10's gate support and moderation/permissions must be complete. Local authoring or one attractive still is not completion.

**Owner/review:** Astra creative/integration lead + Gemini; Claude for the playback/export adapter. One proof first, then the complete justified catalogue at the same bar.

### R10 — Asset delivery, provenance and accessible credits — P1

Use canonical Figma/project component → approved local asset → Iconify → Kenney CC0 → licensed Game-icons → custom Figma → generated art only where useful. Favor chunky rounded/filled icon families. Do not repeatedly search for an already-canonical concept. Group candidate rankings into contact sheets with current UI.

Automatically accepted licenses: CC0-1.0, MIT, ISC, Apache-2.0, CC-BY-3.0/4.0. CC-BY-SA/MPL/custom/ambiguous require review; unknown, unauthorized proprietary, noncommercial and incompatible no-derivatives content is blocked. Preserve author/provider/collection/source URL/license/attribution/modifications/source and final paths. Do not commit bulky raw packs unnecessarily.

**Deliver/accept:** every new asset has saved source, production export, truthful review, exact gate approval when uploaded, actual asset ID/moderation/creator permissions and Studio verification in both applicable places. Gate initially supports images and self-contained FBX/GLB, not animation/audio. Extend only for scoped need, with content-specific validation/preview, frozen bytes, durable operations, uncertainty recovery, regressions, Claude review and deliberate installed-gate update. Refocus every approval request; never bypass through Studio uploads, browser publishing or credential access.

Wire generated `ThirdPartyCredits.luau` through both project builds and a small player-accessible Settings view. It currently has no discovered consumer/mapping. Generate notices with `tools/generate_credits.py`; do not hand-edit derived outputs or turn credits into a player preference. Verify text, scrolling/back/focus and larger text on relevant inputs. Pre-existing arena assets are not automatically license-audited just because they already render.

### R11 — Bonks pacing, catalogue value and season continuity — P1

Produce `docs/ECONOMY_RELEASE_SPEC.md` and reproducible tables/simulation from real config. Do not pick arbitrary “good” prices or treat code comments as measured engagement.

| Current baseline | Value |
| --- | --- |
| New player | 1,000 Bonks |
| Match Bonks | 75 completion +100 win +10 qualifying elimination +15 qualifying catch, with participation/action caps |
| Match XP | 25 completion +100 win +20 elimination +15 catch |
| Existing pass effects | 1.5× match Bonks; 2× match XP; not combat stats |
| Seven daily claims | 100/125/150/200/250/300/500 =1,625 Bonks |
| Quests | 3 daily; individual configured rewards 100–225 |
| Active crates | 3 at 500 base; featured 15% discount =425; quantities 1/5/10 without batch discount |
| Rarity weight / duplicate refund / direct price | Common 70/50/1,000; Rare 24/150/2,500; Legendary 6/400/10,000 |
| Pity | Rare or better by roll 5, Legendary by roll 25 under current rules; state changes individual odds |
| Season S1 | Starts September 1 UTC, 42 days, 25 tiers; `600n + 8n²` XP threshold, tier25 =20,000 |
| Season currency | 3,300 free; additional 10,100 premium, plus cosmetic grants |

Inputs live in `src/config/{Progression,Economy,Cosmetics}/` and `CrateOdds`/`CrateRolls`. Measure queue/round length, qualifying actions, win distribution, claims, ownership and replay. Model new/casual/skilled/completionist and booster cohorts; report Bonks/hour, first useful reward, desired direct-item time, duplicate-adjusted crate sink, stateful expected target acquisition, collection exhaustion and season completion sensitivity.

Illustration only: a fully owned, no-pity 70/24/6 roll refunds `0.70×50 +0.24×150 +0.06×400 =95`, leaving 405 base or 330 featured net sink. Actual pity changes this; simulate exact stateful rules. Starting 1,000 buys two base crates or one Common direct item. These facts do not prove the prices are optimal.

**Accept:** document before/after values and justification; catalogue additions update generated pools/disclosure intentionally; defaults/exclusives/outfits/duplicates/retired identities remain consistent; all advertised content works and persists. Verify daily UTC rollover, completed-unclaimed quests, free/premium season claims and receipts near season boundaries. Preserve old season/product identities; no account configuration or new commercial offering changes. Review unavailable/owned/restricted presentations with R07.

### R12 — Combat feel, device suitability and repeated-round QA — P0/P1

Walk actual FFA/TDM play with multiple skill/input cohorts: movement, camera, aiming, throwing, catching, hammer, elimination, respawn, vote, scoreboard and replay. Inspect responsiveness/readability, spawn fairness, action telegraphs, feedback and repeated-play appeal. Preserve existing simulation ownership and approved art; changes need measured/observed reasons. Infection stays disabled unless separately authorized.

Exercise 1,2,4,8 and full 20-player scenarios as hardware allows; explicitly state when bots, fixtures or fewer clients were used. Test no/tied vote, late-ready arrival, scarce opponents, simultaneous eliminations, team changes, leader leaving results, old result requests and every return choice. No double score/reward, stale timers/team state, orphaned cosmetic rig, input/camera leak or growing effect load.

**Device release matrix:** prioritize representative desktop keyboard/mouse, a physical lower-performance phone and advertised controls, including connected-controller smoke where supported. Expand to a second mobile OS/device class, tablet and console according to advertised support, shared-layout changes and observed failures. Include narrow/cutout landscape, notched safe areas, mobile keyboard, larger text, long names/errors, touch scrolling, reduced motion, sound settings and switching input mid-flow. Lack of equipment is explicit untested coverage for owner rollout decisions; do not infer a pass from emulation or invent an automatic hardware-procurement gate. Visible failures on supported devices remain launch issues.

Measure full-context frame time, memory, networking and asset loading with actual client tools. Studio can distort client performance; inspect actual devices and MicroProfiler/Developer Console evidence. [Roblox performance diagnosis](https://create.roblox.com/docs/performance-optimization/identify)

**Owner/review:** Astra gameplay/QA lead, Gemini for visual/motion findings and Claude for consequential behavior fixes. Owner executes published/device checks inaccessible to the agent. Accessibility and first-session blockers take precedence over ornamental additions, without silently dropping requested content.

### R13 — Essential launch signals and useful product measurement — P0 / selective follow-through

Use existing `src/server/Modules/AnalyticsService.luau`, `src/config/Infra/Analytics.luau`, gauges, logs and platform dashboards first. Launch essentials are enough visibility to detect and act on queue/teleport/capacity failures, profile/save failures and pending/incorrect rewards or receipts. An operator sheet plus existing trustworthy signals can satisfy this; no new telemetry platform or full custom dashboard suite is required. Existing matchmaking funnel ends at Teleporting; correlate existing ArenaArrival/readiness where useful. Distinguish purchase prompts from durable completion. Never use analytics as the transaction ledger.

**Confirmed instrumentation gap:** call sites supply crate rarity/duplicate/pity/count and substitution fields that current three-slot schemas discard. Adding extra call arguments alone will not expose them. For fields actually needed by a launch/balance decision, record a small table of retained fields, denominator, deduplication scope and source of truth; defer unused dimensions. Fit platform limits without per-user/high-cardinality labels. Studio deliberately skips actual platform submission; prints do not prove ingestion.

**Product questions:** first meaningful action and first match completion; tutorial abandonment by step; queue abandonment versus transport failure; immediate replay after loss/win; reward comprehension and claim/equip completion; repeated sessions/D1/D7; earned/spent Bonks by cohort; duplicate frustration/catalogue exhaustion; shop view→intent→durably fulfilled purchase. Separate correlation from causation and observed data from design hypotheses. D1/D7 cannot be established before the cohort has aged.

**Operational measures:** queue age/backlog, assignment throughput/claim recovery, lease/request throttles, reservation/teleport failures, profile load/session/save failures, pending receipt age, reward retries, server dropped time, client performance and missing assets. Specify who checks each measure, where it is visible, and what action it triggers. A dashboard with no actionable thresholds is insufficient.

**Accept:** show the owner where the essential failure/health signals are visible and how to act on them. For changed logging, verify the actual emitted fields/deduplication and published ingestion, rather than building tests for every untouched event. Roblox supports three custom fields and applies event/cardinality limits; near-real-time View Events and delayed aggregate charts serve different purposes. [Analytics event types](https://create.roblox.com/docs/production/analytics/event-types)

The product questions above guide small useful improvements and postlaunch evaluation; missing new D1/D7/cohort/pity instrumentation is not independently a release blocker when existing measurement is adequate. Implement a new event only when it answers a specific launch/balance decision cheaply. Preserve existing useful instrumentation and list deeper analysis as follow-up instead of delaying content for analytics architecture.

Prepare a launch operations sheet with provisional alert thresholds validated against the pre-release baseline: any confirmed reward corruption/duplicate paid grant is immediate stop/escalation; a sustained breach of queue/performance budgets or rising save/teleport failures triggers a hold. Record sample size/time window before interpreting percentages. No automated destructive mitigation or speculative new live-ops platform.

### R14 — Owner release, rollback and commercial readiness — P0

**Deliver:** `docs/RELEASE_CANDIDATE.md` with exact revision/artifact hashes, both place/base versions, asset IDs/moderation, namespace/schema, active season, compatible protocol, QA matrix, advisor dispositions, known issues and owner actions. Local build/check commands are not deployment approval.

Existing `.github/workflows/cicd.yml` stages/tests affected artifacts and publishes tested bytes; preserve it. Publishing the two places is sequential, **not an atomic multi-place transaction**. A partial failure or old running server can leave mixed versions. Prepare and verify an owner-run previous-compatible-version rollback, order of operations, retained artifacts and mixed-version behavior. Never assume restoring code rolls back persistent grants/schema. Keep receipts/product IDs valid across rollback.

Owner validates actual place access/capacity, supported devices, platform metadata, product/pass IDs/benefits, asset permissions and final Creator Hub setup. List incomplete commercial settings explicitly; monetization is not launch-ready while promises/fulfillment remain unverified. Prepare honest store/icon/thumbnail/copy assets if beneficial through the art workflow; publishing/listing/configuration remains owner work. Do not create new offerings.

**Accept:** release smoke journey through both actual published places, new/returning profiles, party/replay, applicable purchases with owner-provided evidence, and rollback rehearsal on an isolated candidate. Exact tested bytes promoted by the owner; no mock or wrong namespace. Owner launch operator and backup identified; triage/runbook and stop conditions ready. If capacity or integrity evidence is missing, recommendation is **not ready for the stated 30–50k+ launch**, with exact blockers and options, regardless of date.

## 6. Schedule, dependencies and decision points

The calendar is a working sequence, not a delivery guarantee. The current date leaves approximately three calendar days; the launch hour and QA staffing decide actual capacity. The quoted old “48 hours” is historical. Do not compress or fabricate acceptance to fit Saturday.

| Checkpoint | Required output and parallel work |
| --- | --- |
| September 9 — playable progress and viability | Begin visible UI fixes and authored arena/emote integration immediately. In parallel, run bounded R01 base/environment checks, R02 capacity measurements, R03 confirmed contract correction and R05 transaction probes; prepare the R06 commercial decision. Do not spend the day only auditing backend systems |
| September 10 — integrated fixes/content | Implement proven service corrections; complete one fan/spinner/emote integration proof and expand scoped content; UI/keyboard/modals/credits; economy calculations and advisor milestones. Prepare owner-deployable candidate early for real service tests |
| September 11 — candidate and QA | Full catalogue/arena accounting, device/accessibility and populated server soak; published owner-run two-place tests; current visual review; commercial/asset checks; scale evidence and operational dashboards; rollback rehearsal. Proposed feature freeze by end of day, exact time owner confirms |
| September 12 — go/no-go and owner launch | Final candidate smoke, no open P0, all required P1 verified or explicitly scoped by owner, approved new visuals/assets, launch operator/rollback ready. Owner deploys and controls traffic. Hold if gates fail |

Critical paths: **bases → full artifacts → owner staging → actual teleport/persistence/device QA → release**; **content inspection → authored integration → gate if needed → moderation/permissions → runtime content QA**; **transaction/policy/scale contracts → fixes → fault tests → published corroboration**. Work on these concurrently where edits/tools do not conflict. Asset moderation and physical testers are external dependencies; surface them early.

If the deadline becomes infeasible, deliver the current candidate, exact remaining blockers, estimated critical-path work and concrete owner options (more testing time, controlled rollout, or a named reduced scope). Do not silently cut the fans/emotes, suppress required reviewers or lower quality thresholds.

## 7. Evidence and release gates

Maintain `docs/RELEASE_CANDIDATE.md` as the compact implementation ledger; raw evidence goes under `.review/production/<candidate>/<package>/`. Every case records requirement, source revision, place/build, actual or mock profile mode, device/viewport/insets, player count, network setting, steps, expected/actual result, capture/log path and outcome. Use human-readable names; numeric MCP request/image indices are not scores.

Minimum gate sequence:

1. **Source/config gate:** correct bases/projects/packages, no revoked instructions restored, intended namespace, no fixture/mock leakage, reproducible complete candidate.
2. **Behavior/integrity gate:** affected unit and service fault suites; real first/returning loop; no unresolved P0; transaction/policy/ownership and lifecycle acceptance.
3. **Content/visual gate:** all in-scope instances and performances accounted for; action/state/device matrix; Astra inspection; valid fresh advisor evidence; focused owner acceptance for changed visuals. Existing approved lobby remains valid for unchanged scope.
4. **Asset gate:** source/export/provenance/credits, exact human upload approval, usable moderated IDs/permissions and Studio appearance. Pending upload/moderation is incomplete.
5. **Scale/device gate:** measured throughput and failure envelope, full per-server load, sustained physical-device QA and truthful coverage. State model assumptions and untested real-platform scale.
6. **Owner release gate:** exact candidate manifest, commercial and deployment actions, published smoke, rollback and monitoring. Only the owner pushes/deploys/publishes.

`tools/visual_review.py` validates evidence freshness and comparisons. Full local `release-readiness.luau` also expects a release-purpose review and actual final owner acceptance at configured paths. The existing `owner-visual-approval.json` satisfies the earlier checkpoint, not every final-release field. Never synthesize missing advisory/acceptance records to make preflight green. This local readiness mechanism does not replace or silently alter place CI.

Final implementation handoff must say one of: **ready for owner final release checks**, **ready only after named owner actions**, or **not ready with concrete blockers**. Include changes, playable content, economy decisions, device/service evidence, advisor findings/dispositions, mock cleanup, asset status, commits and exact owner actions. A proposed plan alone is not game completion.

## 8. Outstanding owner decisions and external dependencies

| Item | Why / next concrete step |
| --- | --- |
| Launch hour, QA window and launch operators | Date is fixed as September 12; identify who can deploy, test, monitor and roll back |
| Physical test devices/testers | No device list supplied. Arrange lower-performance phone, second mobile class, desktop/controller and advertised tablet/console coverage |
| Complete authored place bases | Save/export/provide the correct bases with version provenance; preserve unsaved sessions |
| Production identity/configuration | Confirm data namespace, published capacities and intended commercial setup; do not infer from `STAGING_009` |
| Already-paid restricted/retired crate fulfillment | Resolve existing 500-Bonks fallback conflict with no-compensation direction through a concrete case/offer review |
| True traffic shape | 30–50k+ peak is the target; arrival ramp, lobby share, replay mix and tester/traffic access determine the load envelope |
| Scoped behavior/rig decisions after inspection | Ask only when real authored state leaves core intent/architecture unresolved; do not request fan force values or rig choices before inspecting |
| External reviewer/service or moderation outages | Preserve failed run/operation evidence; do not label pending work passed or silently replace required reviews |

These do not block independent local implementation once that phase is requested. No blanket reconfirmation of PC access, Figma route, visual approval, or beneficial asset creation is needed.

## 9. Initial implementation batch and practical commands

On the next implementation task: read this spec and the compact handoff; inspect Git and current Studio identities/modes; verify needed integrations once; open the accepted comparison; preserve owner work. Start R01/R02/R05 critical-path evidence in parallel with R07/R08/R09 actual state inspection. Complete the confirmed R03 defect through its existing owner, and prepare the R06 commercial decision packet. Do not spend the first hour bootstrapping the already-installed workflow again.

Native PowerShell from the workspace; run only checks relevant to changed code. Historical green runs are not new validation. Existing Studio/in-place tests and headless Lune tests are different coverage.

```powershell
.\.agent-venv\Scripts\python.exe tools\doctor.py
lune run src/scripts/lune/run-tests.luau
.\.agent-venv\Scripts\python.exe tools\run_safe_tests.py
.\.agent-venv\Scripts\python.exe tools\generate_credits.py
```

Use explicit projects: `rojo serve arena.project.json` (34872) or `rojo serve lobby.project.json` (34873), checking existing servers before launching duplicates. Once complete bases are available, fresh local artifact destinations:

```powershell
lune run src/scripts/lune/build-place.luau arena .review/release-candidate/CANDIDATE/arena
lune run src/scripts/lune/build-place.luau lobby .review/release-candidate/CANDIDATE/lobby
```

Replace `CANDIDATE` deliberately; do not overwrite existing evidence. Do not run release/deploy scripts as ordinary tests: even “stage-only” uploads a place version. Owner-executed commands belong in the final reviewed runbook.

Reviewer examples (replace task/files with selected actual evidence):

```powershell
.\.agent-venv\Scripts\python.exe tools\reviewer.py claude --task "Review this bounded service contract and fault evidence." --file path/to/affected.luau --diff --test-output .review/production/CANDIDATE/tests.txt
.\.agent-venv\Scripts\python.exe tools\reviewer.py gemini --task "Review this visual milestone against its named peers in context." --visual-packet .review/production/CANDIDATE/visual-packet.json
.\.agent-venv\Scripts\python.exe tools\visual_review.py --review .review/gemini-REVIEW-ID
lune run src/scripts/lune/release-readiness.luau
```

Use the existing structured packet schema, not smoke-test mode, for visual acceptance. Keep source/evidence hashes and record findings individually as accepted/fixed, rejected with evidence, or unresolved. Latest failed advisor runs are documented in `VISUAL_RELEASE_AUDIT.md`; no current auth fix was established. Claude/Gemini reviews must resume meaningfully in implementation, without automatic repeated retries of unchanged failed packets.

For asset operations use [WORKFLOW_COMMANDS.md](WORKFLOW_COMMANDS.md) and [ASSET_PIPELINE.md](ASSET_PIPELINE.md). Resume/reconcile a known upload before any resubmission. For unsupported desktop surfaces, stop that interaction and record the exact missing capability; permission alone cannot create a tool. Continue source/test work and provide the next safe owner action.

Planning source audits are retained in `.review/production-plan/core-audit.md` and `economy-audit.md`; their key findings and acceptance requirements are incorporated here. This spec is the durable continuation contract, so those local memos and the old conversation are not required reading before work starts.

## 10. Planning review record

Three independent Astra source audits covered core/network/scale, economy/policy and UI/content. Their final spec review corrected the global-poll interpretation, Rare-or-better pity wording, existing receipt-fallback boundary, functional fan/spinner acceptance and explicit SKIP behavior. It also removed invented mandatory test counts, recruitment/hardware procurement gates and blanket telemetry requirements. Player-impact and credible scale evidence remain required; backend polish does not.

A bounded Claude **max-effort** review of the capacity/transaction/policy plan ran with a 180-second per-request deadline and timed out while generating, with rate-limit status allowed. Packet and state: `.review/claude-2dd1784f-9cc4-4b12-92e6-74d478cf7c4b`. **No Claude plan verdict was obtained.** The normal configured 900-second timeout and max effort were not changed. This was a new bounded plan packet, not a retry of the old visual-workflow review. Obtain the relevant technical milestone reviews during implementation; do not relabel this timeout as approval. No new visual artifact was created in planning, so no new Gemini visual acceptance was claimed.

Documentation-relative links and changed-document whitespace checks passed. This planning pass modified the spec/handoff and stale workflow documentation only; it did not run gameplay tests, author/upload content, change game code or deploy. Owner file changes remain untouched.
