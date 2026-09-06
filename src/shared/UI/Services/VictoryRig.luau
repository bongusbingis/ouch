-- Poses a clone of the authored R15 rig through its attachment graph; never touches a live character.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cosmetics = require(ReplicatedStorage.Config.Cosmetics.Cosmetics)
local Emotes = require(ReplicatedStorage.Config.Cosmetics.Emotes)
local CharacterColorLogic = require(ReplicatedStorage.Shared.Game.Economy.CharacterColorLogic)
local VictoryPose = require(ReplicatedStorage.Shared.Game.Cosmetics.VictoryPose)
local VictoryRig = {}

function VictoryRig.style(itemId: string?): any
	local item = if itemId then Cosmetics.Items[itemId] else nil
	local key = if item and item.Category == "EmoteAssets" then item.EmoteStyle else Emotes.DefaultStyle
	return Emotes.Styles[key] or Emotes.Styles[Emotes.DefaultStyle]
end

local function rotation(name: string, pose): CFrame
	if name == "LeftShoulderRigAttachment" then
		return CFrame.Angles(0, 0, pose.leftArm)
	elseif name == "RightShoulderRigAttachment" then
		return CFrame.Angles(0, 0, pose.rightArm)
	elseif name == "LeftElbowRigAttachment" then
		return CFrame.Angles(0, 0, pose.leftElbow)
	elseif name == "RightElbowRigAttachment" then
		return CFrame.Angles(0, 0, pose.rightElbow)
	elseif name == "LeftHipRigAttachment" then
		return CFrame.Angles(pose.leftLeg, 0, 0)
	elseif name == "RightHipRigAttachment" then
		return CFrame.Angles(pose.rightLeg, 0, 0)
	end
	return CFrame.identity
end

function VictoryRig.create(world: WorldModel, colorId: string?): any
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Rigs"):WaitForChild("CharacterRig")
	assert(template:IsA("Model"), "[VictoryRig] Assets.Rigs.CharacterRig must be a Model")
	local rig = template:Clone()
	rig.Parent = world
	local root = rig:WaitForChild("HumanoidRootPart")
	assert(root:IsA("BasePart"), "[VictoryRig] HumanoidRootPart must be a BasePart")
	local color = CharacterColorLogic.resolve(Cosmetics, colorId)
	local pairsByName = {}
	for _, descendant in rig:GetDescendants() do
		if
			descendant:IsA("BaseScript")
			or descendant:IsA("Animator")
			or descendant:IsA("JointInstance")
			or descendant:IsA("Humanoid")
			or descendant:IsA("Constraint")
			or descendant:IsA("NoCollisionConstraint")
			or descendant:IsA("Sound")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			if descendant:IsA("MeshPart") then
				descendant.Color = color
			end
		elseif descendant:IsA("Attachment") and string.match(descendant.Name, "RigAttachment$") then
			local pair = pairsByName[descendant.Name] or {}
			table.insert(pair, descendant)
			pairsByName[descendant.Name] = pair
		end
	end
	local graph = {}
	for name, pair in pairsByName do
		assert(#pair == 2, `[VictoryRig] {name} must have two authored attachments`)
		for index, attachment in pair do
			local part = attachment.Parent
			graph[part] = graph[part] or {}
			table.insert(graph[part], { name = name, from = attachment, to = pair[3 - index] })
		end
	end
	local ordered, queue, seen = {}, { root }, { [root] = true }
	local cursor = 1
	while cursor <= #queue do
		local part = queue[cursor]
		cursor += 1
		for _, link in graph[part] or {} do
			local child = link.to.Parent
			if not seen[child] then
				seen[child] = true
				table.insert(queue, child)
				table.insert(ordered, {
					name = link.name,
					parent = part,
					child = child,
					c0 = link.from.CFrame,
					c1 = link.to.CFrame:Inverse(),
				})
			end
		end
	end
	assert(#ordered == 15, "[VictoryRig] CharacterRig must have a connected R15 attachment graph")
	rig:PivotTo(CFrame.identity)
	local bounds = rig:GetBoundingBox()
	local rootOffset = root.Position - bounds.Position
	local display = { model = rig }
	function display.pose(style, time: number, reducedMotion: boolean?)
		local pose = VictoryPose.sample(style.Pose, time, style.Duration, reducedMotion)
		root.CFrame = CFrame.new(rootOffset + Vector3.new(0, pose.lift, 0))
			* CFrame.Angles(0, math.pi + pose.yaw, pose.lean)
		for _, joint in ordered do
			joint.child.CFrame = joint.parent.CFrame * joint.c0 * rotation(joint.name, pose) * joint.c1
		end
	end
	function display.destroy()
		rig:Destroy()
	end
	return display
end

return VictoryRig
