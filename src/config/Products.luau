--!strict

-- Developer product map for MarketplaceService.ProcessReceipt. Keys are
-- product ids from the Creator Dashboard; fill in after creating products.
-- GDD Robux tiers for reference: hammer assets 150–350, ball VFX 99–250,
-- costumes 250–600, emotes 75–150, battle pass 799.

export type ProductDef = {
	Type: string, -- handler key registered with MonetizationService
	CrateId: string?,
}

return {
	-- [0000000000] = { Type = "Crate", CrateId = "BallCrate" },
} :: { [number]: ProductDef }
