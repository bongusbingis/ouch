# Monetization setup

The Shop reads enabled offers from `src/config/GamePasses.luau` and
`src/config/Products.luau`. Definitions without a valid ID or with
`Enabled = false` never appear and cannot be granted.

Displayed names, icons, sale state, and Robux prices come from
`MarketplaceService:GetProductInfoAsync()` on each player's client. The
configured name and description are storefront fallbacks and benefit copy;
`SuggestedRobux*` values are planning notes and are never shown as a price.

## Game passes

Create the pass in Creator Hub, add its numeric ID, list only existing keys
from `Config.Cosmetics.Items`, and enable it:

```luau
SparkCollection = {
	Id = 123456789,
	Enabled = true,
	DisplayName = "Spark Collection",
	Description = "Permanent spark ball and trail cosmetics.",
	DisplayOrder = 10,
	SuggestedRobuxMin = 149,
	SuggestedRobuxMax = 199,
	Categories = { "BallAssets", "TrailAssets" },
	EntitlementItemIds = { "BallSpark", "TrailSpark" },
},
```

`GamePassService` verifies ownership with Roblox on join and again after a
completed prompt. It grants every configured item through `CosmeticsService`;
reconciliation is safe to repeat because `Cosmetics.Owned` is idempotent. An
enabled pass fails startup if an item is unknown or outside its declared
categories.

## Developer products

The two ready receipt-backed product types are `Cash` and `Crate`:

```luau
Cash500 = {
	Id = 234567891,
	Enabled = true,
	DisplayName = "500 Cash",
	Description = "Add 500 Cash to your balance.",
	DisplayOrder = 30,
	Type = "Cash",
	SuggestedRobux = nil,
	CashAmount = 500,
},

BallCrateOpen = {
	Id = 345678912,
	Enabled = true,
	DisplayName = "Ball Crate Open",
	Description = "Open one Ball Crate.",
	DisplayOrder = 40,
	Type = "Crate",
	SuggestedRobux = nil,
	CrateId = "BallCrate",
},
```

The client only opens Roblox's purchase prompt. `MonetizationService` is the
single `ProcessReceipt` owner and records purchase IDs before acknowledging
retries. Cash routes through `PlayerData`; crate products use the same
roll-and-grant path as earned-Cash crates. An enabled product fails startup if
its type has no receipt handler or its crate is unknown.

`SeasonPass` remains a disabled catalog stub until a season progression owner
and receipt handler exist. Do not enable it before that system is implemented.

## Paid random items

Crate cards disclose configured rarity odds before purchase. When Cash is sold
for Robux, both Cash offers and random crate interactions use Roblox
`PolicyService`. Players with `ArePaidRandomItemsRestricted = true` see the
paid-random actions disabled, and the server independently blocks Cash crate
opens. Developer-product receipts that Roblox has already charged are always
fulfilled through `ProcessReceipt`.

Test purchases in a published test experience with low-priced products;
Roblox test-mode purchases can spend real Robux.
