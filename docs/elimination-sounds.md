# Elimination sound cosmetics

Elimination sounds are world-space, presentation-only cosmetics. An accepted elimination snapshots the eliminator's `Equip_ElimEffectAssets` value and the authoritative elimination position. The arena sends that accepted event over the reliable `CombatFeed`; clients resolve the snapshotted item through `Config.Cosmetics` and play its weapon-specific cue from a fixed world anchor. The victim's equipped sound and character position after the elimination are never consulted.

Uncredited projectile eliminations use the default dodgeball cue. Eliminations without a source or projectile, such as an elimination-zone fall, use `ElimZoneFall` and do not borrow a player's cosmetic.

The nine production items are non-Exclusive `ElimEffectAssets`, so the existing economy automatically includes them in the Effects Crate. Effects are intentionally excluded from the current outfit/emote direct-shop rotation. Once owned, sounds are equipped from **Inventory → Effects → Elimination Sounds**. Common, Rare, and Legendary each ship with three items.

## Supplying asset IDs

The cosmetic definitions live in `src/config/Cosmetics.luau`. Their audio keys live in `src/config/Audio.luau` under `Gameplay`. Replace each empty string in the matching `AssetIds` list with a permitted Roblox audio URI:

```luau
AssetIds = { "rbxassetid://1234567890" }
```

More than one ID may be supplied for natural variation; one is selected randomly per play. Empty and whitespace-only entries are ignored. Until a cosmetic has a usable ID, its missing variant falls back to the matching default dodgeball or hammer elimination sound instead of becoming silent. Keep every elimination entry at `Scope = "World"`.

Each cosmetic is a paired sound family. The dodgeball variant should be tighter and brighter; the hammer variant should be lower, springier, and heavier. They should clearly belong to the same theme without being the same file pitch-shifted beyond recognition.

| Tier | Cosmetic | Audio key | Catalog target | Search phrases | Target duration |
|---|---|---|---|---|---|
| Common | Rubber Pop | `RubberPopDodgeballElimination` | Dry rubber-ball pop/thwack with a rounded, toy-like transient; no realistic impact or pain vocal. | `cartoon rubber pop`, `rubber ball thump`, `toy impact pop` | 0.12–0.28 s |
| Common | Rubber Pop | `RubberPopHammerElimination` | Chunkier inflatable-mallet bonk with one short elastic boing tail. | `cartoon rubber mallet bonk`, `spring boing impact`, `inflatable hammer squeak` | 0.22–0.45 s |
| Common | Toy Squeak | `ToySqueakDodgeballElimination` | One crisp, high toy-squeaker chirp with an immediate start. | `short toy squeak`, `rubber duck squeak short`, `cartoon squeaker` | 0.15–0.30 s |
| Common | Toy Squeak | `ToySqueakHammerElimination` | Lower squeeze-toy squeak or a fast two-note squeak that reads as a heavier compression. | `low toy squeak`, `squeeze toy double squeak`, `cartoon mallet squeak` | 0.30–0.55 s |
| Common | Balloon Pop | `BalloonPopDodgeballElimination` | Clean, soft balloon or plastic-bubble pop; avoid files that resemble a firearm. | `soft balloon pop cartoon`, `plastic bubble pop`, `party balloon pop soft` | 0.10–0.25 s |
| Common | Balloon Pop | `BalloonPopHammerElimination` | Brief elastic stretch/squeak into a fuller balloon burst. | `balloon stretch pop`, `cartoon elastic pop`, `big bubble burst sound` | 0.25–0.50 s |
| Rare | Party Horn | `PartyHornDodgeballElimination` | Short single party-blower toot with a playful upward flick. | `party blower short`, `party horn toot`, `celebration kazoo short` | 0.25–0.55 s |
| Rare | Party Horn | `PartyHornHammerElimination` | Larger party horn or descending party-blower flourish, still tightly edited. | `party blower descend`, `comedy party horn`, `celebration horn short` | 0.45–0.80 s |
| Rare | Arcade K.O. | `ArcadeKODodgeballElimination` | Bright 8-bit or 16-bit score burst with a decisive final note; original/game-generic, not recognizable from another title. | `arcade score chime`, `8 bit success short`, `retro game point sound` | 0.25–0.55 s |
| Rare | Arcade K.O. | `ArcadeKOHammerElimination` | Chunkier retro knockout sting with a low first hit and quick winning cadence. | `arcade knockout sting`, `retro game victory short`, `8 bit impact success` | 0.45–0.90 s |
| Rare | Comedy Drums | `ComedyDrumsDodgeballElimination` | Tight rimshot/snare punctuation with little or no room ambience. | `comedy rimshot short`, `cartoon snare hit`, `drum punchline sting` | 0.25–0.55 s |
| Rare | Comedy Drums | `ComedyDrumsHammerElimination` | Fast descending tom fill ending in a choked cymbal or compact crash. | `comedy drum fill short`, `descending tom cartoon`, `punchline drums cymbal` | 0.50–0.90 s |
| Legendary | Royal Fanfare | `RoyalFanfareDodgeballElimination` | Polished two- or three-note brass success stab, bright and regal. | `short royal fanfare`, `brass victory stab`, `cartoon trumpet success` | 0.45–0.85 s |
| Legendary | Royal Fanfare | `RoyalFanfareHammerElimination` | Wider brass flourish with a strong low opening and a restrained cymbal finish. | `royal fanfare flourish short`, `brass victory cymbal`, `cartoon king fanfare` | 0.75–1.35 s |
| Legendary | Stadium Roar | `StadiumRoarDodgeballElimination` | Compact crowd cheer or surprised-to-cheering swell with no intelligible speech. | `stadium crowd cheer short`, `sports crowd reaction`, `cartoon audience cheer` | 0.50–0.90 s |
| Legendary | Stadium Roar | `StadiumRoarHammerElimination` | Fuller crowd roar layered with one short sports horn; avoid long loops and team-specific chants. | `stadium roar horn short`, `arena crowd celebration`, `sports victory crowd` | 0.80–1.50 s |
| Legendary | Cosmic Chime | `CosmicChimeDodgeballElimination` | Sparkly ascending star/glass chime with a clean magical transient. | `cosmic chime short`, `magic star success`, `sparkle glass chime` | 0.45–0.90 s |
| Legendary | Cosmic Chime | `CosmicChimeHammerElimination` | Resonant synth chord or soft cosmic gong with a weighty attack and controlled tail. | `cosmic gong short`, `synth victory chord`, `space magic impact` | 0.80–1.50 s |

## Selection requirements

- Use audio owned by the experience's creator/group or explicitly shared with the experience. Confirm it loads in both the lobby and arena after moderation.
- Prefer mono or strongly center-focused files for predictable world-space direction. Avoid wide stereo effects that collapse poorly through an `AudioEmitter`.
- Choose files with less than 30 ms of leading silence, no clipped attack, no audible watermark, and no long baked reverb. The cue must feel immediate at the elimination frame.
- Keep dialogue, character names, profanity, screams, pain sounds, gun-like cracks, licensed melodies, team chants, and references to other games out of the set.
- Match perceived loudness across the full collection before adjusting config volume. Longer Legendary cues are configured slightly lower so they feel premium without masking nearby combat.
- Preserve headroom for overlapping eliminations. A two-player trade and a dense team fight must remain readable without harsh clipping.

## Verification

1. Populate both audio keys for one cosmetic and enable Studio auto-granting, or grant the item through the existing cosmetics test tooling.
2. Equip it from **Inventory → Effects → Elimination Sounds**.
3. In the Studio lobby combat test, press `Q` and eliminate a dummy once with a dodgeball and once with the hammer. Both the impact VFX and the corresponding sound variant should play.
4. In an arena match, eliminate another player while observing from the eliminator, victim, and a third client. Every client should hear the eliminator's selected cue at the same fixed impact point.
5. Move or respawn the victim immediately after elimination. The cue must not follow the character.
6. Test at approximately 5, 25, and 60 studs, from both sides of the listener, with effects volume at 25%, 50%, and 100%.
7. Test simultaneous trades and several eliminations in a short team-fight window. Replace any cue whose tail masks throws, catches, or hammer swings.
8. Unequip the cosmetic and verify dodgeball, hammer, and elimination-zone deaths still use their three existing default sounds.
