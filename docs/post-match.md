# Post-match flow

Results is a presentation over authoritative match, reward, party and teleport owners. It never calculates a hit, grants a reward, or runs another matchmaker.

## Ownership

| Concern | Owner |
|---|---|
| Phase, outcome, score, roster, opponent-loss deadline | MatchService / MatchSim |
| Pending award journal and durable profile updates | PlayerData / MatchAwardService |
| Match progress and exact committed result summary | ProgressionService |
| Result packets, group choices, authorization and revisions | PostMatchService |
| Retention, grouped returns and recovery | ArenaReturnService / TeleportRetryCoordinator |
| Session admission, party identity and round eligibility | ArenaSessionService |
| Return reconciliation and queue transaction | Lobby PartyService / existing repositories |
| Rendering and bounded requests | PostMatchClient / React components |

## Player flow

After a normal match, the server opens a 12-second Results phase with a 0.8-second reveal gate. The screen shows the actual outcome, earned top-three appearances, personal earnings/progression and a stable next-action row. Ties share placement; a stable display sort never invents a winner. TDM recognizes contributors from the winning team. No-contest results name the interrupted round and do not award podium placement.

Viable groups **continue automatically** into the next mode vote. The footer says where the player will go when the timer expires. The leader can return the party to the lobby; a member can explicitly leave alone. The effective leader changes when the original leader leaves. The next-round indicator is disabled after acceptance; controller focus moves to Scores rather than defaulting to the Lobby exit.

If the remaining roster cannot produce a valid match, **Find players** returns the group to the lobby with an explicit queue intent. The lobby reconciles the party, waits for all expected members to arrive locally, then uses its existing ban-checked queue transaction once. Regrouping is visible and cancellable by the leader. The intent expires after 20 seconds, is consumed with the queue transition, and cannot be re-armed by a late/duplicate arrival. Membership changes cancel it. An ordinary Lobby return never autoqueues.

At reset, groups without viable retention return through the existing coordinator. It performs a reward preflight before each actual transfer, including manual retries. Pending/missing reward data surfaces a recoverable save status; teleport errors surface Try Again/Stay. Stay restores round eligibility. Transient teleport failures retain grouped retry behavior.

The production matchmaker relaxes its population target to two players after 30 seconds. FFA requires two players; TDM additionally requires two independent parties/entrants before selection. The existing developer-only solo path and Studio practice remain available. An active match losing all opposition gets an eight-second recovery deadline; a restored roster cancels it, otherwise it ends as NoContest. Earned combat progress is kept, with no fabricated win, match-completion bonus or completed-match quest progress.

## Result and action contracts

`Shared.Game.PostMatch.PostMatchResult` schema 1 carries result identity, mode/outcome, server timestamps, scores, personal statistics and optional committed progression/party/showcase fields. Appearance snapshots contain bounded cosmetic IDs and character color. Older packets without optional showcase fields remain valid. Departed contestants retain their captured elimination contribution for final standings.

The initial result marks unresolved rewards as pending. A committed summary republishes the same result ID; it neither restarts celebration nor cancels an in-flight action. Detailed reward animation never gates input. Every preview uses the shared authored rig/cosmetic factory and visible-only preview scheduler; Reduced Motion presents the same information without continuous celebration motion.

| Remote | Shape |
|---|---|
| PostMatchResult event | Authoritative per-player result |
| PostMatchStatus event | Result ID, revision, group state, leader, party, self-return flag, next destination, replay viability and optional finding-players intent |
| PostMatchRequest function | Action plus current result ID |

Actions are `PlayAgain`, compatibility `CancelPlayAgain`, `ReturnToLobby`, `LeaveParty`, and `FindMatch`. The server rejects expired results, pre-reveal actions and unauthorized party-wide requests. All group actions remain leader-owned. Client requests are bounded and stale responses cannot replace newer state.

Return payload schema 1 adds optional `queueOnArrival`. It is accepted only with the configured arena source place and universe, validated party/match identity and bounded unique members. Separate-member returns cannot request group queueing. Legacy payloads continue to return normally to the lobby. The party record retains one last-return identity and at most one expiring queue intent; no new player-profile persistence is introduced.

## Presentation and controls

The result hero, podium, personal progress and action row share the arena palette and existing interaction primitives. Flexible rounded surfaces replace broken image slicing. Phone landscape puts earnings above the fold and preserves touch targets; scores/details scroll. The new Showtime pass adds three cosmetic victory emotes through the existing EMOTES inventory slot. It changes no placement, combat or reward rules. See [Showtime](showtime-pass.md).

The custom arena scoreboard uses Tab, controller Select and Scores. Chat and pause/report remain available; the replaced native player list, health/backpack HUD and overhead labels stay disabled. Screen lifecycle releases cursor/focus ownership and cancels stale requests. During Studio QA, Tab is attempted after loading; the lobby's native CoreGui binding can reject VirtualInput, so the player list is hidden directly for that playtest.

## Verification and release

See the [arena implementation record](arena-experience-redesign.md) for exact counts and executed scenarios. Coverage includes pure eligibility/outcome/contract rules, isolated party/teleport services, actual Studio continuation, no-contest rewards, and return failure/Stay. Stories cover standings, podium appearances, pending rewards and party roles without networking or purchases.

Before publishing, save the authored rig changes in both open Studio documents and the persistent lobby scene, then run the saved-place cloud suites. Real multi-client transfers, actual billing/regional accounts and hardware/audio listening checks remain platform acceptance work. Remove the obsolete live MinPlayers=1 overrides; the allowlist now rejects them. No repository tool has rewritten a place binary.
