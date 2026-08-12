# SPLAT BRAWL

**Game Design Document — v0.3**
Roblox PvP Arena Brawler — Dodgeball & Inflatable Hammer Combat

> v0.3 (2026-07-24): recall removed; added a dedicated timed catch, persistent contested match balls, a pre-match countdown, combined mode/map voting, late-join rules, and exact respawn timing.

## 1. High Concept

Splat Brawl is a fast, skill-based PvP arena game built around two asymmetric weapons — throwable dodgeballs and melee inflatable hammers — set in a bright, bouncy-castle aesthetic. Players fight in Free-for-All and Team Deathmatch modes across small, symmetric arenas designed for constant engagement and readable counterplay.

- **Genre:** Arena Brawler / PvP Shooter-Melee Hybrid
- **Platform:** Roblox
- **Target Session Length:** 3–6 minute matches, designed for repeat-play loops
- **Comparable Titles:** Goofy Gorillas (core weapon feel), Rivals (combat pacing), Arsenal (mode structure)

## 2. Core Pillars

- **No competitive advantage** — nothing purchasable affects combat outcomes. Skill determines who wins, not spending. Progression boosters (XP/Cash multipliers) are permitted because they change how fast you earn cosmetics, never how a fight resolves; weapon, movement, damage, cooldown, and health values are never for sale.
- **Fast respawn, fast re-engagement** — FFA returns players in 1 second; TDM uses readable 4.5-second team waves.
- **Bright, tactile, bouncy** — every surface, effect, and hit reaction reinforces the inflatable/foam fantasy. (Not needed)

## 3. Core Mechanics

### 3.1 Dodgeball (Ranged)

- Every entrant receives one persistent dodgeball for the match. Thrown balls remain in the arena as contested objects; any player without a ball can automatically pick up a resting ball. Lost balls are moved back to an authored recovery point without creating a replacement. There is no recall.
- Aim assist can curve a valid throw toward a target inside the device-specific selection and validation cones.
- Direct hit = elimination.
- A dedicated catch input opens a short, directional catch window. Only an approaching opponent ball inside the configured distance and cone can be caught; successful catches transfer possession.
- **Tempo (balance baseline):** ~0.6s between throws, a 0.18s catch window, and a 0.65s catch cooldown. Ball scarcity and positioning replace recall as the ranged loop.

### 3.2 Inflatable Hammer (Melee)

- Always equipped, no pickup required — the default weapon.
- Swing into a dash that brings you forward to hit players.
- Direct hit = elimination + knockback (useful for ring-out map variants later).
- Miss = a 0.4–0.6s recovery window where the player is vulnerable — this is the whiff-punish window that keeps hammer play from dominating dodgeball.
- **Swing cooldown (v0.2):** lengthened to ~1.5s between swings (previously ~0.8s). Each swing is a commitment, not something to spam while closing distance.
- **Whiff self-stun (v0.2):** a missed swing ends with a very slight self-stun (~0.25s at ~25% move speed), stacked on top of the miss-recovery window. Deliberately subtle — a stagger, not a freeze — and it never triggers on a clean hit, so good hammer play stays fluid while a whiffed swing is decisively punishable.

**Balance intent (v0.2):** the hammer keeps its up-close lethality and dash mobility, but is less forgiving — a hammer player must pick their moment. Spamming swings now loses to a dodgeball player who keeps range: every whiff means a long cooldown plus a slow, punishable recovery.

### 3.3 The Combat Triangle

This triangle is the entire balance foundation and should not be diluted with additional weapons in v1:

| Situation | Advantage | Why |
|---|---|---|
| Hammer vs. Dodgeball up close | Hammer | When you click your hammer, it's a dash hit — but only one attempt per cooldown; a miss is punishable. |
| Dodgeball vs. Hammer rusher | Dodgeball | Range beats melee approach, and the v0.2 cooldown + whiff-stun mean a rusher can't mask bad approaches with swing spam. |

## 4. Game Modes

### 4.1 Free-for-All (FFA)

- 8 players, small-to-medium arena.
- Win condition: first to elimination target (e.g. 15) or highest score at time cap (5 min).
- Respawn: 1 second, followed by 1.5 seconds of spawn invulnerability.
- Scoring: 1 pt per elimination; no team bonuses.

### 4.2 Team Deathmatch (TDM)

- 2 teams, 4–6 players each, color-coded uniforms/inflatables.
- Win condition: score cap (e.g. 40) or higher score at time cap (6 min).
- Respawn: synchronized 4.5-second waves with an exact server-time countdown, preserving team push/retreat rhythm.
- Ball supply: one persistent ball per entrant. Late joiners receive one ball on their first arena spawn; respawns do not create more.

### 4.3 Match Loop and Intermission Lobby

- A 3-second `Starting` phase follows arena teleport. Combat inputs are suppressed until it reaches `Active`.
- During the first 10 seconds of Intermission, players vote among up to three compatible mode/map pairs. The highest count wins; ties resolve randomly on the server.
- Players joining during `Starting` or `Active` enter immediately. TDM assigns them to the smaller team, with deterministic team-order tie breaking.
- Match arenas are templates under `ReplicatedStorage.Assets.Maps` and are cloned into `Workspace` only for an active match and its results presentation.
- `Workspace.Lobby` is a permanent, Studio-authored intermission area. It is never cloned, reparented, or destroyed by the match/map lifecycle.
- When Results ends, players who participated in that match return to `Workspace.Lobby.PlayerSpawns`; match balls and terrain bindings are cleared, then the arena clone is destroyed.
- New arrivals are not sent to the lobby. They remain at their normal arrival location until admitted into a match.
- Returning participants remain in the lobby through intermission and any subsequent wait for enough players. The next match teleports all admitted players to the newly cloned arena.
- Shops, crate opening, and other lobby interactions will live in this permanent area but are outside the current gameplay pass.

## 5. Map Design

Launch with 3 maps, each testing a different balance of the combat triangle:

| Map | Mode Focus | Key Feature |
|---|---|---|
| The Pit | FFA | Small, chaotic arena with short recovery routes that force constant hammer contact |
| Foam Court | TDM | Symmetric 3-lane layout with fair team spawns, foam pits, and a mid control platform |
| Sky Bounce | TDM / FFA | Two-level map — hammer-favored upper walkways, dodgeball-favored ground floor, bounce pads for repositioning |

Shared design rules: no sightline longer than ~25 studs (keeps dodgeball from becoming a pure sniping tool), bounce pads and foam pits used as terrain-based mobility/dodge tools, symmetric layouts for TDM to keep team spawns fair.

## 6. Progression & Retention

Persistent stats — eliminations, catches, win rate, K/D — are visible on the profile for competitive players to chase. They carry no reward and no stat impact.

### 6.1 XP & Cash earn rates

Both currencies are awarded from the same match events. Values live in `Config.Data`; this table is the design intent, the config is the source of truth.

| Event | XP | Cash |
|---|---|---|
| Match complete | 25 | 50 |
| Win | 100 | 150 |
| Elimination | 20 | 10 |
| Catch | 15 | 15 |

An average player earns roughly **165 XP and ~150 Cash per match**, about **1,650 XP / 1,500 Cash per hour** at ~10 matches an hour. Daily quests add ~495 Cash/day on top.

Career XP (`Level.Points`) is lifetime and never resets — it exists for the leaderstat. Season XP is a separate, season-scoped counter. Neither is derived from the other; they are kept in step by a single award path at match commit.

### 6.2 Daily quests

Three quests per day, drawn deterministically per player from a ten-quest pool, resetting at UTC midnight. Rewards are Cash. Completed-but-unclaimed quests are paid out automatically at rollover so nothing is lost to timing.

### 6.3 Season structure

- **6 weeks** per season, with a **1-week rest gap** before the next — long enough to avoid burning content, short enough to stay a reason to return.
- **25 tiers**, threshold `600n + 8n²`, ≈20,000 XP to complete — about **12 hours of play**, comfortably inside a 6-week window for a casual player.
- **Free track**: Cash and five trails. It has to be worth engaging with on its own; it is the on-ramp that makes the premium track legible before anyone is asked to pay.
- **Premium track**: sixteen further rewards, ending in a season-exclusive trail that is **retired permanently** when the season closes.
- Rewards are **claimed manually**, not auto-granted, so the player sees what they earned. Anything still unclaimed at rollover is granted automatically rather than lost.

## 7. Monetization

Cosmetics and progression boosters only. Nothing purchasable affects combat — see §2.

### 7.1 Currency model

- **Cash** — soft currency, earned from matches and quests. Never a competitive resource; it buys only cosmetics.
- **Robux** — hard currency. Buys Cash bundles, direct crate opens, gamepasses, and the season pass.

Cash is deliberately the *only* thing Robux converts into on the random-reward path, so every purchase route has an earnable equivalent.

### 7.2 Crates

| Crate | Cash price | Pool |
|---|---|---|
| Ball Crate | 500 | 9 ball skins |
| Trail Crate | 1,000 | 40 droppable trails |

Rarity weights: Common 70 / Rare 24 / Legendary 6. Exclusive is weight 0 — it never drops and exists only as pass entitlements.

**Duplicate protection.** A duplicate refunds Cash by rarity (50 / 150 / 400).

**Pity.** Per crate, a Rare or better is guaranteed within **5** opens and a Legendary within **25**. Counters reset when the rarity drops naturally. **The pity rule is disclosed in the odds panel** — a guarantee the player cannot see does none of the trust work that justifies it.

**Odds disclosure.** Every possible outcome and its probability is shown before purchase, summing to exactly 100%. Percentages use largest-remainder allocation precisely so they sum correctly; rounding each independently does not.

### 7.3 Direct purchase

Any droppable cosmetic can be bought outright for Cash: Common 1,200 / Rare 3,500 / Legendary 12,000.

This exists because RNG-averse players otherwise have nothing to spend Cash on, and because one sink is not an economy. The pricing holds two invariants, both pinned by tests:

- Direct buy is **cheaper than chasing one specific item** through crates (12,000 vs ~200,000 expected for a named Legendary), so targeting is always the rational choice for a specific want.
- One crate open is **cheaper than the cheapest direct buy** (1,000 vs 1,200), so crates stay the value play for breadth.

Crates win on breadth, direct buy wins on targeting. Neither dominates.

### 7.4 Gamepass catalog

| Pass | Robux | Grants |
|---|---|---|
| Splat Starter Kit | 49 | 1 exclusive trail |
| Trail Collection | 149 | 5 exclusive trails, no boosts |
| Double XP | 199 | 2.0x XP |
| Cash Boost | 249 | 1.5x Cash |
| Brawler's Club | 499 | 2.5x XP, 1.5x Cash, 2 club trails |
| Founder's Pack | 999 | The above plus the Founder's Crown trail; retired after launch |

**Stacking is max-wins per multiplier type**, never multiplicative — owning Double XP and Brawler's Club gives 2.5x, not 5x. Brawler's Club is deliberately 2.5x so that upgrading from Double XP is never a dead purchase.

Trail Collection is intentionally booster-free: there is a pure-cosmetic option for players who want no mechanical advantage at all.

Passes for hammer skins, costumes, and emotes stay merchandised as "coming soon" until that content exists. They are never sold empty.

### 7.5 Season pass

**499 Robux** for Season 1 — introductory. The GDD previously targeted 799; that is the goal once the track has a proven season of content behind it, and pricing an unproven pass at 799 suppresses first-season attach rate.

One product per season rather than one reusable product, so receipt history is unambiguous about which season was bought.

### 7.6 Compliance

- Paid random items follow Roblox policy: all outcomes and numerical odds shown before purchase, summing to exactly 100%, reachable from a details control.
- `PolicyService` gates **both** crate payment paths. A restricted player who has already been charged is still made whole — they receive the crate's Cash value instead of a random roll, because an already-charged receipt must never be stranded in retries.
- `ProcessReceipt` is idempotent: purchase IDs are recorded permanently in the profile, so a retry after a grant acknowledges without re-granting.

### 7.7 Pricing philosophy

- A price point at every wallet size, 49 → 999, because a single tier converts far worse than a ladder.
- **Soft urgency only.** Countdowns appear only on things that genuinely rotate or expire: the weekly featured slot, the season, the 72-hour starter offer, daily quests. No fake scarcity, no countdown on an evergreen SKU, no manufactured "only 3 left".
- The featured slot rotates weekly on a **global** schedule with a real 15% discount the server actually charges — a per-player rotation would make the countdown a lie.
- What is never sold: weapons, movement, damage, cooldowns, health, or anything else that decides a fight.

## 8. Technical Notes (Roblox-Specific)

- Server-authoritative hit detection for both dodgeball and hammer to prevent client-side exploiting — do not trust client RaycastResult for eliminations.
- Catch windows are deterministic sim state driven by the dedicated Catch input; validation of direction, distance, ownership, team, and approach happens in the server-authoritative simulation.
- Respawn waves (TDM) handled via a server-side timer service, not per-client.
- StreamingEnabled recommended if Sky Bounce map grows beyond a single streamable region.
- Reuse your existing DataStore persistence pattern (as in Pizza Shift) for stats, XP, and cosmetic ownership.

## 9. KPIs & Analytics

Targets to judge the economy against. Every one maps to an event that is already emitted, so none of these require new instrumentation.

| Metric | Target | Measured by |
|---|---|---|
| Payer conversion | 2–4% of DAU | `ShopPurchase` funnel `Completed` / `Opened` |
| First-purchase conversion (72h window) | 3–5x the non-offer baseline | `SplatStarter` grants vs. `Onboarding.FirstJoinAt` cohort |
| Season pass attach rate | 5–10% of active players | `SeasonPassS1` receipts / season-active players |
| D1 retention | 35%+ | Onboarding funnel `FirstMatchCompleted` → next-day `Joined` |
| D7 retention | 12%+ | Same, seven-day window |
| ARPDAU | Track, no launch target | Robux `Source` economy events / DAU |
| Cash faucet vs. sink | Sink within 70–110% of faucet | `Source`/`Sink` economy events, `Gameplay` vs `Shop` |
| Crate → direct-buy split | Neither below 20% of Cash spend | `Sink` events by `itemSku` |

Two of these are guard rails rather than growth targets. **Faucet vs. sink** catches an economy drifting into either inflation or a grind wall. **Crate/direct split** catches one path dominating: if direct buy falls below 20%, the RNG-averse player has no real option; if crates fall below 20%, the gamble has stopped being the better deal for breadth and its pricing needs revisiting.

Instrumentation gaps worth knowing: economy events record `endingBalance` as `0` on the Robux receipt path, and Studio sessions log to console rather than to Roblox analytics.
