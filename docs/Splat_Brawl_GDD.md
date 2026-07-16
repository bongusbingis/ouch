# SPLAT BRAWL

**Game Design Document — v0.2**
Roblox PvP Arena Brawler — Dodgeball & Inflatable Hammer Combat

> v0.2 (2026-07-16): converted from PDF to markdown; rebalanced §3.1–3.3 — hammer is now less forgiving (longer swing cooldown + slight self-stun on missed swings) so it cannot be spammed and stays in balance with the dodgeball.

## 1. High Concept

Splat Brawl is a fast, skill-based PvP arena game built around two asymmetric weapons — throwable dodgeballs and melee inflatable hammers — set in a bright, bouncy-castle aesthetic. Players fight in Free-for-All and Team Deathmatch modes across small, symmetric arenas designed for constant engagement and readable counterplay.

- **Genre:** Arena Brawler / PvP Shooter-Melee Hybrid
- **Platform:** Roblox
- **Target Session Length:** 3–6 minute matches, designed for repeat-play loops
- **Comparable Titles:** Goofy Gorillas (core weapon feel), Rivals (combat pacing), Arsenal (mode structure)

## 2. Core Pillars

- **No power creep** — cosmetics only. Skill determines outcomes, not spending.
- **Fast respawn, fast re-engagement** — dead time under 2 seconds in both modes.
- **Bright, tactile, bouncy** — every surface, effect, and hit reaction reinforces the inflatable/foam fantasy. (Not needed)

## 3. Core Mechanics

### 3.1 Dodgeball (Ranged)

- The player starts with a dodgeball in hand, throws it, and can recall it.
- The ball has an aim assist to help players and can kind of curve to players (makes it satisfying).
- Direct hit = elimination.
- **Tempo (balance baseline):** the dodgeball is the pacing reference the hammer is balanced against — ~0.6s between throws, ~2s recall cooldown. These stay unchanged in v0.2; the hammer is brought down to meet them, not the other way around.

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
- Respawn: immediate, 1.5s spawn invulnerability.
- Scoring: 1 pt per elimination; no team bonuses.

### 4.2 Team Deathmatch (TDM)

- 2 teams, 4–6 players each, color-coded uniforms/inflatables.
- Win condition: score cap (e.g. 40) or higher score at time cap (6 min).
- Respawn: wave-based every 4–5s to preserve team push/retreat rhythm.
- Team-based ammo balance: dodgeball spawns are mirrored on each side of the map to avoid one team controlling all ranged options.

### 4.3 Match Loop and Intermission Lobby

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
| The Pit | FFA | Small, chaotic, single dodgeball spawn in center — forces constant hammer contact |
| Foam Court | TDM | Symmetric 3-lane layout, mirrored ammo spawns, mid control platform |
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
- Catch window validated server-side using timestamp of throw vs. block input, with reasonable latency compensation (favor-the-shooter within ~100ms).
- Respawn waves (TDM) handled via a server-side timer service, not per-client.
- StreamingEnabled recommended if Sky Bounce map grows beyond a single streamable region.
- Reuse your existing DataStore persistence pattern (as in Pizza Shift) for stats, XP, and cosmetic ownership.
