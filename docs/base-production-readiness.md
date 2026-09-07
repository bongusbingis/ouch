# Base production readiness

Implementation authorized after the read-only September 6 audit. Preserve current ownership, complete cosmetics, Marketplace-owned Robux prices, landscape mobile support, chat/report controls, and the authored visual style.

## Work and acceptance

- [x] Reconcile passes for the full profile lifecycle, including loading beyond 30 seconds.
- [x] Isolate combat input budgets by player and bound transient event packets.
- [x] Validate engine movement at the authoritative adapter boundary with explicit legitimate-motion allowances.
- [x] Allocate full-population grounded spawns and integrate native character replacement with match respawns.
- [x] Recover delayed commerce UI through authoritative receipt/entitlement state.
- [x] Repair analytics custom fields, combat counts, and economy source coverage.
- [x] Gate completion rewards on participation and bound repeat-opponent farming without changing combat outcomes.
- [x] Lock dependencies and harden build/test/release artifact handling.
- [x] Apply landscape orientation and hide offers without platform identities.
- [x] Remove animation-completion dependence from loading readiness; verify mount, hide, and reopen.
- [ ] Finish Creator Hub pass names/sale settings, arena capacity, and the live Effects Crate override.
- [ ] Save/import the reviewed Studio bases and run both exact-artifact Open Cloud suites before publication.
- [ ] Complete real billing, regional-account, multiplayer, device, and latency acceptance.
- [ ] Schedule a successor before S1 ends on October 13, preserving existing paid identities and earned progress.

## Implementation boundaries

PlayerData remains the profile owner; GamePassService reconciles entitlements, MonetizationService owns receipts, and ShopClient derives purchase recovery. ServerAuthAdapter owns incoming input scheduling and movement validation; MatchService owns spawn/death consequences and ProgressionService owns participation. AnalyticsService owns the platform schema. Studio-authored place files are written only through Studio and the existing published-place importer.

Unconfigured preview offers may be hidden for the base release while retaining their identities and fulfillment. Existing paid products and earned season progress must remain payable. Real currency is never spent without a designated QA purchase. Publication requires complete tested artifacts; incomplete verification is recorded rather than relabeled as production acceptance.

## Evidence from September 6–7

- Final headless tests: 724 passed. Shared, arena, and lobby lint and formatting passed earlier, and the loading/native-death files were formatted during implementation. The final whole-tree lint/format rerun was blocked when macOS intermittently stopped accepting new processes (`Resource temporarily unavailable`, OS error 35 / `EAGAIN`), including attempts using the pinned binaries directly. The last loading callback and focus edits still need that static-check rerun; the loading client regression and subsequent normal startup passed.
- Final Studio suites: arena 245 passed, lobby 83 passed. The five cloud-only arena Environment checks were excluded because Studio Play is not their target environment.
- Both explicit Rojo project builds passed before the last loading/native-death fixes. A merge into a temporary fixture copy passed without modifying its input place; this checks merge execution, not release asset completeness. `wally install` returned successfully, but Rojo later disconnected during the macOS resource failure and left some Studio package aliases missing. All 13 aliases in both Edit models were synchronized to their exact installed files, including Janitor, Cmdr, TestEZ, and Promise. Reconnect sync before the final command-line/artifact checks.
- Normal arena play verified grounded spawning, walking, correction of an injected client teleport, the world podium, and round repeat. Native death now enters match elimination while preserving Roblox's replacement lifecycle; the replacement waits for its wave and returns to grounded Running state. If native health reaches zero during an existing combat ragdoll, MatchService restores the body state and explicitly requests character replacement, retrying failures while that same dead character remains. Ordinary combat eliminations still restore the existing character. This uses Roblox's [LoadCharacterAsync lifecycle](https://create.roblox.com/docs/reference/engine/classes/Player#LoadCharacterAsync).
- Loading presentation passed three announcements: initial animated mount, static reopen, and animated reopen; hiding did not announce readiness. Normal arena startup reached `ReactLoadingPresented` and `ArenaReady` after the fix. Repeatable client check: `src/scripts/studio/verify-loading-presentation.luau`.
- A six-second native respawn missed the first TDM wave and was held for the next wave before returning to Running. With the default Health regeneration script disabled for the test, native health loss during a ragdoll recovered to Running with 100 health in both FFA and TDM. Regeneration can otherwise heal the same ragdolled body before its wave, which is also a valid recovery; replacement is needed only if native health remains zero.
- The current account's four configured passes reconciled through the running server's actual ownership cache and fulfilled their grants. No real-money purchase was made. Studio fixtures cover lost notifications, saved receipts, and partial pass fulfillment.
- Lobby startup loaded its profile without a game-code error. A later lobby screen capture stalled in Studio tooling, so this is not a fresh certification of every visual state or physical device.
- Loading and ballot focus restoration now use the shared ancestor-visibility guard. One invalid-selection warning still appeared in the last resource-constrained startup and needs tracing in a clean controller run. That run also warned while waiting for streamed `InnerRing.Origin` and `OuterRing.Origin`; both origins subsequently existed on the client and `ArenaReady` became true. This was delayed client streaming, not a missing server-authored marker; check its timing again under normal system load before changing the hierarchy.
- Studio Edit arena markers are 20 general / 10 Red / 10 Blue with supporting-ground and headroom checks. `src/scripts/studio/author-production-spawns.luau` is the repeatable authoring recipe. These are authored Studio changes, not an imported or published place artifact.

## Remaining release gates

Creator Hub access is awaiting sign-in. Four passes are still off sale; Showtime still has its platform stub name. The running server still reads an Effects Crate price of 750 from live configuration; remove that override to adopt the baked 500. See `shop-platform-release.md` for exact IDs, names, proposed settings, and unchanged product grants. Player-facing Robux prices remain entirely Marketplace-owned.

The repository has no imported base under either `places/arena/` or `places/lobby/`, and this session has no Open Cloud credentials. Existing root-level place files have not been assigned guessed identities. No changes have been published. Both Studio windows were left in ordinary Edit mode with zero temporary test-disable attributes; temporary test instances and flags were removed before handoff.

Once access is available:

1. Save the reviewed authored assets from their correctly identified Studio windows. Preserve all unsaved work, and restore Rojo sync if it disconnected.
2. Import the corresponding published bases with `bash src/scripts/shell/pull-places.sh`; the importer is the only repository tool that replaces source place binaries.
3. Run `lune run src/scripts/lune/release-readiness.luau`, all three lint/format checks, and `lune run src/scripts/lune/run-tests.luau`.
4. Run `bash src/scripts/shell/deploy.sh <place>.project.json <imported-base.rbxl> --stage-only` with that place's Open Cloud environment. This uploads a Saved version and tests it without publishing. Run separately for both places; do not substitute a code-only build.
5. Exercise 20 players, opposing/observer clients, 0/100/150/200 ms latency, rotating-platform jumps, jump pads, mobile landscape, controller reconnect, real teleports/rejoins, and designated billing/region accounts. Confirm analytics ingestion and movement correction rates in staging.
6. Publish through the normal verified deployment path only after those gates pass. An active S1 is sufficient for the base release; a successor is a dated live-operations requirement, not permission to alter S1's product or history.
