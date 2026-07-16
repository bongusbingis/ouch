--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapFeatures = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MapFeatures"))
local MovementSpeedService = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Adapters")
		:WaitForChild("MovementSpeedService")
)

-- Applies the active map's terrain features server-side: bounce pads launch
-- along their UpVector (same server-set velocity pattern as hammer knockback,
-- which predicts cleanly), foam pits slow movement while a character's root
-- is inside the pit volume (via MovementSpeedService, which owns WalkSpeed).

local MapFeatureService = {}

local bouncePads: { BasePart } = {}
local foamPits: { BasePart } = {}
local padCooldowns: { [Player]: { [BasePart]: number } } = {}
local slowed: { [Player]: boolean } = {}
local connection: RBXScriptConnection? = nil

local function rootInPart(root: BasePart, part: BasePart): boolean
	local offset = part.CFrame:PointToObjectSpace(root.Position)
	local half = part.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y + 2 and math.abs(offset.Z) <= half.Z
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil or character:GetAttribute("CombatAlive") == false then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function stepPads(player: Player, root: BasePart, now: number)
	local cooldowns = padCooldowns[player]
	if cooldowns == nil then
		cooldowns = {}
		padCooldowns[player] = cooldowns
	end
	for _, pad in bouncePads do
		if not rootInPart(root, pad) then
			continue
		end
		if now < (cooldowns[pad] or 0) then
			continue
		end
		cooldowns[pad] = now + MapFeatures.BouncePad.CooldownSeconds

		local speed = (pad:GetAttribute("LaunchSpeed") :: number?) or MapFeatures.BouncePad.LaunchSpeed
		root.AssemblyLinearVelocity = pad.CFrame.UpVector * speed
	end
end

local function stepPits(player: Player, root: BasePart)
	local inPit = false
	for _, pit in foamPits do
		if rootInPart(root, pit) then
			inPit = true
			break
		end
	end

	if inPit and not slowed[player] then
		slowed[player] = true
		MovementSpeedService.setModifier(player, "foamPit", MapFeatures.FoamPit.WalkSpeedScale)
	elseif not inPit and slowed[player] then
		slowed[player] = nil
		MovementSpeedService.clearModifier(player, "foamPit")
	end
end

local function restoreSlowed()
	for player in slowed do
		MovementSpeedService.clearModifier(player, "foamPit")
	end
	table.clear(slowed)
end

function MapFeatureService.bind(pads: { BasePart }, pits: { BasePart })
	MapFeatureService.unbind()
	bouncePads = pads
	foamPits = pits
	if #pads == 0 and #pits == 0 then
		return
	end

	connection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local root = aliveRoot(player)
			if root == nil then
				continue
			end
			stepPads(player, root, now)
			stepPits(player, root)
		end
	end)
end

function MapFeatureService.unbind()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	restoreSlowed()
	table.clear(padCooldowns)
	bouncePads = {}
	foamPits = {}
end

function MapFeatureService.start()
	Players.PlayerRemoving:Connect(function(player)
		padCooldowns[player] = nil
		slowed[player] = nil
		MovementSpeedService.forget(player)
	end)
end

return MapFeatureService
