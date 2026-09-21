-- Description: In-place spec for elimination state, ragdoll construction, and full restoration on a real humanoid rig fixture.

--!nonstrict

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local EliminationService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("EliminationService"))
local Helpers = ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers")
local CharacterFixture = require(Helpers:WaitForChild("CharacterFixture"))
local FakePlayer = require(Helpers:WaitForChild("FakePlayer"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local CharacterAppearance = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CharacterAppearance")
)

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

		it("temporarily ragdolls an impact without changing combat state", function()
			rig:SetAttribute("CombatAlive", true)
			rig:SetAttribute("CombatHealth", 100)
			player:SetAttribute("CombatAlive", true)
			player:SetAttribute("CombatHealth", 100)

			expect(EliminationService.impact(player, 0.05)).to.equal(true)
			expect(rig:GetAttribute("CombatAlive")).to.equal(true)
			expect(player:GetAttribute("CombatAlive")).to.equal(true)
			expect(countDescendants(rig, "BallSocketConstraint", "Ragdoll_") > 0).to.equal(true)
			task.wait(0.1)
			expect(countDescendants(rig, "BallSocketConstraint", "Ragdoll_")).to.equal(0)
			expect(testMotor.Enabled).to.equal(true)
		end)

		it("restores an impact's saved physics flags and keeps its momentum", function()
			local humanoid = rig:FindFirstChildOfClass("Humanoid")
			local root = rig:FindFirstChild("HumanoidRootPart")
			local part = testMotor.Part1
			root.Anchored = false
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = true
			part.CanQuery = false
			part.Massless = true
			humanoid.AutoRotate = false
			humanoid.PlatformStand = true
			humanoid.RequiresNeck = false
			humanoid.BreakJointsOnDeath = false
			humanoid.EvaluateStateMachine = false
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)

			expect(EliminationService.impact(player, 0.05)).to.equal(true)
			task.wait(0.02)
			expect(EliminationService.impact(player, 0.1)).to.equal(true)
			root.AssemblyLinearVelocity = Vector3.new(30, 12, 0)
			task.wait(0.12)

			expect(part.Anchored).to.equal(true)
			expect(part.CanCollide).to.equal(false)
			expect(part.CanTouch).to.equal(true)
			expect(part.CanQuery).to.equal(false)
			expect(part.Massless).to.equal(true)
			expect(humanoid.AutoRotate).to.equal(false)
			expect(humanoid.PlatformStand).to.equal(true)
			expect(humanoid.RequiresNeck).to.equal(false)
			expect(humanoid.BreakJointsOnDeath).to.equal(false)
			expect(humanoid.EvaluateStateMachine).to.equal(false)
			expect(humanoid:GetStateEnabled(Enum.HumanoidStateType.GettingUp)).to.equal(false)
			expect(root.AssemblyLinearVelocity.Magnitude > 0).to.equal(true)
		end)

		it("does not let an earlier impact expiry restore a later impact", function()
			expect(EliminationService.impact(player, 0.05)).to.equal(true)
			task.wait(0.02)
			expect(EliminationService.impact(player, 0.12)).to.equal(true)
			task.wait(0.06)
			expect(countDescendants(rig, "BallSocketConstraint", "Ragdoll_") > 0).to.equal(true)
			task.wait(0.1)
			expect(countDescendants(rig, "BallSocketConstraint", "Ragdoll_")).to.equal(0)
		end)

		it("does not let an impact expiry revive a real elimination", function()
			expect(EliminationService.impact(player, 0.05)).to.equal(true)
			expect(EliminationService.down(player, nil)).to.equal(true)
			task.wait(0.1)
			expect(rig:GetAttribute("CombatAlive")).to.equal(false)
			expect(countDescendants(rig, "BallSocketConstraint", "Ragdoll_") > 0).to.equal(true)
		end)

		it("preserves native death evaluation so Roblox can replace a dead character", function()
			local humanoid = rig:FindFirstChildOfClass("Humanoid")
			humanoid.BreakJointsOnDeath = false
			humanoid.Health = 0
			local evaluation = humanoid.EvaluateStateMachine
			expect(EliminationService.down(player)).to.equal(true)
			expect(humanoid.EvaluateStateMachine).to.equal(evaluation)
			expect(countDescendants(rig, "BallSocketConstraint", "Ragdoll_")).to.equal(0)
			expect(EliminationService.up(player)).to.equal(false)
			expect(rig:GetAttribute("CombatAlive")).to.equal(false)
		end)

		it("restores native death evaluation when health reaches zero during a ragdoll", function()
			local humanoid = rig:FindFirstChildOfClass("Humanoid")
			-- The shared fixture anchors its root for deterministic tests, but a live
			-- character is unanchored when native death state evaluation runs.
			rig.HumanoidRootPart.Anchored = false
			EliminationService.down(player)
			humanoid.Health = 0
			expect(EliminationService.forget(rig)).to.equal(true)
			expect(EliminationService.forget(rig)).to.equal(false)
			expect(humanoid.EvaluateStateMachine).to.equal(true)
			task.wait(0.1)
			expect(humanoid:GetState()).to.equal(Enum.HumanoidStateType.Dead)
			expect(EliminationService.up(player)).to.equal(false)
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

		it("restores a previously disabled humanoid state machine", function()
			local humanoid = rig:FindFirstChildOfClass("Humanoid")
			humanoid.EvaluateStateMachine = false
			EliminationService.down(player, nil)
			EliminationService.up(player)
			expect(humanoid.EvaluateStateMachine).to.equal(false)
		end)

		it("releases ragdoll resources when the character is removed", function()
			expect(EliminationService.down(player, nil)).to.equal(true)
			player.CharacterRemoving:Fire(rig)
			expect(countDescendants(rig, "BallSocketConstraint", "Ragdoll_")).to.equal(0)
			expect(testMotor.Enabled).to.equal(true)
			EliminationService.forget(rig)
		end)

		it("up on a never-downed character still marks it alive", function()
			expect(EliminationService.up(player)).to.equal(true)
			expect(rig:GetAttribute("CombatAlive")).to.equal(true)
		end)

		it("keeps all costumes visual through ragdoll, respawn and an equip while down", function()
			CharacterFixture.destroy(rig)
			rig = CharacterFixture.createBlob("CostumeElimRig")
			player.Character = rig
			local appearance = CharacterAppearance.create(rig, {}, { live = true })
			local function expectCosmeticPhysics()
				for _, part in rig.CostumeVisuals:GetDescendants() do
					if part:IsA("BasePart") then
						expect(part.CanCollide or part.CanQuery or part.CanTouch).to.equal(false)
						expect(part.Massless).to.equal(true)
					end
				end
			end
			for id, item in Cosmetics.Items do
				if not item.Contents then
					continue
				end
				appearance.update({ costumeId = id })
				expect(EliminationService.down(player, nil)).to.equal(true)
				expectCosmeticPhysics()
				expect(EliminationService.up(player)).to.equal(true)
				expectCosmeticPhysics()
			end
			EliminationService.down(player, nil)
			appearance.update({ costumeId = "RainHopper" })
			expectCosmeticPhysics()
			EliminationService.up(player)
			expectCosmeticPhysics()
			appearance.destroy()
		end)
	end)
end
