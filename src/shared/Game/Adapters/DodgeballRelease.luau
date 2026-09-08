-- Description: Computes the world position a thrown ball is released from, resolving the configured release socket relative to the thrower.

--!strict

local DodgeballRelease = {}

local ANIMATED_PARENTS = {
	RightHand = true,
	RightLowerArm = true,
	RightUpperArm = true,
	LeftHand = true,
	LeftLowerArm = true,
	LeftUpperArm = true,
	Head = true,
	["Right Arm"] = true,
	["Left Arm"] = true,
}

local sockets: { [Model]: Attachment | false } = setmetatable({}, { __mode = "k" }) :: any

local function socket(model: Model): Attachment?
	local cached = sockets[model]
	if cached ~= nil then
		return if cached then cached else nil
	end

	local found = model:FindFirstChild("DodgeballReleaseSocket", true)
	if found == nil or not found:IsA("Attachment") then
		sockets[model] = false
		return nil
	end

	local parent = found.Parent
	if parent ~= nil and ANIMATED_PARENTS[parent.Name] then
		warn(
			`[DodgeballRelease] {found:GetFullName()} must be parented to HumanoidRootPart or a torso part; using the configured root offset`
		)
		sockets[model] = false
		return nil
	end

	sockets[model] = found
	return found
end

function DodgeballRelease.position(model: Model, root: BasePart, fallbackOffset: vector): Vector3
	local authored = socket(model)
	if authored ~= nil then
		return authored.WorldPosition
	end
	return (root.CFrame * CFrame.new(fallbackOffset.x, fallbackOffset.y, fallbackOffset.z)).Position
end

return table.freeze(DodgeballRelease)
