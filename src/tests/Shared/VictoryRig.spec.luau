-- Both places author the same complete preview rig; cosmetic poses remain isolated from live characters.
--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VictoryRig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("VictoryRig")
)
local Emotes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Emotes"))

return function()
	describe("VictoryRig", function()
		it("poses every emote on a complete authored rig and cleans up its clone", function()
			local world = Instance.new("WorldModel")
			local display = VictoryRig.create(world, nil)
			expect(display.model.LeftFoot.MeshId).to.equal("rbxassetid://134464286998182")
			for _, descendant in display.model:GetDescendants() do
				expect(descendant:IsA("Constraint") or descendant:IsA("Humanoid") or descendant:IsA("Sound")).to.equal(
					false
				)
			end
			for _, style in Emotes.Styles do
				for _, time in { 0, style.Duration / 2, style.Duration } do
					display.pose(style, time, false)
					for _, part in display.model:GetChildren() do
						if part:IsA("BasePart") then
							expect(part.Anchored).to.equal(true)
							expect(part.CanCollide or part.CanTouch or part.CanQuery).to.equal(false)
							expect(part.Position.Magnitude < 10).to.equal(true)
						end
					end
				end
			end
			display.destroy()
			expect(#world:GetChildren()).to.equal(0)
			world:Destroy()
		end)
	end)
end
