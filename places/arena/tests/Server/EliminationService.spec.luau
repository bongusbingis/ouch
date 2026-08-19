--!nonstrict
-- EliminationService state, ragdoll construction, and restoration on a
-- humanoid fixture with a deterministic non-root joint.

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

local function addRagdollTestJoint(character: Model): Motor6D
	local part0 = Instance.new("Part")
	part0.Name = "RagdollTestPart0"
	part0.Anchored = true
	part0.Parent = character

	local part1 = Instance.new("Part")
	part1.Name = "RagdollTestPart1"
	part1.Anchored = true
	part1.Parent = character

	local motor = Instance.new("Motor6D")
	motor.Name = "RagdollTestJoint"
	motor.Part0 = part0
	motor.Part1 = part1
	motor.Parent = part0
	return motor
end

return function()
	describe("EliminationService", function()
		local player
		local rig
		local testMotor

		beforeEach(function()
			player = FakePlayer.new(200001)
			rig = CharacterFixture.create("ElimRig")
			testMotor = addRagdollTestJoint(rig)
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
			expect(testMotor.Enabled).to.equal(false)

			local sawDisabledMotor = false
			for _, motor in motors(rig) do
				local part0 = motor.Part0
				local part1 = motor.Part1
				local eligible = part0 ~= nil
					and part1 ~= nil
					and part0.Name ~= "HumanoidRootPart"
					and part1.Name ~= "HumanoidRootPart"
				if eligible then
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
			expect(testMotor.Enabled).to.equal(true)
			for _, motor in motors(rig) do
				local part0 = motor.Part0
				local part1 = motor.Part1
				if
					part0 ~= nil
					and part1 ~= nil
					and part0.Name ~= "HumanoidRootPart"
					and part1.Name ~= "HumanoidRootPart"
				then
					expect(motor.Enabled).to.equal(true)
				end
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
