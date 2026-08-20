--!nonstrict
-- Validates the Studio-authored combat animations declared in Config.Animations.
-- Only required clips are asserted: optional ones are the polish passes that may
-- not be authored yet, and the animation layer is built to run without them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Animations = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Animations"))
local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))

return function()
	describe("Animation assets", function()
		it("authors every required clip in Config.Animations", function()
			local checked = 0
			for _, clips in Animations.Clips do
				for _, clip in clips do
					expect(typeof(clip.Name)).to.equal("string")
					if not clip.Required then
						continue
					end
					local animation = TestAssets.get(ReplicatedStorage, "Assets", Animations.FolderName, clip.Name)
					expect(animation:IsA("Animation")).to.equal(true)
					expect(animation.AnimationId ~= "").to.equal(true)
					checked += 1
				end
			end
			expect(checked > 0).to.equal(true)
		end)

		it("declares a valid animation priority for every clip", function()
			for _, clips in Animations.Clips do
				for _, clip in clips do
					expect(Enum.AnimationPriority[clip.Priority]).to.be.ok()
				end
			end
		end)
	end)
end
