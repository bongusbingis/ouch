# Monetization setup

Everything below is config plus a Creator Hub id. No code changes are needed to
put an offer on sale.

## Catalog status

Both `src/config/GamePasses.luau` and `src/config/Products.luau` use
`CatalogStatus`, not the older `Enabled` boolean:

| Status | In the storefront? | Purchasable? |
|---|---|---|
| `Preview` | Yes, with a disabled action | No |
| `Active` | Yes | Yes — requires a real `Id` |
| `Hidden` | No | No |

`Preview` is how an offer is merchandised before it exists on the platform.
Only `Active` definitions enter `ById`, which is the sole map receipt
processing and ownership reconciliation consult.

Names, icons, sale state, and the Robux price shown to players all come from
`MarketplaceService:GetProductInfoAsync()` on the client. `SuggestedRobux` is a
planning note and is never displayed as a price.

## Going live with an offer

1. Create the pass or product in Creator Hub.
2. Paste its numeric id into the definition.
3. Change `CatalogStatus` to `"Active"`.
4. Run the test suite — the config validators and specs will reject an
   inconsistent catalog at startup rather than in production.

## Game passes

A pass grants cosmetics (`EntitlementItemIds`), boosters (`Boosts`), or both.

```luau
EffectCollection = {
    Id = 123456789,
    CatalogStatus = "Active",
    DisplayName = "Effect Collection",
    Description = "Exclusive effects, permanently unlocked.",
    DisplayOrder = 410,
    SuggestedRobux = 149,
    Categories = { "TrailAssets", "ElimEffectAssets" },
    EntitlementItemIds = { "TrailAurora", --[[ ... ]] },
},
```

`GamePassService` verifies ownership with Roblox on join and again after a
completed prompt, then grants every configured item through `CosmeticsService`.
Repeating this is safe because ownership records are idempotent. An Active pass
fails startup if an item is unknown or outside its declared categories.

**Boosters** declare multipliers instead of items:

```luau
Boosts = { XpMultiplier = 2.5, BonksMultiplier = 1.5 },
```

Stacking is **max-wins per multiplier type**, never multiplicative. A bundle
must therefore declare a strictly higher multiplier than the single pass it
replaces, or buying it is a dead purchase for an existing owner.

**Pass ownership is never written to the profile.** The platform is the source
of truth and `EntitlementService` caches it per session, so a refund cannot
strand a permanent booster flag on a player. The corollary matters:

> Game passes → ownership lives on the platform, cached per session.
> Developer products → ownership lives in the profile, because the platform
> does not remember it.

## Developer products

Three receipt-backed types: `Bonks`, `Crate`, and `SeasonPass`.

```luau
Bonks1100 = {
    Id = 234567891,
    CatalogStatus = "Active",
    DisplayName = "Bonks Stack",
    DisplayOrder = 320,
    Type = "Bonks",
    SuggestedRobux = 99,
    BonksAmount = 1100,
},
```

The client only opens Roblox's purchase prompt. `MonetizationService` is the
single `ProcessReceipt` owner and records purchase ids permanently, so a retry
after a grant acknowledges without re-granting. An Active product fails startup
if its type has no handler or its crate is unknown.

## Seasons

Ship **one product per season** rather than editing `SeasonId` in place, so
receipt history stays unambiguous about what was bought.

```luau
SeasonPassS1 = {
    Id = 345678912,
    CatalogStatus = "Active",
    Type = "SeasonPass",
    SuggestedRobux = 499,
    SeasonId = "S1",
},
```

To open a new season, add a definition to `src/config/Seasons.luau` with its
window, tier count, XP thresholds, and both reward tracks, then add a matching
product.

**Never delete a season definition — mark it `Archived = true` instead.** A
player offline across an entire season still carries that season's id in their
profile. If the definition is gone, the service cannot look up what they were
owed and their unclaimed rewards vanish silently. This is not statically
enforceable; it is a rule.

`BattlePassService.start` must run before `MonetizationService.start` so its
`SeasonPass` receipt handler is registered first — `MonetizationService` asserts
that every Active product has a handler.

## Featured rotation

`src/config/Shop.luau` holds the rotation list, period, and discount. The slot
is chosen from absolute UTC time alone, so every client and server agrees
without replicating anything. The discount is real: `CrateService.priceFor` and
the storefront call the same shared function, so the advertised price is the
charged price.

## Paid random items

- Crate cards disclose every outcome and its numerical probability before
  purchase, summing to exactly 100%, plus the pity guarantees.
- `PolicyService` gates **both** crate payment paths. A restricted player whose
  receipt Roblox already charged is made whole with the crate's Bonks value
  rather than a random roll — returning a failure would strand the purchase in
  retries forever.
- Pity thresholds are a published guarantee. Changing them changes a promise
  players have been shown.

Test purchases in a published test experience with low-priced products; Roblox
test-mode purchases can spend real Robux.
