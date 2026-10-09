-- Description: Checks published gameplay audio cues against the runtime's required entry and asset ID contract.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Audio"))

local REQUIRED_EFFECTS = {
	"DefaultElimination",
	"HammerSwing",
	"JumpPadBounce",
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

		it("gives every effect a dense array of well formed asset IDs", function()
			for name, effect in Audio.Gameplay do
				expect(type(name)).to.equal("string")
				expect(type(effect.AssetIds)).to.equal("table")
				expect(#effect.AssetIds > 0).to.equal(true)
				local count = 0
				for index, assetId in effect.AssetIds do
					expect(type(index)).to.equal("number")
					expect(index >= 1 and index <= #effect.AssetIds and index % 1 == 0).to.equal(true)
					expect(type(assetId)).to.equal("string")
					expect(string.match(assetId, "^rbxassetid://%d+$") ~= nil).to.equal(true)
					count += 1
				end
				expect(count).to.equal(#effect.AssetIds)
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
