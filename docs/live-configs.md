# Live configs

Roblox experience configs (`ConfigService`) let a value in `src/config` change in a
running game without a republish. This document covers what is exposed, how to author
it, and what happens when the config service is unavailable.

## What can change live

Only leaves declared in `src/config/LiveConfig.luau` are live-updatable. Anything not
listed there can never be changed by a config, no matter what is authored in Creator
Hub. Each entry declares the key, its type, and its accepted range.

Currently in scope: `Combat`, `AimAssist`, `GameModes.VoteDurationSeconds`,
`MapFeatures`, and the lobby's `Matchmaking` scalars.

The shop's A/B levers are also in scope: `Shop.VariantId`, the three rotation
periods, `Shop.Featured.DiscountPercent`, and each crate's `BonksPrice`. Varying
these per cohort is how a pricing experiment runs; `VariantId` labels the cohort
and is stamped on every shop analytics row, so a result can be attributed to the
configuration that produced it.

Their ranges are load-bearing rather than decorative. `CrateConfig.spec` proves
that every combination the allowlist permits still satisfies both published
economic guarantees *at the discounted price actually charged* -- narrow a bound
and that spec keeps you honest; widen one and it fails.

Deliberately out of scope: monetization (`Products`, `GamePasses`), asset IDs
(`Cosmetics`, `Audio`), the input map, and the rest of the economy tables
(`Data`, `Quests`, `Seasons`, `Inventory`). Rarity `DirectBonks`/`DupeBonks` are
excluded on purpose: they sit on the far side of both guarantees, so a live
override there could make crates strictly worse value than buying outright.

`GameModes.Modes[].Enabled` is **not** live-updatable: `VoteOptions` is derived from it
at module load and copied by the lobby, so changing it live would leave the two out of
sync. Enabling or disabling a mode remains a republish.

## Authoring a config

1. Open the experience in Creator Hub, go to **Configs**, and create a config whose key
   is exactly the key string from `LiveConfig.Entries` — for example
   `Combat.Dodgeball.ThrowSpeed`.
2. Set the type to match the entry's `Type` (every entry is currently `number`).
3. Set the value inside the entry's `Minimum`/`Maximum`. A value outside the range is
   rejected at runtime and the baked value is kept.
4. Publish. Updates take up to 5 minutes to reach live servers; staged changes reach
   team members in Studio within about a minute.

A key that is deleted in Creator Hub reverts that leaf to the value baked into
`src/config`, exactly as shipped.

To try a value on one server without publishing it, use `ConfigService:SetTestingValue`
and `ConfigService:ClearTestingValue` from the server. Testing values stay local to that
server.

## Sim-critical values latch to a match boundary

`ConfigService` is server-only, but `Combat` and `AimAssist` are read by the
deterministic sim on both the predicting client and the authoritative server. If the two
sides ran different constants, prediction would mispredict continuously.

So overrides for those two modules are staged rather than applied while a match is
running, and adopted at `MatchPreparing` — the start of the countdown, before the match
goes Active. The server applies and publishes them in the same step, so clients adopt
them during the countdown. Every other module applies immediately.

`ReplicatedStorage.ConfigState` carries the active override set as one value object per
override — a `NumberValue`, `BoolValue`, or `StringValue` matching the declared type —
named after the key with dots replaced by underscores, so
`Combat.Dodgeball.ThrowSpeed` becomes a `NumberValue` named `Combat_Dodgeball_ThrowSpeed`.
A key with no override has no child at all, which is how absence stays distinguishable
from a legitimate value of `0`.

`revision` is a single attribute on the folder, bumped last, and is what clients react to,
so a client reads a fully written set. This is the commit pattern `ModeVoteState` uses.

Value objects rather than attributes because server-authority replication caps an
instance's **total attribute payload at 1024 bytes**, which this many keys exceeds
outright, and separately caps string attribute *values* at 50 characters. A changed
`Value` property replicates as a small typed delta, which is the shape that replication is
built for. Neither side reverses the name mapping: both walk `LiveConfig.Entries` and
derive the name from the key.

A spec keeps the projected names distinct and dot-free, so two keys can never collide onto
one child.

## Behavior when configs are unavailable

The game runs on the values baked into `src/config` whenever live values cannot be
obtained. Specifically:

- If `GetConfigAsync` fails or never returns a snapshot, the baked values stay and the
  server retries every `RetrySeconds`.
- If the snapshot reports `Error ~= ConfigSnapshotErrorState.None`, the currently applied
  values are kept rather than cleared.
- A resync is all-or-nothing: if any single key read fails, the whole resync is abandoned
  and the previously applied set survives untouched.
- Any value failing type or range validation is dropped with a warning; the rest still
  apply.
- Keys not in the registry are ignored rather than applied.
- Clients re-validate the replicated payload against the same registry, so a malformed
  payload installs nothing.
- A client that never receives a payload keeps its baked values.

`ConfigSnapshot.UpdateAvailable` is the primary signal: it triggers `Refresh()` followed
by a resync. A periodic resync every `ResyncSeconds` runs as a safety net in case the
event does not fire.

## Adding a new live key

1. Confirm the leaf's container is not frozen — `ConfigOverrides.writePath` refuses to
   write into a frozen table, so the override would silently do nothing.
2. Add an entry to `LiveConfig.Entries` with a sensible `Minimum`/`Maximum`. The range is
   the safety net against a mistyped value in Creator Hub reaching gameplay.
3. If the leaf's module is read by the deterministic sim, add the module to
   `LiveConfig.SimCritical` so it latches to a match boundary.
4. Register the module in the place's `ConfigLiveService.start` call, and in that place's
   `ConfigReplication.startClient` call if clients read it.
5. Create the config in Creator Hub with the matching key.

Consumers need no change: overrides are written into the config table they already read,
so anything doing `Combat.Dodgeball.ThrowSpeed` picks up the new value. Code that copies
a config value into a local at module load will not, and should read through the table
instead.
