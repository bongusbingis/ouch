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

		T.expect(result.odds):toEqual("ODDS  COMMON 70%  •  RARE 24%  •  LEGENDARY 6%")
		T.expect(result.highlight):toEqual("CHASE: Solar Flare  •  LEGENDARY")
		T.expect(result.rarityCount):toEqual(3)
	end)

	T.it("normalizes a single available rarity to one hundred percent", function()
		local result = CratePresentation.forCrate({ ItemPool = { "Red", "Blue" } }, {
			Rarities = RARITIES,
			Items = {
				Red = { DisplayName = "Red Ball", Rarity = "Common" },
				Blue = { DisplayName = "Blue Ball", Rarity = "Common" },
			},
		})

		T.expect(result.odds):toEqual("ODDS  COMMON 100%")
		T.expect(result.highlight):toEqual("2 COLOR DROPS  •  Blue Ball")
	end)
end)

return true
