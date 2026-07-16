--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Modules = Server:WaitForChild("Modules")
local BallService = require(Modules:WaitForChild("BallService"))
local MatchService = require(Modules:WaitForChild("MatchService"))
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))

local function sortedKeys(values: { [string]: any }): { string }
	local keys = {}
	for key in values do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function positionFor(player: Player): string
	local character = player.Character
	if character == nil then
		return "no character"
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return "no root"
	end
	local position = root.Position
	return string.format("%.1f, %.1f, %.1f", position.X, position.Y, position.Z)
end

local function combatFor(player: Player): string
	local character = player.Character
	local alive = character ~= nil and character:GetAttribute("CombatAlive") ~= false
	return `alive={alive} heldBall={BallService.hasHeldBall(player)} score={player:GetAttribute("MatchScore") or 0}`
end

local function profileFor(player: Player): (string, string)
	local data = PlayerData.get(player)
	if data == nil then
		return "profile=not loaded", "equipped=unavailable"
	end

	local progression = data.Progression
	local owned = 0
	for _ in data.Cosmetics.Owned do
		owned += 1
	end

	local equips = {}
	for _, slot in sortedKeys(Cosmetics.Slots) do
		table.insert(equips, `{slot}={data.Cosmetics.Equipped[slot] or "-"}`)
	end

	return `cash={data.Cash} xp={data.Level.Points} elims={progression.Elims} deaths={progression.Deaths} catches={progression.Catches} wins={progression.Wins} losses={progression.Losses} matches={progression.MatchesPlayed} owned={owned}`,
		`equipped: {table.concat(equips, ", ")}`
end

return function(context, target: Player?): string
	local player = target or context.Executor
	local match = MatchService.stateForTesting()
	local profile, equipped = profileFor(player)
	return table.concat({
		`{player.Name} ({player.UserId}) team={player:GetAttribute("TeamId") or "-"}`,
		`match: phase={match.phase} mode={match.modeId} map={match.mapId or "-"} time={math.floor(
			match.timeRemaining + 0.5
		)} target={match.scoreTarget}`,
		`combat: {combatFor(player)} position={positionFor(player)}`,
		`profile: {profile}`,
		equipped,
	}, "\n")
end
