-- Description: Spec for the profile template every service writes through, since a missing branch fails silently rather than erroring: starting balances, owned branches, and positive progression awards.

--!strict

local T = require(script.Parent.TestKit)
local DataConfig = require(script.Parent.Parent.Parent.Config.Progression.Data)
local Shop = require(script.Parent.Parent.Parent.Config.Economy.Shop)

T.describe("Data config", function()
	T.it("gives every player a starting balance", function()
		T.expect(DataConfig.Template.Bonks > 0):toBeTruthy()
	end)

	T.it("declares the branches the economy services own", function()
		local template = DataConfig.Template
		T.expect(type(template.Cosmetics.Owned)):toEqual("table")
		T.expect(type(template.Cosmetics.Equipped)):toEqual("table")
		T.expect(type(template.Crates.Pity)):toEqual("table")
		T.expect(type(template.Receipts)):toEqual("table")
		T.expect(type(template.Entitlements.PremiumSeasons)):toEqual("table")
		T.expect(type(template.Season.ClaimedFree)):toEqual("table")
		T.expect(type(template.Season.ClaimedPremium)):toEqual("table")
	end)

	T.it("starts the rotating shop in a state that forces a first draw", function()
		local template = DataConfig.Template
		T.expect(type(template.Shop.Offers)):toEqual("table")
		T.expect(#template.Shop.Offers):toEqual(0)
		T.expect(template.Shop.Bucket < 0):toBeTruthy()
	end)

	T.it("cannot collide with a real period index for any supported rotation", function()
		T.expect(math.floor(0 / Shop.Rotation.RotationSeconds) > DataConfig.Template.Shop.Bucket):toBeTruthy()
	end)

	T.it("awards positive progression for the things a match rewards", function()
		for _, table_ in { DataConfig.ProgressionXP, DataConfig.ProgressionBonks } do
			for _, amount in table_ do
				T.expect(amount > 0):toBeTruthy()
			end
		end
	end)
end)

return true
