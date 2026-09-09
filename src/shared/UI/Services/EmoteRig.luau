-- Name: EmoteRig.luau
-- Author: Jack C.
-- Description: Clones the authored R15 rig into a display-only, Animator-driven rig that keeps its joints and plays real emote clips instead of hand-posing them.
-- Created: 2026-09-09

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterAppearance = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CharacterAppearance")
)
local EmotePlayer = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Cosmetics"):WaitForChild("EmotePlayer")
)

local EmoteRig = {}

function EmoteRig.create(world: Instance, colorId: string?, costumeId: string?): any
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Rigs"):WaitForChild("CharacterRig")
	assert(template:IsA("Model"), "[EmoteRig] Assets.Rigs.CharacterRig must be a Model")
	CharacterAppearance.prepare({ costumeId = costumeId })
	local rig = template:Clone()

	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		elseif descendant:IsA("BaseScript") then
			descendant:Destroy()
		end
	end

	local humanoid = rig:WaitForChild("Humanoid")
	assert(humanoid:IsA("Humanoid"), "[EmoteRig] CharacterRig.Humanoid must be a Humanoid")
	local root = rig:WaitForChild("HumanoidRootPart")
	assert(root:IsA("BasePart"), "[EmoteRig] CharacterRig.HumanoidRootPart must be a BasePart")
	local animator = humanoid:WaitForChild("Animator")
	assert(animator:IsA("Animator"), "[EmoteRig] CharacterRig.Humanoid.Animator must be an Animator")

	humanoid.AutoRotate = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	root.Anchored = true

	rig.Parent = world
	rig:PivotTo(CFrame.identity)

	local bounds = rig:GetBoundingBox()
	local rootOffset = root.Position - bounds.Position

	local appearance = CharacterAppearance.create(
		rig,
		{ characterColorId = colorId, costumeId = costumeId },
		{ live = true }
	)

	local current: AnimationTrack? = nil

	local display = { model = rig, animator = animator }

	function display.setOrigin(origin: CFrame)
		root.CFrame = origin * CFrame.new(rootOffset) * CFrame.Angles(0, math.pi, 0)
	end

	function display.playEmote(emoteId: string): AnimationTrack?
		EmotePlayer.stop(current)
		current = EmotePlayer.play(animator :: Animator, emoteId)
		return current
	end

	function display.stopEmote()
		EmotePlayer.stop(current)
		current = nil
	end

	function display.destroy()
		display.stopEmote()
		appearance.destroy()
		rig:Destroy()
	end

	return display
end

return EmoteRig
