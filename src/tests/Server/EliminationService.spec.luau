--!nonstrict
-- EliminationService on real rigs: the CombatAlive attribute as the single
-- source of truth, ragdoll constraint construction over the rig's Motor6Ds,
-- and full restore on revive. Native Humanoid health must never change.

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local EliminationService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("EliminationService"))
local Helpers = ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers")
local CharacterFixture = require(Helpers:WaitForChild("CharacterFixture"))
local FakePlayer = require(Helpers:WaitForChild("FakePlayer"))

local function countDescendants(character: Model, className: string, namePrefix: string?): number
	local count = 0
	for _, descendant in character:GetDescendants() do
		if descendant:IsA(className) then
			if namePrefix == nil or string.sub(descendant.Name, 1, #namePrefix) == namePrefix then
				count += 1
			end
		end
	end
	return count
end

local function motors(character: Model): { Motor6D }
	local found = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			table.insert(found, descendant)
		end
	end
	return found
end

return function()
	describe("EliminationService", function()
		local player
		local rig

		beforeEach(function()
			player = FakePlayer.new(200001)
			rig = CharacterFixture.create("ElimRig")
			player.Character = rig
		end)

		afterEach(function()
			CharacterFixture.destroy(rig)
		end)

		it("down marks the character eliminated and ragdolls its joints", function()
			local humanoid = rig:FindFirstChildOfClass("Humanoid")
			local healthBefore = humanoid.Health

			expect(EliminationService.down(player, nil)).to.equal(true)

			expect(rig:GetAttribute("CombatAlive")).to.equal(false)
			expect(rig:GetAttribute("CombatHealth")).to.equal(0)
			expect(player:GetAttribute("CombatAlive")).to.equal(false)
			expect(EliminationService.isDown(rig)).to.equal(true)

			expect(humanoid.Health).to.equal(healthBefore)
			expect(humanoid.PlatformStand).to.equal(true)
			expect(humanoid.AutoRotate).to.equal(false)

			expect(countDescendants(rig, "BallSocketConstraint", "Ragdoll_") > 0).to.equal(true)
			expect(countDescendants(rig, "NoCollisionConstraint", "RagdollNoCollision_") > 0).to.equal(true)

			local sawDisabledMotor = false
			for _, motor in motors(rig) do
				local root = motor.Part0
				local other = motor.Part1
				local touchesRoot = (root and root.Name == "HumanoidRootPart")
					or (other and other.Name == "HumanoidRootPart")
				if not touchesRoot then
					expect(motor.Enabled).to.equal(false)
					sawDisabledMotor = true
				end
			end
			expect(sawDisabledMotor).to.equal(true)
		end)

		it("down is rejected while already eliminated", function()
			expect(EliminationService.down(player, nil)).to.equal(true)
			expect(EliminationService.down(player, nil)).to.equal(false)
		end)

		it("down is rejected without a character", function()
			local ghost = FakePlayer.new(200002)
			expect(EliminationService.down(ghost, nil)).to.equal(false)
		end)

		it("up removes the ragdoll and restores the saved state", function()
			local humanoid = rig:FindFirstChildOfClass("Humanoid")
			local root = rig:FindFirstChild("HumanoidRootPart")
			local rootCanCollideBefore = root.CanCollide
			local autoRotateBefore = humanoid.AutoRotate

			expect(EliminationService.down(player, nil)).to.equal(true)
			expect(EliminationService.up(player)).to.equal(true)

			expect(rig:GetAttribute("CombatAlive")).to.equal(true)
			expect(EliminationService.isDown(rig)).to.equal(false)
			expect(countDescendants(rig, "BallSocketConstraint", "Ragdoll_")).to.equal(0)
			expect(countDescendants(rig, "NoCollisionConstraint", "RagdollNoCollision_")).to.equal(0)
			for _, motor in motors(rig) do
				expect(motor.Enabled).to.equal(true)
			end
			expect(root.CanCollide).to.equal(rootCanCollideBefore)
			expect(humanoid.AutoRotate).to.equal(autoRotateBefore)
			expect(humanoid.PlatformStand).to.equal(false)
		end)

		it("up on a never-downed character still marks it alive", function()
			expect(EliminationService.up(player)).to.equal(true)
			expect(rig:GetAttribute("CombatAlive")).to.equal(true)
		end)
	end)
end
