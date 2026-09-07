--!strict

-- Clones authored components and aligns their BodyMount frames to the R15 body; cosmetics never affect collision or mass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cosmetics = require(ReplicatedStorage.Config.Cosmetics.Cosmetics)
local CostumeVisualFactory = {}

CostumeVisualFactory.BodyParts = table.freeze({
	Head = true,
	UpperTorso = true,
	LowerTorso = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
})

function CostumeVisualFactory.prepare(outfitId: string?): { Model }?
	local outfit = if outfitId then Cosmetics.Items[outfitId] else nil
	if not outfit or outfit.Category ~= "CostumeAssets" or not outfit.Contents then
		return nil
	end
	local assets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Cosmetics"):WaitForChild("Costumes")
	assert(assets:IsA("Folder"), "[CostumeVisualFactory] Assets.Cosmetics.Costumes must be a Folder")
	local templates = {}
	local coveredTargets = {}
	for _, componentId in outfit.Contents do
		local template = assets:WaitForChild(componentId)
		assert(template:IsA("Model"), `[CostumeVisualFactory] {componentId} must be a Model`)
		local count = 0
		for _, descendant in template:GetDescendants() do
			assert(
				not descendant:IsA("LuaSourceContainer"),
				`[CostumeVisualFactory] {componentId} cannot contain scripts`
			)
			assert(
				not descendant:IsA("JointInstance")
					and not descendant:IsA("Constraint")
					and not descendant:IsA("WeldConstraint")
					and not descendant:IsA("NoCollisionConstraint"),
				`[CostumeVisualFactory] {componentId} cannot contain rig joints or constraints`
			)
			if descendant:IsA("BasePart") then
				local target = descendant:GetAttribute("BodyPart")
				assert(
					typeof(target) == "string" and CostumeVisualFactory.BodyParts[target],
					`[CostumeVisualFactory] {descendant:GetFullName()} requires an R15 BodyPart`
				)
				local bodySize = descendant:GetAttribute("BodySize")
				assert(
					typeof(bodySize) == "Vector3"
						and bodySize.X > 0
						and bodySize.Y > 0
						and bodySize.Z > 0
						and bodySize.Magnitude < math.huge,
					`[CostumeVisualFactory] {descendant:GetFullName()} requires its authored BodySize`
				)
				local coversBody = descendant:GetAttribute("CoversBody")
				assert(
					coversBody == nil or typeof(coversBody) == "boolean",
					`[CostumeVisualFactory] {descendant:GetFullName()}.CoversBody must be a boolean`
				)
				if coversBody then
					assert(
						not coveredTargets[target],
						`[CostumeVisualFactory] {outfitId} covers {target} more than once`
					)
					assert(
						descendant:IsA("MeshPart") and descendant.Size == bodySize,
						`[CostumeVisualFactory] {descendant:GetFullName()} must use its exact fitted body mesh size`
					)
					coveredTargets[target] = true
				end
				local mount = descendant:WaitForChild("BodyMount")
				assert(
					mount:IsA("Attachment"),
					`[CostumeVisualFactory] {descendant:GetFullName()}.BodyMount must be an Attachment`
				)
				count += 1
			end
		end
		assert(count > 0, `[CostumeVisualFactory] {componentId} has no render parts`)
		table.insert(templates, template)
	end
	return templates
end

function CostumeVisualFactory.create(character: Model, outfitId: string, live: boolean?): any?
	local templates = CostumeVisualFactory.prepare(outfitId)
	if not templates then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "CostumeVisuals"
	local bodies = {}
	local destroyed = false
	for _, template in templates do
		local clone = template:Clone()
		clone.Parent = folder
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				local mount = part:WaitForChild("BodyMount") :: Attachment
				part.Anchored = true
				part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
				part.Massless = true
				local weld = if live then Instance.new("WeldConstraint") else nil
				if weld then
					weld.Name, weld.Part1, weld.Parent = "CostumeMount", part, part
				end
				local targetName = part:GetAttribute("BodyPart")
				local body = bodies[targetName]
				if not body then
					body = { name = targetName, mounts = {} }
					bodies[targetName] = body
				end
				body.covered = body.covered or part:GetAttribute("CoversBody") == true
				table.insert(body.mounts, {
					part = part,
					mount = mount,
					size = part.Size,
					bodySize = part:GetAttribute("BodySize"),
					offset = mount.CFrame:Inverse(),
					weld = weld,
					transparency = part.Transparency,
				})
			end
		end
	end
	local function releaseBody(body)
		if body.connection then
			body.connection:Disconnect()
			body.connection = nil
		end
		if body.originalTransparency ~= nil then
			body.target.Transparency = body.originalTransparency
			body.originalTransparency = nil
		end
	end
	local function updateBody(body)
		if destroyed then
			return
		end
		local found = character:FindFirstChild(body.name)
		local target = if found and found:IsA("BasePart") then found else nil
		if body.target ~= target then
			releaseBody(body)
			body.target, body.size = target, nil
			if target and live then
				body.connection = target:GetPropertyChangedSignal("Size"):Connect(function()
					updateBody(body)
				end)
			end
		end
		local resized = target and target.Size ~= body.size
		for _, entry in body.mounts do
			if target then
				if resized then
					local scale = target.Size / entry.bodySize
					local rotation = entry.offset.Rotation
					local partScale = Vector3.new(
						(rotation.XVector * scale).Magnitude,
						(rotation.YVector * scale).Magnitude,
						(rotation.ZVector * scale).Magnitude
					)
					if entry.weld then
						entry.weld.Part0 = nil
					end
					entry.part.Size = entry.size * partScale
					entry.scaledOffset = CFrame.new(entry.offset.Position * scale) * rotation
					entry.mount.CFrame = entry.scaledOffset:Inverse()
				end
				if entry.weld then
					if entry.weld.Part0 ~= target then
						entry.weld.Part0 = nil
						entry.part.CFrame = target.CFrame * entry.scaledOffset
						entry.part.Anchored = false
						entry.weld.Part0 = target
					end
				else
					entry.part.CFrame = target.CFrame * entry.scaledOffset
				end
				entry.part.Transparency = entry.transparency
			else
				if entry.weld then
					entry.weld.Part0 = nil
				end
				entry.part.Anchored, entry.part.Transparency = true, 1
			end
		end
		if target and body.covered then
			if body.originalTransparency == nil then
				body.originalTransparency = target.Transparency
			end
			target.Transparency = 1
		end
		body.size = if target then target.Size else nil
	end
	local function update()
		for _, body in bodies do
			updateBody(body)
		end
	end
	update()
	folder.Parent = character
	return {
		update = update,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			for _, body in bodies do
				releaseBody(body)
			end
			folder:Destroy()
		end,
		root = folder,
	}
end

return CostumeVisualFactory
