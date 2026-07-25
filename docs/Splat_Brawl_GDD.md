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

- **No power creep** — cosmetics only. Skill determines outcomes, not spending.
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

- Account XP levels — cosmetic unlocks only, no stat impact.
- Daily challenges: e.g. 'Eliminate 3 Players', 'Win 1 TDM match', 'Get 5 hammer eliminations'.
- Persistent stats: eliminations, catches, win rate, K/D — visible on profile for competitive players to chase.
- Seasonal battle pass, resets every 4–6 weeks, aligned with cosmetic drops.

## 7. Monetization (Cosmetics-Only)

CRATES!!!!!!

| Item Type | Examples | Price Tier (Robux) |
|---|---|---|
| Hammer assets | Banana hammer, boxing glove, candy cane | 150–350 |
| Dodgeball trail/impact VFX | Confetti splat, neon trail, sound packs | 99–250 |
| Character/inflatable costumes | Full-body assets | 250–600 |
| Elimination taunts/emotes | Victory animations | 75–150 |
| Battle Pass (seasonal) | Tiered unlock track | 799 flat |

## 8. Technical Notes (Roblox-Specific)

- Server-authoritative hit detection for both dodgeball and hammer to prevent client-side exploiting — do not trust client RaycastResult for eliminations.
- Catch windows are deterministic sim state driven by the dedicated Catch input; validation of direction, distance, ownership, team, and approach happens in the server-authoritative simulation.
- Respawn waves (TDM) handled via a server-side timer service, not per-client.
- StreamingEnabled recommended if Sky Bounce map grows beyond a single streamable region.
- Reuse your existing DataStore persistence pattern (as in Pizza Shift) for stats, XP, and cosmetic ownership.
