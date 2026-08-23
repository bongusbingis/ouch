--!strict

-- The profile template is the shape every service writes through. It had no
-- headless coverage once the migration spec was removed, and it is the one
-- config a typo in breaks silently: a missing branch does not error, it just
-- reconciles into existence empty and the owning service reads nil forever.

local T = require(script.Parent.TestKit)
local DataConfig = require(script.Parent.Parent.Parent.Config.Data)
local Shop = require(script.Parent.Parent.Parent.Config.Shop)

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
		-- Bucket must never match a real period index, or a brand new profile
		-- would be treated as already drawn and the player would see no offers
		-- until the next rotation.
		local template = DataConfig.Template
		T.expect(type(template.Shop.Offers)):toEqual("table")
		T.expect(#template.Shop.Offers):toEqual(0)
		T.expect(template.Shop.Bucket < 0):toBeTruthy()
	end)

	T.it("cannot collide with a real period index for any supported rotation", function()
		-- Period indices are floor(now / RotationSeconds) and time is positive,
		-- so any negative sentinel is unreachable. Pinned because shortening the
		-- rotation raises the index rather than lowering it.
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
