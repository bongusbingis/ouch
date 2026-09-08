-- Description: Builds real anchored humanoid rigs for in-place specs through the engine's own rig creation, since the cloud execution environment has no players.

--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CharacterFixture = {}

local function create(description: HumanoidDescription, name: string?): Model
	local rig = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	description:Destroy()

	rig.Name = name or "TestRig"

	local root = rig:WaitForChild("HumanoidRootPart")
	assert(root:IsA("BasePart"), "[CharacterFixture] HumanoidRootPart must be a BasePart")
	root.Anchored = true

	rig.Parent = Workspace
	return rig
end

function CharacterFixture.create(name: string?): Model
	return create(Instance.new("HumanoidDescription"), name)
end

function CharacterFixture.createBlob(name: string?): Model
	-- Published body assets and uniform scale from the experience's loaded avatar, not the account avatar.
	local description = Instance.new("HumanoidDescription")
	description.Head = 107944744988228
	description.Torso = 105501586240500
	description.LeftArm = 100763057323637
	description.RightArm = 118403097845313
	description.LeftLeg = 79035461011820
	description.RightLeg = 125583380937048
	description.HeadScale = 1.017769455909729
	description.HeightScale = 1.017769455909729
	description.WidthScale = 1.017769455909729
	description.DepthScale = 1.017769455909729
	description.BodyTypeScale = 0
	description.ProportionScale = 0
	return create(description, name or "BlobTestRig")
end

function CharacterFixture.destroy(rig: Model?)
	if rig then
		rig:Destroy()
	end
end

return CharacterFixture
