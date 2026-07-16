--!strict
-- Test-only character rigs for humanoid-dependent specs. The cloud execution
-- environment has no players, so rigs are built through the engine's
-- CreateHumanoidModelFromDescription (a real, standard R15 rig) rather than
-- hand-assembling gameplay assets in code. Physics does not step in this
-- environment, so the HumanoidRootPart is anchored to keep rigs stationary.
-- Callers own cleanup: destroy() every fixture in afterEach.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CharacterFixture = {}

function CharacterFixture.create(name: string?): Model
	local description = Instance.new("HumanoidDescription")
	local rig = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	description:Destroy()

	rig.Name = name or "TestRig"

	local root = rig:WaitForChild("HumanoidRootPart")
	assert(root:IsA("BasePart"), "[CharacterFixture] HumanoidRootPart must be a BasePart")
	root.Anchored = true

	rig.Parent = Workspace
	return rig
end

function CharacterFixture.destroy(rig: Model?)
	if rig then
		rig:Destroy()
	end
end

return CharacterFixture
