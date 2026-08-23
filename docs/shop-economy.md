# Shop and economy

The storefront backend. The shop UI itself is not built yet; this is the surface
it consumes.

## What is sold, and where it comes from

| Surface | Content | Currency | Rotates |
|---|---|---|---|
| Rotating shop | Outfits and emotes, per player | Bonks, or a per-item dev product | Yes, per player |
| Crates | Dodgeball / hammer / effect skins | Bonks or Robux | No |
| Featured crate | One crate, discounted | Bonks | Yes, globally |
| Featured bundle | One bundle of cosmetics | Robux | Yes, globally |
| Passes and products | Boosts, Bonks packs, season pass | Robux | No |

Four equip categories, seven slots: `CharacterColor`, `CostumeAssets`,
`BallAssets`, `HammerAssets`, `TrailAssets`, `ElimEffectAssets`, `EmoteAssets`.
Trails and elimination effects are one *category* in the storefront but two
*slots*, because a ball trail and an elimination effect are unrelated in play and
one slot would make equipping either silently unequip the other.

## Rotations

All three schedules bucket absolute UTC time through
`FeaturedRotation.periodIndex(rotationSeconds, now)` — one formula, so there is
one place it can be wrong.

The featured crate and featured bundle are **global**: every player on every
server sees the same drop at the same time, so the countdown is not a lie. They
are never stored, because both are pure functions of the clock.

The rotating shop is **per player**. `ShopRotation.draw(userId, periodIndex, pool,
owned, count)` is deterministic from the player and the period alone, so two
servers agree without talking.

The drawn set **is** stored, in `profile.Shop`, against the period it was drawn
for. This is the part that is easy to get wrong: the draw excludes items the
player owns, so recomputing after a purchase reshuffles the offers they chose not
to buy. `ShopRotation.spec` demonstrates that drift rather than asserting it away.

Items in a rotation category are purchasable **only while offered** —
`DirectPurchaseService` asks `ShopService.isPurchasable` before anything else.
Without that the rotation would be decorative.

## Crate availability

Crates carry a `CatalogStatus` (`Active` / `Preview` / `Hidden`) exactly as
products and passes do. Only `Active` crates can be opened or have odds built for
them; `CrateOdds.build` asserts on an empty pool by design, so `Preview` is how a
crate exists in config before its content does.

Two published economic guarantees are pinned by `CrateConfig.spec`:

- a crate open costs less than the cheapest direct buy, and
- direct buy beats the expected cost of chasing the same item in a crate,

checked at the **discounted** price actually charged, not just the baked one.

## A/B testing

Roblox hands different servers different config snapshots, so varying a
live-overridable leaf per cohort *is* the experiment. The shop exposes:

```
Shop.VariantId                     string
Shop.Rotation.OfferCount           1..8
Shop.Rotation.RotationSeconds      1h..30d
Shop.Featured.RotationSeconds      1h..30d
Shop.Featured.DiscountPercent      0..20
Shop.Bundle.RotationSeconds        1h..30d
Crates.<CrateId>.BonksPrice        500..1000
```

`VariantId` is the piece that makes the rest measurable: it is stamped on every
shop economy event, funnel step and grant, so a result can be attributed to the
configuration that produced it. Varying prices without labelling them produces
numbers nobody can act on.

The bounds are chosen so that **every** combination the allowlist permits still
satisfies both guarantees above at the charged price. `CrateConfig.spec` proves
this against the allowlist itself, so narrowing a bound is safe and widening one
fails the suite. Rarity `DirectBonks`/`DupeBonks` are deliberately not
overridable — they sit on the far side of both guarantees.

See `docs/live-configs.md` for the override mechanism.

## Adding content

**A cosmetic reskin** (colour or texture) needs no Studio asset — a `Visual`
entry in `Config.Cosmetics` is enough. A *shape*-changing skin needs a new
`MeshPart` under `ReplicatedStorage.Assets.Cosmetics.Templates` plus a matching
`VisualTemplates` entry; the MeshId must match or `CosmeticVisualFactory.create`
asserts.

**An elimination effect** is an entry in `Config.Audio.Gameplay` plus a cosmetic
that names it. Effects reference audio by name rather than carrying asset ids, so
the sounds stay owned by the audio config and its spec validates every id once.
The default names the same two entries the game always used, so a player who owns
nothing hears exactly what they heard before. The **eliminator's** effect plays,
not the victim's — it is bought to be shown off on a win.

**A bundle** is an entry in `Config.Bundles` plus a `Bundle` product in
`Config.Products` naming it. The bundle owns its contents; the product owns the
Robux id. Never both — two copies of an id turn a pricing mistake into a wrong
grant.

**A crate** goes `Preview` until its category has items, then `Active`.

**A new category** needs a `Config.Inventory.Viewport.<Category>` entry or
`InventoryPreview` asserts. That assert is the intended signal that how the thing
previews has not been decided yet.

## Known gap

Every economy service — `ShopService`, `CrateService`, `DirectPurchaseService`,
`MonetizationService`, `GamePassService`, `BattlePassService` — runs in the
**arena only**, while `ShopPage` renders in the **lobby**. A lobby client calling
`GetShopState`, `OpenCrate` or `PurchaseCosmetic` yields forever, because the
remote exists there but nothing handles it.

None of these services depend on anything arena-specific; every dependency is
shared config, shared `Game` code, or a shared server module. Moving them to
`src/server/Modules/` would make them load in both places. This is unresolved and
must be settled before the shop UI is wired up.
