# Production operations — September 9 candidate

**Status: preparation only; not a launch authorization or a verified monitoring installation.** This sheet covers the existing source signals and owner actions for the [current candidate](RELEASE_CANDIDATE.md), following [R13/R14](PRODUCTION_READINESS_SPEC.md). No deployment, published-service test, dashboard login, alert installation or rollback rehearsal was performed to prepare it. Source was inspected at HEAD `8cdd931bd36a8994b84db257ad7593b666c9510e` with concurrent working-tree changes; use the candidate's final hashes and revisions before release.

The **release owner** controls rollout, access/capacity, commercial settings, all staging/production deployments, place publishing, Git pushes and release PRs. A **backup operator**, **service investigator** and **device tester** need named people and verified access before rollout; these roles are not staffed by this document. The release owner makes hold/resume/rollback decisions, the investigator records evidence and diagnoses, and the tester verifies the actual player journey after each change. Do not automatically erase data, reset queues, grant replacement purchases, change prices or disable movement protection in response to an alert.

## Open the real observation surfaces

| Surface | What exists | Owner action / present evidence limit |
| --- | --- | --- |
| Roblox Developer Console | Platform client/server logs, memory/network information and profiling tools | In an owner/edit-authorized live session, open F9 and select Server for server warnings or Client for device failures. Record place ID, actual published version, job ID, UTC time and device. This task did not open a published console. |
| Creator Dashboard → experience → Analytics → Economy / Funnel / Custom → View Events | Platform near-real-time event inspection, followed by aggregate charts | Owner verifies access for universe `10464667217`, generates a known published event, refreshes View Events and records the actual fields/value. Access, ingestion and useful charts for this candidate are **unverified**. No custom dashboard or automated alert is installed by this work. |
| Existing server state / player presentation | Queue/party phases, arena admission/readiness, loaded profiles and reward/receipt journals | Investigator inspects the affected server and authorized profile evidence without mutating it. State in one server is not universe-wide coverage. Player-facing recovery is corroborating evidence, not a transaction ledger. |
| CI run and retained artifacts | Existing workflow job summaries and artifact uploads | Owner records workflow commit/run, manifests, tested/published receipts and actual version history. Current local builds are not proof of a published candidate. |

Roblox documents F9, Client/Server log selection, memory and network diagnostics in the [Developer Console guide](https://create.roblox.com/docs/studio/developer-console). View Events is under the Economy/Funnel/Custom pages; aggregate charts typically take about 24 hours, so their absence immediately after a test is not proof of failed submission. See [event validation](https://create.roblox.com/docs/production/analytics/event-types). These are platform capabilities, not claims that the owner's account or dashboards were inspected.

[AnalyticsService](../src/server/Modules/AnalyticsService.luau) deliberately returns before platform submissions in Studio. `Debug.AnalyticsVerbose` currently defaults false; Studio prints, when enabled, still do not establish ingestion. Look for `[AnalyticsService] LogCustomEvent failed`, `LogFunnelStepEvent failed`, `LogEconomyEvent failed` or `LogOnboardingFunnelStepEvent failed` in server logs. An analytics outage can explain missing observations; it cannot establish that grants or transport failed or succeeded.

## Signal, interpretation and response

The actions below are an operator procedure, **not configured alarms or measured release thresholds**. Record the numerator, denominator, observation interval, server/sample count and traffic mix before interpreting a percentage. Compare like-for-like windows. Preserve the first failure's evidence before changing conditions.

| Concern / responsible role | Existing signal and exact limitation | Trigger and concrete response |
| --- | --- | --- |
| Match access / release owner + tester | Source arena `121997450145716`, lobby `130584867985467`; configured target 20 and party maximum 4. Candidate records earlier Studio MaxPlayers 60, which does not verify published capacity. `ArenaAdmission` and `ArenaReady` player attributes expose local admission/readiness. `ArenaSessionService` warns `Arena capacity reached` or reports rejection warnings. | A valid published party cannot enter, legitimate arrival is rejected, or actual capacity/permissions differ from the reviewed contract: stop ramping arrivals. Confirm both published place IDs, access, capacities, expected roster and protocol, then retest the complete lobby→arena path with the owner. Do not raise target population to match an unverified platform setting. |
| Queue / service investigator | `Matchmaking` funnel: `Queued` → `Matched` → `Teleporting`; `MatchmakingCancelled` and `MatchmakingTeleportFailed`. Server warnings include `[MatchmakerService]`, `[PartyService]`, `[QueueRepository.Enqueue]`, `[QueueRepository.GetCandidates]`, `[MatchRepository...]` and `[TeleportCoordinator.ReserveServer]`. CloudRetry warns only after configured retries are exhausted. | Oldest valid waiting tickets keep aging while enough eligible players are present and assignments do not keep pace: hold the traffic ramp. Inspect party authority/ticket freshness, claims, lease contention, reservation latency and cloud errors; distinguish scarce population from a stalled worker. Preserve timings from the same attempt. Do not clear `AllPlayers`, force-unclaim parties or lower the poll interval as an unverified cure. |
| Teleport / investigator + tester | Lobby failure event and actual `TeleportStatus` state; return-to-lobby `TeleportAttempt`/`TeleportFailed` custom values are attempt numbers. `[ArenaReturnService] Could not return ...` and retry-driver warnings provide context. `ArenaGateReleased` value is gate duration in **seconds**; `ArenaLoadingStage`/`ArenaPreload` values are client-reported **milliseconds**. | A retained player is stuck or comparable attempts increasingly fail: hold the ramp, record direction, destination, attempt/result, presentation state and arrival/readiness. Let the existing bounded retry/recovery path operate; test Retry/Stay/return choices on the retained player. Do not dispatch a second competing teleport while the previous one may still be active. |
| Profile/session/save / investigator | `[Data] Loaded profile ...`; `[Data] CRITICAL — failed to load profile ...`; `[Data] Timed out waiting for profile writes ...`; client kick reasons `Data load failed` and `Your data has been released`. Developer Console network failures can corroborate store errors. Load success is not save confirmation. | Any confirmed profile corruption is immediate stop/escalation. Rising load/save failures or valid users unable to join: hold rollout, capture store errors and affected session chronology, verify namespace and session ownership, and have the owner decide recovery. Do not turn on mocks, reset the namespace, clear session ownership or replace balances to make a failing live journey appear healthy. |
| Paid receipts / investigator + release owner | `[Monetization] receipt for unmapped product`, `no handler for product type`, `receipt ... failed`; many ordinary pending returns are deliberately silent. `ReceiptWork`, `Receipts` and saved receipt readback are the evidence of pending/completed work. `PurchaseGranted` follows `confirmReceiptSaved`; a prompt close or reveal is insufficient. | **One confirmed duplicate paid grant, incorrect paid grant or lost paid entitlement: stop/escalate immediately.** Retain purchase ID, product ID, target/namespace, saved evidence, journal state and retries in access-controlled incident evidence. Allow idempotent receipt retry; do not replay grants manually or delete tombstones. Unmapped IDs require owner investigation of existing commercial identity, not reassignment to another offer. |
| Earned awards / investigator | `RewardsRecoveryPending`, `MatchAwards.Pending`, `[MatchAwardService] commit failed`, and `[Data] Crate committed but replication failed ...`. Bonks crate recovery uses the persisted open state/sequence and reveal acknowledgment described in the candidate. A replication warning can coexist with a committed reward. | Pending work fails to drain across the existing retries, or a balance/ownership discrepancy is confirmed: stop further affected tests/ramp, compare the same award/open identity and saved state, then reproduce on the isolated candidate. Do not buy again or award a replacement merely because the reveal was missing. Confirm correction before resuming. |
| Movement / investigator + tester | At `MatchEnded`, `Server_movementCorrections` reports reset-on-read correction count. `Server_rejectedInputs` reports rejected intent count; neither is proof of cheating. Existing movement allowance/reset paths cover game mechanics and spawns. | Repeated legitimate rubber-banding, a fall/recovery loop, or a correction increase associated with a particular mechanic: stop expanding that exposure, preserve player/device/RTT and mechanic context, reproduce hammer/fan/jump-pad/platform interaction and inspect the responsible allowance. Do not loosen global movement limits or penalize players from the aggregate alone. |
| Performance/assets / tester + investigator | `Server_droppedSimMs`, client/server console memory/network/logs, Script Profiler and MicroProfiler; `InputLatency` samples `GetNetworkPing() * 2000` every configured 60 seconds. That code value is an RTT estimate in ms, not input-to-photon latency. | A visible sustained hitch, memory growth after warm-up, recurring missing/failed assets, or server dropped simulation under the agreed population/device envelope: hold the ramp, capture the actual device plus server trace, compare against the same baseline and isolate the trigger. Idle Studio FPS or a single ping sample is insufficient to resume. |

Sources: [matchmaking config](../places/lobby/shared/Matchmaking/Config.luau), [PartyService](../places/lobby/server/Modules/Matchmaking/PartyService.luau), [queue repository](../places/lobby/server/Modules/Matchmaking/QueueRepository.luau), [CloudRetry](../places/lobby/server/Modules/Matchmaking/CloudRetry.luau), [arena session](../places/arena/server/Modules/ArenaSessionService.luau), [teleport retry driver](../src/shared/Game/Matchmaking/TeleportRetryCoordinator.luau), [arena return](../places/arena/server/Modules/ArenaReturnService.luau), [PlayerData](../src/server/Modules/PlayerData.luau), [MonetizationService](../src/server/Modules/MonetizationService.luau), [MatchAwardService](../src/server/Modules/MatchAwardService.luau).

There is **no existing aggregate queue-age/backlog gauge in the inspected path**. `GetCandidates` reads at most the configured 100 sorted rows; its oldest ticket is a bounded sample, and rows can be stale/claimed. It is not a full queue count or a measurement of all waiting players. Compare authoritative ticket `enqueuedAt`, party phase and assignment times for an explicitly recorded sample; external cloud-service request/error observations are separate. Matchmaking's funnel has no explicit queue-duration value and ends before arena arrival. Same-arena PlayAgain bypasses the global queue, so CCU is not a queue-entry rate.

`ReceiptWork` is initialized with item work and has **no creation timestamp**. Do not claim that its age can be computed from this schema. Record when a pending receipt is first observed, platform evidence when available, later retry observations and durable outcome. The saved receipt `at` field describes completed receipt bookkeeping, not necessarily original purchase or pending-start time. Existing configured bounds—64 pending receipts/awards, 8-second receipt-save wait, 5-second award retry, 10-second write-lease close wait—are implementation controls, not service-level measurements or alert thresholds. See [progression persistence config](../src/config/Progression/Data.luau) and PlayerData.

The source performance gauges are registered in [SimulationServer](../places/arena/server/Scripts/SimulationServer.server.luau), read/reset at `MatchEnded`, and each exported once using the first currently connected player. They are server interval totals, not per-player values or continuous frame-time percentiles. A stalled match may never emit its next total; manually calling the `take...` functions would consume the counters. Use the runtime profilers for immediate incidents. The reporter's device/assist fields identify that arbitrary reporter, not the server population. [Roblox performance diagnosis](https://create.roblox.com/docs/performance-optimization/identify) explains profiling and the distinction between network and data ping.

The production spec proposes p95 assignment ≤15 seconds with sufficient population, a five-minute burst-drain check, and 16.7ms server work / desktop 60FPS / agreed phone 30FPS investigation targets. **None is a validated or installed alert for this candidate.** Before rollout, the owner records actual baseline windows, sample sizes, supported device/population conditions and chosen hold/resume thresholds. A confirmed reward error or visibly broken supported journey remains actionable without waiting for a percentage threshold.

## What analytics actually retains

[FieldSchemas](../src/config/Infra/Analytics.luau) and [AnalyticsFields.resolve](../src/shared/Game/Economy/AnalyticsFields.luau) keep at most three strings. Each slot takes the **first available** key from its priority list and prefixes the key name. Wrappers do not provide durable exactly-once analytics delivery. A failed submission is warned and does not become the gameplay transaction ledger.

| Event family | Retained fields / numeric value | Denominator and deduplication caution |
| --- | --- | --- |
| Matchmaking funnel | deviceClass; assistBucket; first of modeId/reason/source/track. Step GUID starts anew at step 1. | Count journeys entering Queued for funnel progression. `partySize` and `matchId` are dropped, so these dashboards cannot correlate an exact cross-server party/arrival or calculate authoritative player throughput. Source call sites can report transitions again; the wrapper is not a persistent deduplicator. |
| ArenaArrival / loading / gate | Same default fields. Gate `reason` survives; gate seconds and loading/preload milliseconds survive as numeric values. | `admission`, `stage`, `outcome` and expected/ready counts are dropped. ArenaArrival logs when admission changes; it is not automatically unique-player arrival. Gate rows are per admitted local player, not one per match. Do not divide these raw counts into a success rate without a scoped source denominator. |
| TeleportAttempt / TeleportFailed | Default fields; `reason` may survive; numeric value is attempt number. | Source return events are per reported player attempt/final failure, not unique journeys. `direction` and `maxAttempts` are dropped. Sum of values is not failure count. Lobby has the separate MatchmakingTeleportFailed event. |
| Server_droppedSimMs / Server_rejectedInputs / Server_movementCorrections | Numeric interval total plus default fields, normally modeId. | One reporter per match-end, reset-on-read, no cross-server dedup identity. Compare per observed server interval and population. The counts are not frame time distributions or per-player rates. |
| Shop* / Economy | deviceClass; variantId; Shop first of offerKind/section/productType/source, Economy first of source/productType/modeId. Economy amount, balance, flow, transaction type and SKU use native arguments. | Shop opened/attempted/prompt events measure intent. Confirm paid completion from saved receipts and actual fulfillment. Crate rarity, duplicate, pity, count and substitution details passed at call sites are dropped by these schemas. |

This sheet adds no telemetry. Existing `Combat_hits`, `Combat_catches`, `Combat_deaths` numeric events remain useful; fields appended to `CombatSummary` do not automatically survive the default schema. Deeper D1/D7, replay cohorts and duplicate-frustration analysis are follow-up questions, not fabricated prelaunch outcomes or a reason to build a new telemetry platform before fixing player failures.

## Candidate identity and stop conditions before remote actions

Owner verifies these against the final [candidate ledger](RELEASE_CANDIDATE.md); concurrent local work means this sheet is not an immutable artifact manifest:

- Universe `10464667217`; lobby `130584867985467`; arena `121997450145716`. Earlier Edit versions 1066/507 and reported MaxPlayers 60 are Studio observations, not a published acceptance result. The client Play snapshot reports version 0.
- [Env](../src/server/Env.luau) still uses `PrimaryDataKey = "STAGING_009"`. Its name does not prove isolation. Matchmaking uses `OuchDev_v2` in Studio and `OuchLive_v2` otherwise; this does not isolate the profile store. Owner confirms intended data continuity and isolated test target before cloud tests or real-player testing. Do not rename either namespace as an operational shortcut.
- The retained lobby base exists; the complete arena base remains missing in the candidate record. The builder requires exactly one complete `.rbxl` per place directory. A local lobby merge made amid concurrent edits is not a frozen two-place release. Preserve unsaved authored Studio work and establish base provenance first.
- The lead recorded Studio **File → Download a Copy** logging “Saving to Roblox...” before download. No Publish was invoked, but unchanged Edit version does not exclude an unpublished cloud save. Owner inspects lobby version history; do not repeat that route for arena under an assumption that it is local-only. A read-only published download, below, cannot capture unsaved/current Edit-only changes.
- [Observed client ConfigState](../.review/production/2026-09-09-batch1/config-live-lobby.json) has Effects base 750 / featured 637, while source has 500 / 425. See [R11](ECONOMY_RELEASE_SPEC.md). Owner reconciles effective values and existing restricted/retired paid fulfillment; retain all existing product IDs, season IDs, entitlements and receipt tombstones. Neither source rollback nor setting a config default rolls persistent transactions back.

## Inspected commands and their effects

These commands are **instructions for the owner, not actions run by this task**. Start in `C:\Users\jackc\Desktop\ouch`. Use a fresh literal candidate directory name where `CANDIDATE` appears. Credentials are supplied privately through the existing environment; never paste or print API keys into evidence. All remote tests/staging/publishing below remain owner-only.

Local identity checks and complete artifact preparation (no network publishing):

```powershell
git status --short
git rev-parse HEAD
Get-ChildItem -LiteralPath places/arena,places/lobby -Filter *.rbxl
lune run src/scripts/lune/build-place.luau arena .review/owner-release/CANDIDATE/place-arena
lune run src/scripts/lune/build-place.luau lobby .review/owner-release/CANDIDATE/place-lobby
Get-FileHash -Algorithm SHA256 -LiteralPath .review/owner-release/CANDIDATE/place-arena/dist.rbxl,.review/owner-release/CANDIDATE/place-lobby/dist.rbxl
```

[build-place](../src/scripts/lune/build-place.luau) runs Rojo plus the merge script and writes local `build.rbxl`, `dist.rbxl`, `manifest.json`; it rejects existing outputs and destinations inside `places/`. It records HEAD, artifact/base/lock hashes but does not prove a dirty tree equals that HEAD. Freeze and identify the actual tested source; keep required bases and dependencies available. The arena command currently requires its missing base to be resolved.

Optional **read-only remote fetch to a fresh local file**, only if the owner wants the currently published arena as a separate comparison input and already has the required asset-delivery access:

```powershell
$opsArenaDownload = '.review/owner-release/arena-published-download.rbxl'
if (Test-Path -LiteralPath $opsArenaDownload) { throw 'Choose a fresh output path first' }
New-Item -ItemType Directory -Force -Path .review/owner-release | Out-Null
$env:ROBLOX_PLACE_ID = '121997450145716'
lune run src/scripts/lune/fetch-live-place.luau $opsArenaDownload
Get-FileHash -Algorithm SHA256 -LiteralPath $opsArenaDownload
```

[fetch-live-place](../src/scripts/lune/fetch-live-place.luau) uses GET for asset-delivery metadata and the returned download location, then writes the specified local file. It performs no source upload or remote save. The owner must still establish the downloaded version/provenance and compare it with protected Edit work before choosing a base. Do not use [pull-places.sh](../src/scripts/shell/pull-places.sh) as an equivalent harmless comparison: it **overwrites the existing authored local `.rbxl`** after downloading. None of these fetch commands was run for this document.

| Inspected deployment entry point | Actual effect / boundary |
| --- | --- |
| `test-and-deploy.luau ... --test-only` | Executes the supplied cloud test script against the current place version. No new upload, but **remote code execution**, not a local or read-only test. It neither proves new local bytes nor isolates the profile namespace. |
| `test-and-deploy.luau ... --stage-only` | Uploads a **saved remote version**, runs cloud tests against that version, writes local `.tested.json`; does not publish. The configured place/universe are the actual remote target, not an automatically separate staging environment. |
| `test-and-deploy.luau ... --publish-tested` | Verifies COMPLETE receipt, universe/place, task path, saved version and exact artifact hash, then uploads those bytes as **published** and writes `.published.json`. Does not rerun tests or establish compatibility/freshness of the old result. |
| `test-and-deploy.luau` with no mode | Saves, executes cloud tests, then publishes on success. Do not run it as a routine test. |
| `release-places.luau` | Verifies manifests/commit/targets, stages and tests every selected place, then publishes in sorted order **arena → lobby**. In GitHub Actions it also requires current `prod` HEAD. A failure can leave saved versions or a partial publication. |
| `.github/workflows/cicd.yml` | PR/main checks build both places. A **push to prod** after required jobs succeeds deploys affected places; therefore an owner push/merge can publish. Artifact retention is configured for 14 days. Archive the approved rollback bundle before expiry. |

Sources: [test-and-deploy](../src/scripts/lune/test-and-deploy.luau), [release-places](../src/scripts/lune/release-places.luau), [receipt verification](../src/scripts/lune/release-receipt.luau), [artifact verification](../src/scripts/lune/release-artifact.luau), [cloud payload](../src/scripts/cloud/RunTests.luau), [existing CI](../.github/workflows/cicd.yml). The cloud payload invokes the in-place TestEZ runner; `COMPLETE` is that runner's result, not physical-device, load, persistence-isolation or final visual acceptance.

For a concrete owner-reviewed candidate whose namespace/targets are already approved, the existing direct **stage-only** command for one artifact is:

```powershell
$env:ROBLOX_UNIVERSE_ID = '10464667217'
$env:ROBLOX_PLACE_ID = '121997450145716'
lune run src/scripts/lune/test-and-deploy.luau .review/owner-release/CANDIDATE/place-arena/dist.rbxl src/scripts/cloud/RunTests.luau --stage-only
```

This example targets the **existing arena**, remotely saves a version and runs code; it is not authorized execution by the agent and is blocked until the owner resolves the conditions above. For an isolated rehearsal, the owner supplies explicitly approved test-universe/place targets instead. Normal production promotion should use the existing coordinated CI path so all affected artifacts are tested before publication. Do not bypass its current-prod-head or manifest checks, synthesize `.tested.json`, or paste a direct unverified publish command during incident triage.

## Rollback decision and rehearsal

No compatible previous two-place artifact pair, approved rollback order or successful rehearsal is established by this document. The owner must retain both prior `dist.rbxl` files, manifests, dependency lock identity, actual source commit, `.tested.json`, `.published.json`, saved/published version IDs, asset permissions and effective configuration. Check that the previous code understands the current profile schema, `S1`/product identities, receipt tombstones and new crate-open recovery state. Existing running servers and sequential place publication can leave mixed versions even after a successful upload.

If a compatible exact previous artifact has valid retained test evidence for the intended target, the inspected tool supports owner publishing those bytes again:

```powershell
$env:ROBLOX_UNIVERSE_ID = '10464667217'
$env:ROBLOX_PLACE_ID = '121997450145716'
lune run src/scripts/lune/test-and-deploy.luau .review/owner-release/PREVIOUS/place-arena/dist.rbxl src/scripts/cloud/RunTests.luau --publish-tested
```

**This is a real publish, not a rollback preview.** It creates a published version from the retained bytes, trusts the hash-bound COMPLETE receipt, and does not restore profile data or live configuration. The command is conditional documentation only; no `PREVIOUS` bundle is designated ready. Do not substitute today's artifact under yesterday's receipt. If evidence or compatibility is missing, stop and prepare/retest an approved compatible candidate through the existing workflow. `release-places` will reject a previous manifest under a different checkout commit; that guard is intentional, not a reason to alter manifests.

Before releasing, rehearse the chosen forward/rollback pair on the owner-approved isolated targets, including a partial two-place update and old-running-server journeys. Normal forward order is arena then lobby; choose rollback order from tested mixed-version compatibility, not an assumption that reversing the order is safe. Following any real rollback, the tester verifies new/returning profile load, party assignment, both teleport directions, retained-player replay and pending award/receipt recovery; the owner reconciles actual published versions and effective config before resuming arrivals.

## Incident record and handoff

For each hold, retain: UTC first/last observation; release commit and both actual place versions; universe/place/job; real or mock profile mode and namespace; effective config; player count and global queue versus same-arena replay mix; device/input/viewport and measured network conditions; exact symptom and reproduction; numerator/denominator/window; logs/screenshots/trace paths; affected purchase/award identity in restricted evidence; owner action; before/after result; remaining uncertainty. Keep a short explicit disposition: investigating, held, fixed pending verification, or owner-cleared to resume.

Release owner signs off named operators, verified observation access/ingestion, actual baselines, exact artifact/version/config manifest, compatible rollback evidence and the candidate's remaining player/content/device/service gates. This sheet supplies the procedure; it does not close those gates or establish readiness for 30,000–50,000+ CCU.
