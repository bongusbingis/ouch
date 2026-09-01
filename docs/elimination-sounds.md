# Elimination sound cosmetics

Elimination sounds are world-space, presentation-only cosmetics. An accepted elimination snapshots the eliminator's `Equip_ElimEffectAssets` value and the authoritative elimination position. The arena sends that accepted event over the reliable `CombatFeed`; clients resolve the snapshotted item through `Config.Cosmetics` and play its cue from a fixed world anchor. The victim's equipped sound and character position after the elimination are never consulted.

Uncredited projectile eliminations use the default cue. Eliminations without a source or projectile, such as an elimination-zone fall, use `ElimZoneFall` and do not borrow a player's cosmetic.

Each `ElimEffectAssets` item plays one sound regardless of which weapon scored the elimination -- there is no dodgeball/hammer variant pair. That is a value choice, not a type limitation: `Config.Cosmetics.ElimEffectDef` still carries separate `DodgeballSound` and `HammerSound` fields (see the comment above that type), so a future item can point them at two different `Config.Audio.Gameplay` entries without any changes to `EliminationAudio` or `GameAudio`. `eliminationEffect()` in `src/config/Cosmetics.luau` just sets both fields to the same entry name for now.

Shipped items are non-Exclusive `ElimEffectAssets`, so the existing economy automatically includes them in the Effects Crate. Effects are intentionally excluded from the current outfit/emote direct-shop rotation. Once owned, sounds are equipped from **Inventory → Effects → Elimination Sounds**.

| Cosmetic | Audio key | Asset |
|---|---|---|
| Default Bonk (Defaults.ElimEffectAssets) | `DefaultElimination` | `rbxassetid://173818824` |
| Clang | `ClangElimination` | `rbxassetid://139535360137391` |

## Adding a new elimination sound

1. Add an entry under `Config.Audio.Gameplay` (`src/config/Audio.luau`) with `Scope = "World"` and one or more `AssetIds`.
2. Add an item to `Items` in `src/config/Cosmetics.luau` via `eliminationEffect(rarity, displayName, audioKey, sortOrder)`. This points both `DodgeballSound` and `HammerSound` at the same audio entry; pass two different audio keys directly in an `ElimEffect` table instead of using the helper if the item needs distinct weapon cues.
3. `Cosmetics.spec.luau` and `CosmeticsLogic.spec.luau` assert every `ElimEffectAssets` item resolves to a real, well-formed `Config.Audio.Gameplay` entry.

## Verification

1. Grant the item through the existing cosmetics test tooling and equip it from **Inventory → Effects → Elimination Sounds**.
2. In the Studio lobby combat test, press `Q` and eliminate a dummy once with a dodgeball and once with the hammer. Both should play the same cue.
3. In an arena match, eliminate another player while observing from the eliminator, victim, and a third client. Every client should hear the eliminator's selected cue at the same fixed impact point.
4. Move or respawn the victim immediately after elimination. The cue must not follow the character.
5. Unequip the cosmetic and verify dodgeball, hammer, and elimination-zone deaths still use the default and `ElimZoneFall` sounds.
