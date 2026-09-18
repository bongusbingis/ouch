# Tiered Robux offers for the "For You" shop rotation

## The brief in one paragraph

The per-player "For You" rotation currently draws three cosmetics at random and sells all of them for Bonks. Replace that with a fixed three-slot composition: one Common sold for Robux, one Rare-or-Legendary sold for Robux, and one item sold for Bonks exactly as today. The two Robux slots are served by **three** developer products priced per rarity tier — not per item — so no new product is ever needed when a cosmetic is added. A receipt resolves to an item by matching the product's tier against the player's current offer slots, grants the cosmetic, and marks that slot purchased so it cannot be bought twice in the same period.

Preserve every existing catalog ID, rarity, price, ownership rule, and the Bonks purchase path. This changes how the rotation is composed and adds a Robux path; it does not reopen pricing or the candy visual system.

> UI work in this plan touches Shop surfaces. Read [STYLE.md](../STYLE.md) and [SHOP_REDESIGN_PLAN.md](../SHOP_REDESIGN_PLAN.md) before changing any card or modal.

---

## 1. Developer products — fill these in before implementing

Create three developer products on the Creator Hub (Dashboard → experience → Monetization → Developer Products → Create). Name, description and price only — **skip the icon**, because cosmetic cards render the cosmetic's own `Thumbnail`/`previewItems` and never read `product.Icon`.

Price each tier at or modestly below what the equivalent Bonks already cost through a Bonks pack. Above that line the product cannot convert, because the player can already reach the item through packs.

| Product key | Tier | Equivalent Bonks price | Robux price | **Product ID** |
| --- | --- | ---: | ---: | ---: |
| `OfferUnlockCommon` | Common | 1,000 | 99 | 3713076299 |
| `OfferUnlockRare` | Rare | 2,500 | 199 | 3713076349 |
| `OfferUnlockLegendary` | Legendary | 10,000 | 599 | 3713076414 |

Equivalent Bonks prices come from `Cosmetics.Rarities[*].DirectBonks` (`src/config/Cosmetics/Cosmetics.luau:86`) and are uniform within a tier — this is what makes tier-priced products coherent, and it is already the shipped pricing model.
---

## 2. What exists today (verified)

| Concern | Location | Current behavior |
| --- | --- | --- |
| Rotation tunables | `src/config/Economy/Shop.luau:50` | `OfferCount = 3`, `RotationSeconds = 24h`, six categories |
| Eligibility | `ShopRotation.isEligible` | excludes `ShopEligible == false`, `AlwaysAvailable`, `InventoryVisible == false`, and `Exclusive` |
| Deterministic draw | `ShopRotation.draw` | seeded from `(userId, bucket)`, excludes owned |
| Persisted state | `Data.Template.Shop` | `{ Bucket = -1, Offers = { itemId } }` — persisted so buying one offer does not reshuffle the others |
| Draw + persist | `ShopService.ensure:60` | redraws only when the bucket changes |
| Offer projection | `ShopService.stateFor:113` | emits `{ itemId, rarity, displayName, bonksPrice, owned }` |
| Bonks purchase | `DirectPurchaseService.purchase:30` | checks offered → evaluate → grant → debit |
| Card build | `ShopViewModel.cosmeticCard` | resolves a product via `productFor(products, "ItemId", …)`; sets `bonksPrice` and `robuxPrice` independently |
| Both buttons | `ShopDetailsModal:300`, `:722` | `hasBonks` and `hasRobux` computed independently and both counted into `actionCount` |
| Robux routing | `EconomyMenuController:513` | `purchaseSelectedRobux` checks only `card.productId ~= nil`; kind-agnostic |
| Prompt | `ShopClient.promptProduct:543` | generic; gates only `Crate` (policy) and `SeasonPass` (season window) |
| Metadata fetch | `ShopClient.loadMarketplaceData:262` | iterates `Products.Catalog`; new active products are picked up automatically |
| Receipt dispatch | `MonetizationService:122` | per-`Type` handler; unknown or failed receipts return `NotProcessedYet` |

**Eligible rotation pool, by rarity** (72 items total):

| Rarity | Balls | Hammers | Impacts | Elim | Outfits | **Total** |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Common | 9 | 10 | 3 | 1 | 1 | **24** |
| Rare | 9 | 10 | 4 | 0 | 2 | **25** |
| Legendary | 9 | 10 | 3 | 0 | 1 | **23** |

`EmoteAssets` is listed in `Shop.Rotation.Categories` but contributes nothing: every emote is `ShopEligible = false`, and `src/shared/Tests/Emotes.spec.luau:50` asserts it stays that way. **Remove `"EmoteAssets"` from `Shop.Rotation.Categories` as part of this change** — it is dead config and will otherwise skew the role pools when someone later assumes it contributes.

---

## 3. Design

### 3.1 Three fixed roles

`Shop.Rotation` stops meaning "draw N random items" and starts meaning "fill three named roles".

| Role | Rarity drawn from | Sold for | Notes |
| --- | --- | --- | --- |
| `RobuxCommon` | Common | Robux only | served by `OfferUnlockCommon` |
| `RobuxPremium` | Rare **or** Legendary | Robux only | served by `OfferUnlockRare` or `OfferUnlockLegendary`, whichever matches the drawn item's rarity |
| `Bonks` | any eligible rarity | Bonks only | unchanged from today |

Rules:

- The three slots must hold three **distinct** items.
- A Robux-role item is **not** buyable with Bonks, and the Bonks-role item is **not** buyable with Robux. One price per card. This keeps the tier→slot mapping one-to-one, which is the whole reason the receipt can be resolved without storing intent.
- The draw stays deterministic from `(userId, bucket)` and stays persisted, for the reason already documented in `Data.Template.Shop`: buying one offer must not reshuffle the others.
- `RobuxPremium` picks Rare vs Legendary as part of the seeded draw. Choose the mix deliberately and record it in `Shop.luau` — a reasonable default is a 70/30 Rare/Legendary split, so the expensive tier stays a genuine event rather than a daily fixture.

### 3.2 Why the tier identifies the slot

Because exactly one Robux Common slot and exactly one Robux premium slot exist per period, a receipt carrying `OfferUnlockRare` can only mean the `RobuxPremium` slot, and only when that slot holds a Rare. There is no second candidate to disambiguate against, so no pre-purchase intent has to be written, saved durably, or recovered.

This is the property that makes the design work. **If a future change ever puts two same-tier Robux offers on screen at once, this breaks silently** — a receipt would have two valid targets and would pick one arbitrarily. Guard it with the composition test in §7.

### 3.3 Resolution at receipt time

```
receipt(ProductId) → Products.ById[ProductId] → { Type = "OfferUnlock", Rarity = R }

  R == "Common"                  → slot RobuxCommon
  R == "Rare" or "Legendary"     → slot RobuxPremium, only if that slot's item rarity == R
```

Then, in order:

1. Slot missing, or its rarity does not match `R` → **substitute** (§5.1).
2. Slot already marked purchased this period → **substitute**.
3. Item already owned → **substitute**.
4. Otherwise grant the cosmetic, mark the slot purchased, and return a payload naming the **resolved item ID**.

Step 4's payload matters: the product is tiered, but the receipt tombstone must record what was actually granted, so the receipt stays the authoritative record of the transaction. Do not let the payload say only "a Rare".

---

## 4. Changes by file

### 4.1 `src/config/Economy/Products.luau`

Add `"OfferUnlock"` to `ProductType`, a `Rarity` field to `ProductDef`, and three entries:

```lua
	OfferUnlockCommon = {
		Id = 0, -- REPLACE with the Common-tier developer product id
		Icon = "",
		CatalogStatus = "Preview", -- flip to "Active" once Id is real
		DisplayName = "Common Unlock",
		Description = "Unlock today's Common offer instantly.",
		DisplayOrder = 600,
		Type = "OfferUnlock",
		Rarity = "Common",
	},
	OfferUnlockRare = { …, DisplayOrder = 610, Type = "OfferUnlock", Rarity = "Rare" },
	OfferUnlockLegendary = { …, DisplayOrder = 620, Type = "OfferUnlock", Rarity = "Legendary" },
```

Extend the validation loop so an `OfferUnlock` with an `Id` asserts its `Rarity` exists in `Cosmetics.Rarities` and has `DirectBonks > 0`. This needs `local Cosmetics = require(script.Parent.Parent.Cosmetics.Cosmetics)` — the identical require `Bundles.luau` already makes from the same folder, so there is no cycle.

Also assert that **no two `OfferUnlock` products share a `Rarity`**. That is the config-level expression of §3.2.

`DisplayOrder` does not drive placement for these — they surface only through `cosmeticCard`, never as their own section. The 600+ band just keeps them clear of Bonks (310–340) and the season pass (500).

### 4.2 `src/config/Economy/Shop.luau`

- Remove `"EmoteAssets"` from `Rotation.Categories`.
- Replace `OfferCount = 3` with an explicit role table, e.g. `Roles = { { Id = "RobuxCommon", Rarities = {"Common"} }, { Id = "RobuxPremium", Rarities = {"Rare","Legendary"}, Weights = {70,30} }, { Id = "Bonks" } }`.
- Keep the existing assertions and add: at least one role, exactly one role per Robux tier, role IDs unique.

### 4.3 `src/shared/Game/Economy/ShopRotation.luau`

Add a role-aware draw beside the existing one. Keep `isEligible`, `includes` and `pool` untouched — other call sites depend on them.

- `ShopRotation.poolByRarity(items, categories)` → `{ [rarity]: { itemId } }`, sorted, for deterministic role pools.
- `ShopRotation.drawRoles(userId, bucket, pools, owned, roles, items)` → `{ { ItemId, Role, Rarity } }`, seeded identically to `draw`, excluding owned, and excluding items already taken by an earlier role.

A role whose pool is exhausted is **omitted**, not backfilled from another rarity (§5.2).

### 4.4 `src/config/Progression/Data.luau`

```lua
		Shop = {
			Bucket = -1,
			Version = 1,                -- new; forces one redraw on migration
			Offers = {},                -- now { { ItemId, Role, Rarity } }
			Purchased = {},             -- { [role] = true }, cleared with Offers on rotation
		},
```

**Migration:** `ShopService.ensure` must redraw when `Shop.Version` is absent or below current, in addition to the existing bucket check. A one-time mid-period reshuffle is acceptable — the persistence rule exists to stop a *purchase* reshuffling the rest, not to freeze a schema change.

### 4.5 `src/server/Modules/ShopService.luau`

- `ensure:60` — redraw on bucket change **or** version mismatch; use `drawRoles`; reset `Purchased = {}` on every redraw.
- `offersFrom:84` — iterate records, keep the eligibility re-check, preserve role.
- `offersFor:98` — keep returning `{ string }` for existing callers; add `ShopService.offerRecords(player)` for role-aware callers.
- `isPurchasable:100` — becomes role-aware. An item in a Robux role must return **false**; otherwise `DirectPurchaseService` will happily sell it for Bonks.
- `stateFor:113` — emit `role`, and `bonksPrice` **only** for the `Bonks` role. Add `purchased` per offer.
- New `ShopService.resolveOfferForTier(player, rarity)` → `(itemId?, role?, reason?)`, implementing §3.3 steps 1–3. This is the single resolution point; the receipt handler must not reimplement it.
- New `ShopService.markPurchased(player, role)`.

### 4.6 `src/server/Modules/MonetizationService.luau`

Add an `OfferUnlock` handler beside `Cosmetic`:

```lua
	OfferUnlock = function(player, def, receiptInfo)
		local itemId, role = activeShopService.resolveOfferForTier(player, def.Rarity)
		if itemId == nil then
			-- substitute: grant DirectBonks for def.Rarity, payload kind = "Bonks", substitutedFor = def.Rarity
		end
		-- grant cosmetic, markPurchased(player, role)
		-- payload: { grantId = tostring(receiptInfo.PurchaseId), kind = "Cosmetic",
		--            productId = receiptInfo.ProductId, itemId = itemId }
	end,
```

Inject `ShopService` through `StartOptions` the way the other collaborators already are, so the spec can substitute it.

The handler must return `false` **only** when it genuinely could not settle, because that leaves the receipt at `NotProcessedYet` and Roblox retries forever. Every resolvable path — including all three substitution cases — must return `true` with a payload.

### 4.7 `src/server/Modules/DirectPurchaseService.luau`

No signature change. It already calls `ShopService.isPurchasable`, so making that role-aware (§4.5) blocks Bonks purchases of Robux-role items automatically. **Add a spec proving it**, rather than relying on the transitive fix.

### 4.8 `src/shared/Game/Economy/ShopViewModel.luau`

In `cosmeticCard`:

- Resolve the product by **tier and role**, not by `ItemId`: when `offer.role ~= "Bonks"`, find the `OfferUnlock` product whose `Rarity` matches the offer's rarity.
- Set `bonksPrice` only for the `Bonks` role; `robuxPrice`/`productId` only for Robux roles.
- Map `offer.purchased` into the card so an already-bought slot renders as bought and not as a second prompt.

Leave the existing `productFor(products, "ItemId", …)` lookup in place — it stays correct and unused, and keeps the door open for curated per-item products later.

### 4.9 `src/shared/Game/Economy/ShopClient.luau`

`promptProduct:543` gates `Crate` and `SeasonPass`. Add an `OfferUnlock` gate that refuses when the tier has no resolvable offer (exhausted pool, or slot already purchased), so the player is never prompted for something that can only substitute.

No change needed to `loadMarketplaceData` — it already iterates `Products.Catalog` generically.

### 4.10 UI

`ShopDetailsModal` and the card components already render Bonks and Robux actions independently, so a card with one price shows one button with no change. What does need doing:

- A **purchased** state on the For You card for a Robux slot already bought this period.
- The For You section must read correctly with **two** cards when a role is omitted (§5.2). `ShopViewModel` already guards `#rotating.cards > 0`; confirm `ShopLayout` packs a two-card section without collapsing every section to full width — the known `resolveSpans` limitation is called out in `SHOP_REDESIGN_PLAN.md` §1.

---

## 5. Edge cases — decide these explicitly

### 5.1 Substitution

A receipt that cannot be resolved to a grantable item must still settle. Grant `Cosmetics.Rarities[R].DirectBonks` Bonks instead, and record `substitutedFor` in the payload. This mirrors the existing precedent in `CrateService` for a retired crate receipt.

Triggers: slot missing or rarity mismatch; slot already purchased; item already owned by the time the receipt lands.

The player is never worse off than the Bonks value of the tier they paid for. Confirm this reads acceptably in the purchase-notification copy.

### 5.2 Exhausted role pool

A player owning all 24 Commons has no `RobuxCommon` slot. **Omit the role**; render two cards; refuse the prompt for that tier (§4.9). Do not backfill from another rarity — that would sell a Rare at the Common price and break the tier→slot mapping.

### 5.3 Period rollover mid-purchase

A prompt opened just before rotation can produce a receipt that lands after it. Resolution runs against the **current** bucket, so the player receives the current period's item of that tier, not the one they were looking at.

**Recommended default:** accept this. The window is seconds per day, the player gets an item of the tier and price they paid for, and closing it properly requires exactly the durable pre-purchase intent this design was chosen to avoid.

_Optional refinement, only if the owner wants it:_ keep `PreviousBucket` and `PreviousOffers` for one period and prefer an unpurchased matching slot there when the receipt arrives within N seconds of rollover. Adds profile weight and a second resolution path; not recommended for v1.

### 5.4 Paid-random policy

`OfferUnlock` grants a **named, chosen** item. It is not a random generator, so it must **not** be gated on `PaidRandomPolicyService`. This is deliberate and valuable: it gives restricted accounts a Robux path, which crates cannot. Do not copy the `Crate` gate in `promptProduct`.

### 5.5 Double purchase

Prevented at three layers: the card renders as purchased, `promptProduct` refuses, and the receipt handler substitutes. Receipt **replay** is separately handled by `PurchaseId` dedup in `MonetizationService` and needs no work here — do not conflate the two.

### 5.6 Analytics

Log the tier product **and** the resolved item ID on every grant and substitution. Note the existing constraint from the economy audit: `Config.Infra.Analytics` retains only three fields per row and drops `substitutedFor` from the Economy schema today. Decide whether this change needs that schema widened before shipping, or accept that substitutions are not separately measurable at launch.

---

## 6. Sequence

1. Config: `Products.luau` entries and validation, `Shop.luau` roles, drop `EmoteAssets`.
2. `ShopRotation.poolByRarity` / `drawRoles` + specs. Pure, no dependencies — do this first.
3. `Data.luau` schema and `ShopService` draw/migration/resolution/marking + specs.
4. `MonetizationService.OfferUnlock` handler + specs.
5. `ShopViewModel` card wiring + `ShopClient` prompt gate.
6. UI purchased state and two-card layout check.
7. Paste real product IDs, flip to `Active`, verify in Studio.

Steps 1–5 are testable headless. Only 6–7 need Studio.

---

## 7. Tests

New or extended specs:

- **Composition** — every period yields exactly one Common Robux role, at most one premium Robux role, one Bonks role, and three distinct items. Assert across many `(userId, bucket)` pairs.
- **One product per tier** — no two `OfferUnlock` products share a `Rarity` (§3.2's invariant).
- **Determinism** — same `(userId, bucket)` yields the same roles; a purchase does not reshuffle the others.
- **Migration** — a profile with the old flat `Offers` array and no `Version` redraws once and then stabilises.
- **Resolution** — Common product resolves the Common slot; Rare product resolves the premium slot only when it holds a Rare; Legendary likewise.
- **Substitution** — mismatched tier, already-purchased slot, and already-owned item each settle as Bonks and return `true`.
- **Double purchase** — second receipt for a purchased role substitutes; a replayed `PurchaseId` grants exactly once.
- **Bonks isolation** — `DirectPurchaseService.purchase` refuses a Robux-role item.
- **Exhausted pool** — all Commons owned yields two roles and a refused Common prompt.
- **No policy gate** — a restricted player can still prompt and receive an `OfferUnlock`.

Use the real `ShopService` with mocked profile and marketplace boundaries, per the standing guidance in the economy audit that a stub receipt dispatcher is not sufficient evidence.

---

## 8. Acceptance

- Three products exist with real IDs, `CatalogStatus = "Active"`, and prices at or below the tier's Bonks-equivalent.
- The For You section always shows one Common Robux card, one Rare-or-Legendary Robux card, and one Bonks card — or fewer only when a role's pool is genuinely exhausted.
- No card offers both currencies; no Robux-role item is purchasable with Bonks.
- A completed purchase grants the exact item shown, marks the slot, and the receipt payload names the resolved item.
- A second purchase of the same slot in one period is impossible through the UI and settles as Bonks if one ever reaches the receipt handler.
- No receipt path can return `false` for a resolvable purchase.
- Restricted accounts can complete an `OfferUnlock` purchase.
- Existing catalog IDs, rarities, Bonks prices, ownership, crates, bundles, passes, and the season pass are unchanged.

---

## 9. Out of scope

Crate products, Bonks packs, game passes, the season pass, the featured/bundle rotations, and rarity pricing. Per-item `Type = "Cosmetic"` products remain defined and unused; this plan does not remove them.

## 10. Open decisions for the owner

1. Robux price per tier (§1).
2. Rare/Legendary weighting for the `RobuxPremium` role (§3.1) — default 70/30.
3. Whether to widen the analytics schema for `substitutedFor` before launch (§5.6).
4. Whether to take the rollover refinement in §5.3 — default no.
