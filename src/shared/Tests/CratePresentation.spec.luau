--!strict

local T = require(script.Parent.TestKit)

local Client = script.Parent.Parent.Parent.Parent.StarterPlayer.StarterPlayerScripts.Client
local CratePresentation = require(Client.Modules.UI.CratePresentation)

local RARITIES = {
	Common = { Weight = 70 },
	Rare = { Weight = 24 },
	Legendary = { Weight = 6 },
	Exclusive = { Weight = 0 },
}

T.describe("CratePresentation", function()
	T.it("matches odds to rollable configured rarity buckets", function()
		local result = CratePresentation.forCrate({
			ItemPool = { "Common", "Rare", "Legend", "Exclusive" },
		}, {
			Rarities = RARITIES,
			Items = {
				Common = { DisplayName = "Common", Rarity = "Common" },
				Rare = { DisplayName = "Rare", Rarity = "Rare" },
				Legend = { DisplayName = "Solar Flare", Rarity = "Legendary" },
				Exclusive = { DisplayName = "Event Horizon", Rarity = "Exclusive" },
			},
		})

		T.expect(result.odds):toEqual("ODDS  COMMON 70%  |  RARE 24%  |  LEGENDARY 6%")
		T.expect(result.highlight):toEqual("CHASE: Solar Flare  |  LEGENDARY")
		T.expect(result.rarityCount):toEqual(3)
		T.expect(#result.outcomes):toEqual(3)
	end)

	T.it("normalizes per-item probabilities to one hundred percent", function()
		local result = CratePresentation.forCrate({ ItemPool = { "Red", "Blue" } }, {
			Rarities = RARITIES,
			Items = {
				Red = { DisplayName = "Red Ball", Rarity = "Common" },
				Blue = { DisplayName = "Blue Ball", Rarity = "Common" },
			},
		})

		T.expect(result.odds):toEqual("ODDS  COMMON 100%")
		T.expect(result.highlight):toEqual("2 COLOR DROPS  |  Blue Ball")
		T.expect(result.outcomes[1].probability):toBeNear(0.5, 0.0001)
		T.expect(result.outcomes[2].probability):toBeNear(0.5, 0.0001)
	end)

	T.it("lists pity guarantees rarest first and omits rarities the crate cannot drop", function()
		local result = CratePresentation.forCrate({
			ItemPool = { "Common", "Rare" },
			Pity = { Rare = 5, Legendary = 25 },
		}, {
			Rarities = RARITIES,
			Items = {
				Common = { DisplayName = "Common", Rarity = "Common" },
				Rare = { DisplayName = "Rare", Rarity = "Rare" },
			},
		})

		T.expect(#result.pity):toEqual(1)
		T.expect(result.pity[1].rarity):toEqual("Rare")
		T.expect(result.pity[1].threshold):toEqual(5)
	end)

	T.it("orders multiple guarantees by rarity", function()
		local result = CratePresentation.forCrate({
			ItemPool = { "Common", "Rare", "Legend" },
			Pity = { Rare = 5, Legendary = 25 },
		}, {
			Rarities = RARITIES,
			Items = {
				Common = { DisplayName = "Common", Rarity = "Common" },
				Rare = { DisplayName = "Rare", Rarity = "Rare" },
				Legend = { DisplayName = "Solar Flare", Rarity = "Legendary" },
			},
		})

		T.expect(#result.pity):toEqual(2)
		T.expect(result.pity[1].rarity):toEqual("Legendary")
		T.expect(result.pity[2].rarity):toEqual("Rare")
	end)

	T.it("reports no guarantees for crates without a Pity block", function()
		local result = CratePresentation.forCrate({ ItemPool = { "Common" } }, {
			Rarities = RARITIES,
			Items = { Common = { DisplayName = "Common", Rarity = "Common" } },
		})

		T.expect(#result.pity):toEqual(0)
	end)
end)

return true
