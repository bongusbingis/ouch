--!strict
-- Config-driven sounds fail silently at runtime when an id is malformed or an
-- entry is missing, so the shape is checked in place instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Audio"))

local REQUIRED_EFFECTS = {
	"HammerElimination",
	"HammerSwing",
	"JumpPadBounce",
	"DodgeballElimination",
	"DodgeballThrow",
	"DodgeballBounce",
	"ElimZoneFall",
}

return function()
	describe("Gameplay audio config", function()
		it("defines every effect the game plays", function()
			for _, name in REQUIRED_EFFECTS do
				expect(Audio.Gameplay[name]).to.be.ok()
			end
		end)

		it("gives every effect at least one well formed asset id", function()
			for name, effect in Audio.Gameplay do
				expect(#effect.AssetIds > 0).to.equal(true)
				for _, assetId in effect.AssetIds do
					expect(type(assetId)).to.equal("string")
					expect(string.match(assetId, "^rbxassetid://%d+$") ~= nil).to.equal(true)
				end
			end
		end)

		it("never repeats an asset id within one effect", function()
			for name, effect in Audio.Gameplay do
				local seen = {}
				for _, assetId in effect.AssetIds do
					expect(seen[assetId]).to.equal(nil)
					seen[assetId] = true
				end
			end
		end)

		it("declares a usable scope and volume", function()
			for name, effect in Audio.Gameplay do
				expect(effect.Scope == "World" or effect.Scope == "Local").to.equal(true)
				expect(type(effect.Volume)).to.equal("number")
				expect(effect.Volume > 0).to.equal(true)
			end
		end)
	end)
end
