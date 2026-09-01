-- Name: CharacterFixture.luau
-- Author: Jack C.
-- Description: Builds real anchored humanoid rigs for in-place specs through the engine's own rig creation, since the cloud execution environment has no players.
-- Created: 2026-07-16

--!strict

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
