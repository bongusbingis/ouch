# Importing external particle effects as impact cosmetics

This covers turning a multi-emitter particle effect from an external VFX pack into an
equippable **impact effect cosmetic**. There are three paths:

- **Hybrid (`ParticleKit` + signature geometry)** — the production default for
  effects whose identity needs a readable shape, word, ribbon, or bubble. Shared
  particle presets land the hit; the effect module owns one unmistakable signature.
- **Code-built (`ParticleKit`)** — transcribe the emitters' dumped properties into a
  data spec; no Studio asset, the effect ships in the repo. This is how the imported
  pack lives today (`src/shared/Game/Cosmetics/Effects/Imported/`), and how the
  worked example `SugarRush` renders.
- **Studio template** — author/clone the emitters under
  `Assets.Cosmetics.Effects.Impact.<Name>`. Use this when you would rather tune the
  effect in Studio than in code.

Both resolve through the same `EffectId` in `Config.Cosmetics.Items` and fire the same
one-shot burst. `SugarRush` was imported from the pack's `Common` egg-reveal burst,
recolored to the candy palette.

## How the pipeline works

An impact effect cosmetic is one row in `Config.Cosmetics.Items` whose `EffectId`
resolves, at play time, to **either** a registered script effect **or** a
Studio-authored template under `ReplicatedStorage.Assets.Cosmetics.Effects.Impact`.
When it is a Studio template, `CosmeticEffectFactory.playInstance`:

1. clones the template,
2. **consolidates every descendant `ParticleEmitter` onto a single anchor at the
   impact point** — so a multi-part authored effect all bursts from where the hit
   landed (per-emitter positional offsets in the template are *not* preserved; author
   the effect centered),
3. disables each emitter (so it does not free-run) and fires a **one-shot burst**,
   using that emitter's own `EmitCount` number attribute, then the template's, then
   the category default (`Config.CosmeticEffects.Impact.DefaultEmitCount`),
4. cleans the anchor up after the longest emitter lifetime.

Only `ParticleEmitter`s play. `Beam`/`Trail`/`Light`/`Smoke`/`Fire` children are
dropped — if an effect depends on those, it needs a script or hybrid port instead.

So integrating a composite particle effect is: **place + name the template, recolor
its emitters, set one `EmitCount` attribute per emitter, add one config row.** No
factory or driver changes per effect.

## Code-built path (`ParticleKit`)

`src/shared/Game/Cosmetics/Effects/ParticleKit.luau` builds emitters from a data spec
and one-shot bursts them exactly like `playInstance`, but with no Studio asset — the
emitter properties (texture id, `Color`/`Transparency`/`Size` sequences, ranges,
`EmitCount`, flipbook) transcribe straight from the property dump. Each effect is one
`ParticleKit.effect({ emitters = { ... } })` registered in `ScriptEffects`; the imported
pack lives under `Effects/Imported/` (`DamageEffects`: Burn/Magma/Poison/Shock;
`EggEffects`: Common/Epic/Ethereal/SugarRush plus the three exclusive impacts).
`ParticlePresets.luau` is the production vocabulary for flashes, rings, rays,
streaks, stars, motes, smoke, debris, crescents, and flares. Effect modules compose
those constructors instead of copying emitter curves. Add a new id to the appropriate
production or imported list in `ScriptEffects`. Textures still need re-uploading to
this experience (swap the ids in the spec). `context.scale` multiplies the `Size`
curves, so the gallery's scale control works.

## Production impact identities

Every purchasable impact has a particle-led hit beat, but the signature and motion
grammar stay exclusive to that item. Do not recolor one composition into another
production cosmetic.

The shared motion language is a compressed launch, a readable 10-20% overshoot,
a brief squash and smaller rebound, then a settled hold or clean collapse. Hero and
secondary layers should offset that beat rather than fire in lockstep: rigid linear
growth and one-way TweenService scaling do not meet the production bar. Preserve each
effect's identity through the axis and cadence of the spring - foam squashes, jelly
wobbles, paper snaps open, heavy candy recoils, and premium light pulses stay crisp.

| Effect | Particle language | Signature |
|---|---|---|
| Star Pop | gold ring, rays, cyan motes | chunky flying star glyphs |
| Foam Poof | cream ring, soft smoke, cyan motes | opaque expanding foam balls |
| Confetti Impact | four-color speed streaks | dense matte paper fountain |
| Jelly Splash | pink smoke, cyan crescents | gummy splat and stretched droplets |
| Candy Crash | fast streaks and tumbling debris | heavy candy chunks; no star celebration |
| Party Popper | pink rays, gold stars, flare cross | long curved streamers with sparse paper |
| Sugar Rush | full candy reveal burst | particle-only rainbow celebration |
| Comic Bonk | yellow streaks and pink rays | angular burst and `BONK!` typography |
| Bubble Burst | blue motes and white stars | oversized glass bubbles with staggered pops |
| Royal Party | restrained gold rays and stars | crown-like jewel arc and delayed glint |
| Prismatic | dual spectrum rings and teal streaks | fast flagship rainbow starburst |
| Galaxy | purple nebula smoke and slow stars | lingering cosmic cloud |
| Starlight | white/gold flare cross and rays | stationary vertical gold shaft |

## Studio-template checklist (any composite effect)

1. In Studio, take the effect's root Model/Folder, **rename it to the `EffectId`**,
   and place it under `ReplicatedStorage.Assets.Cosmetics.Effects.Impact`. Its
   internal structure can stay as imported — the factory walks all descendants.
2. Delete any non-`ParticleEmitter` VFX children (Beams/Trails/Lights); they will not
   play through this path.
3. **Re-upload every `Texture` asset** the emitters reference to *this* experience and
   swap the ids — texture ids owned by another game may not load here. (Roblox's own
   stock textures, e.g. `rbxassetid://6673021984`, usually load as-is; verify each.)
4. Recolor each emitter's `Color` to the candy palette (`src/shared/Game/Cosmetics/Effects/Palette.luau`).
5. Add a `Number` attribute named `EmitCount` to each emitter = its one-shot burst
   size (continuous emitters authored with a `Rate` need this; a burst of `Rate`
   is usually the wrong amount).
6. Add the `Config.Cosmetics.Items` row with `Category = "ImpactEffectAssets"`,
   `EffectId = "<name>"`, a `Rarity`, `DisplayName`, and `SortOrder`.
7. Preview: `Config.Debug.CosmeticVFXGallery = true` in Studio, set the gallery's
	`EffectId` to your name, toggle `Play`. Tune size, counts, overshoot, settle, and
	exit timing, then re-check.

## Worked example — `SugarRush`

**Source:** the pack's `Workspace.VFX.Egg Effects.Common` effect (emitters `Enable.Dust`,
`Enable.Light`, `Enable.Rays`, `Enable.Shockwave`, `Enable.SmallStripes`, `Enable.Star`,
`Common.HorizontalFlare`, `Common.Light`, `Common.VerticalFlare`). It is a rich
sparkle-reveal burst: central bloom + expanding ring + radiating rays + flying
4-point stars + dust + stripes + a flare cross.

**Repo side (done):** `SugarRush` is a `Rare` `ImpactEffectAssets` cosmetic reproduced
in code — `Effects/Imported/EggEffects.luau` builds it from the `Common` geometry with
the candy per-emitter palette below, so it renders with **no Studio asset**. Re-upload
any of the pack's textures that fail to load in this experience and swap the ids in the
spec: `6673021984`, `11299782591`, `13718068134`, `13789357218`, `5001001365`,
`15347545896`, `15424657493`.

The candy recolor applied in code (also the reference if you later author a Studio
version instead):

| Emitter | Texture | `Color` (candy) | `EmitCount` | Reads as |
|---|---|---|---|---|
| `Enable.Light` | 6673021984 | White `248,252,253` | 1 | central bloom / the flash |
| `Enable.Shockwave` | 15347545896 | Cyan `97,255,237` | 1 | expanding ring |
| `Enable.Rays` | 13789357218 | Gold `255,211,51` | 12 | radiating rays |
| `Enable.Star` | 15424657493 | Gold `255,211,51` | 15 | flying 4-point sparkles |
| `Enable.Dust` | 13718068134 | Pink `242,24,76` | 20 | drifting motes |
| `Enable.SmallStripes` | 5001001365 | HotPink `255,102,204` | 15 | outward streaks |
| `Common.Light` | 6673021984 | Lavender `209,140,252` | 1 | soft after-pulse |
| `Common.HorizontalFlare` | 11299782591 | White `248,252,253` | 1 | flare cross (horizontal) |
| `Common.VerticalFlare` | 11299782591 | White `248,252,253` | 1 | flare cross (vertical) |

Total one-shot burst ≈ 67 particles.

**Scale note:** the pack's sizes are authored large (the bloom reaches ~10 studs, the
ring ~5). Against a ~5-stud character these read fine as a flash, but the ring is small
for a hit — raise the `Shockwave` emitter's `Size` in the spec for punch. `ParticleKit`
multiplies `Size` by `context.scale`, so the gallery's scale slider also tunes it live.

**Testing:** with `Config.Debug.CosmeticVFXGallery = true`, open the Studio place, set
`Workspace.CosmeticVFXGallery.EffectId` to `SugarRush` (or `Burn`/`Magma`/`Poison`/
`Shock`/`Common`/`Epic`/`Ethereal`), and toggle `Play` — the gallery previews these
code-built effects and Studio templates alike. `SideBySide` covers all 13 production
impacts and `StressTest` cycles the same roster. To test the full equip path, equip an
impact and use `LobbyCombatTest`, which broadcasts the same `Elim`/`HammerHit` events
the arena does.
