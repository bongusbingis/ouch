# Post-match flow

The arena post-match experience is an event-driven presentation over existing match, progression, party, and teleport owners. It does not calculate wins, award currency, mutate profiles, or run a second matchmaker.

## Runtime ownership

- `MatchService` owns the authoritative match phase, winner, scores, participant roster, and result lifetime.
- `ProgressionService` remains the only match reward committer. It exposes the exact summary it already awarded, including XP, Bonks, boosts, and season state before/after the award.
- `PostMatchService` joins those facts into one player-specific result packet and owns server validation for post-match actions.
- `ArenaReturnService` owns lobby teleport retries and the one-reset party-retention decision used by Play Again.
- `ArenaSessionService` owns party identity from the lobby teleport payload and selects an effective leader. The original leader remains leader while present; otherwise the lowest present user ID takes over.
- `PostMatchClient` owns the local result screen lifecycle and the `PostMatch` combat-cursor request.
- `PostMatchScreen` is presentation-only and can render production or debug data without requiring networking or profile services.

## State flow

```text
Active
  -> Results / authoritative result packet
  -> 0.8 second reveal within a 12-second Results phase
  -> interactive results
       -> Play Again: retain the whole party for this reset
       -> Cancel Play Again: release that retention
       -> Return Party to Lobby: leader returns every present party member
       -> Leave Party & Return: non-leader separates and returns only themselves
  -> MatchReset
       -> retained parties stay for the next arena vote
       -> all other matched parties return to the lobby together
  -> Intermission / next game-mode vote
```

Detailed reward animation never gates the action buttons. The results UI is removed as soon as the authoritative phase leaves `Results`; combat input becomes active only when the existing simulation client observes `Active` again.

The server enforces `interactiveAt`; Reduced Motion snaps visual motion but does not create an earlier action window. The screen renders the authoritative expiry as a countdown and progress bar.

The initial result packet contains the in-memory statistics immediately and truthfully marks its real reward calculation as pending. This reserves the progression card without inventing values or changing the page width later. Entitlement checks and per-player reward commits run concurrently, never inside the serial match-event dispatch. When an exact committed summary becomes available during `Results`, the server republishes the same result ID with its real reward fields; this update neither restarts the reveal nor cancels an action already in flight.

The current same-server replay path intentionally reuses the arena's existing Intermission vote. It does not yet send a retained party back through the global lobby queue or backfill that arena from other servers. A future population coordinator can replace the retention implementation behind `ArenaReturnService.retainParty` without changing the result UI or request contract.

## Result contract

`Shared.Game.PostMatch.PostMatchResult` is the boundary between gameplay facts and presentation.

Production-required player fields:

- schema and result IDs;
- mode ID and display name;
- outcome;
- authoritative winner ID when one exists;
- reveal and expiry server timestamps;
- presentation copy derived from the real mode result;
- ordered score entries;
- tracked personal statistics.

Optional fields:

- FFA placement;
- match XP, season XP, Bonks, bases, and multipliers;
- season before/after progress;
- challenge progress and unlock presentation;
- party members and effective leader.

The optional layout collapses cleanly. Missing reward, season, score-detail, or party information does not create an empty card. The contract and debug story support challenge and unlock presentation, but production challenge deltas and unlocks are not emitted until their authoritative owners provide them. Dodgeball hits, hammer hits, accuracy, streaks, and podiums are not currently calculated and are therefore not sent to production clients.

Future systems should add their result values to the server-side personal summary and extend the shared result projection. They should not make the React component require gameplay services or write profile data from UI code.

## Networking

- `PostMatchResult` event: one authoritative result packet per eligible player.
- `PostMatchStatus` event: party action state, effective leader, revision, and current party projection.
- `PostMatchRequest` function: `PlayAgain`, `CancelPlayAgain`, `ReturnToLobby`, or `LeaveParty`, always paired with the current result ID.

The server rejects stale result IDs, requests before the reveal gate, requests outside `Results`, and every party-wide request from a non-leader. Status revisions prevent an older response from replacing a newer party decision. `ReturnToLobby` is a leader-only grouped operation for every present party member. `LeaveParty` is available only to a non-leader in a multi-member party; its authenticated return payload removes that player from the surviving party record before the lobby creates their solo party. Both paths use the existing retry/loading coordinator.

## Debug preview

Open `Shared/UI/Stories/PostMatchScreen.story` in the React story tooling. Its top development toolbar cycles through:

- TDM victory with a party of four;
- TDM defeat;
- FFA first place;
- FFA sixth place;
- Survivors win;
- Infected win;
- no rewards;
- rewards pending and boosted rewards with a tier transition;
- tied/no-winner result;
- missing optional party projection;
- example future challenge progress;
- example future unlock presentation;
- party of one;
- non-leader party-member controls, self-return in flight, and request failure.

The story reads only `DebugPostMatchData`. Its actions change local React story state and never call Network, PlayerData, or any reward service.

## Device behavior

- PC: the centralized combat module releases mouse lock for the `PostMatch` cursor reason.
- Touch: combat gestures are already disabled outside `Active`; the action row uses large touch targets and the compact landscape layout.
- Controller: the result root is a selection group. Play Again receives default focus for leaders, while Leave Party & Return receives it for non-leaders.
- Reduced Motion: result springs snap to their resting state.
- All text uses `ResponsiveText`; no result label uses `TextScaled`.
- The backdrop is full-bleed; interactive content is constrained to the device safe area and a 1920x1080 maximum canvas. Portrait canvases are height-bounded from their width instead of stretching the landscape composition.

## Manual acceptance

1. End FFA, TDM, and Infection through the authoritative match tools and verify mode-specific copy, winner, scores, and FFA placement.
2. Test a win, loss, and tied/no-winner result.
3. Confirm only existing eliminations, catches, knockouts, XP, Bonks, boosts, and season progress appear.
4. Verify missing rewards or season data removes the section without an empty panel.
5. Test solo, party leader, party member, four-member party, leader disconnect, and member disconnect.
6. Have the leader choose Play Again, cancel it, and choose again. Verify every member receives the status change.
7. Verify a retained party stays for the next game-mode vote and a non-retained party returns through the existing loading/retry UX.
8. Trigger Return Party to Lobby as leader. As a member, trigger Leave Party & Return and verify only that player receives the separating payload, the remaining party stays together, and the returning player arrives in a solo party. Exercise Retry and Stay for both paths.
9. Verify combat buttons, touch gestures, and camera attacks cannot fire during Results and return during Active.
10. Verify mouse, touch, controller focus, Reduced Motion, phone landscape, tablet, desktop, and TV-like aspect ratios.
11. Repeat several rounds and confirm one result root, no duplicate handlers, no stale result, and no retained decision leaking into another reset.
