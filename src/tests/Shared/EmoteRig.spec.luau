-- Name: EmoteRig.spec.luau
-- Author: Jack C.
-- Description: Confirms EmoteRig clones a complete authored rig that keeps its Humanoid, Animator, and animatable joints (AnimationConstraint or Motor6D), and cleans up its clone on destroy.
-- Created: 2026-09-09

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EmoteRig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("EmoteRig")
)

return function()
	describe("EmoteRig", function()
		it("clones a complete authored, Animator-driven rig and cleans up its clone", function()
			local world = Instance.new("WorldModel")
			local display = EmoteRig.create(world, nil)
			expect(display.model.LeftFoot.MeshId).to.equal("rbxassetid://134464286998182")

			local humanoid = display.model:FindFirstChildOfClass("Humanoid")
			expect(humanoid ~= nil).to.equal(true)
			expect(humanoid:FindFirstChildOfClass("Animator") ~= nil).to.equal(true)
			expect(display.animator ~= nil).to.equal(true)

			local jointCount = 0
			for _, descendant in display.model:GetDescendants() do
				if descendant:IsA("Motor6D") or descendant:IsA("AnimationConstraint") then
					jointCount += 1
				end
			end
			expect(jointCount > 0).to.equal(true)

			for _, part in display.model:GetChildren() do
				if part:IsA("BasePart") then
					expect(part.CanCollide or part.CanTouch or part.CanQuery).to.equal(false)
				end
			end

			display.destroy()
			expect(#world:GetChildren()).to.equal(0)
			world:Destroy()
		end)
	end)
end
