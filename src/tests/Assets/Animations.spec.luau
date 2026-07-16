--!nonstrict
-- Validates the Studio-authored combat animations referenced from
-- Config.Combat: SimulationServer WaitForChilds these by name at runtime.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))

return function()
	describe("Animation assets", function()
		it("authors every combat animation referenced by Config.Combat", function()
			local names = {
				Combat.Dodgeball.ThrowAnimationName,
				Combat.Hammer.AnimationName,
			}
			for _, name in names do
				expect(typeof(name)).to.equal("string")
				local animation = TestAssets.get(ReplicatedStorage, "Assets", "Animations", name)
				expect(animation:IsA("Animation")).to.equal(true)
				expect(animation.AnimationId ~= "").to.equal(true)
			end
		end)
	end)
end
