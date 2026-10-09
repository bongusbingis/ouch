-- Description: Spawns collectible Bonks coins at the live map's Scriptables.CoinSpawns during combat matches, detects pickups server-side against character roots, and folds each coin into the player's pending match award (capped per match).

--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay")
local CoinConfig = require(Config:WaitForChild("Coins"))
local GameModes = require(Config:WaitForChild("GameModes"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local CoinRules = require(Shared:WaitForChild("Game"):WaitForChild("Coins"):WaitForChild("CoinRules"))
local ArenaService = require(script.Parent.ArenaService)
local ArenaSessionService = require(script.Parent.ArenaSessionService)

local CoinService = {}

local COIN_TAG = "Coin"
local CHECK_INTERVAL = 0.1

type Coin = { instance: Instance, spawnIndex: number, position: Vector3 }

local random = Random.new()
local started = false
local active = false
local ended = true -- MatchEnded/MatchReset set it, MatchStarted clears it, so a lingering Active phase cannot restart coins
local matchService: any = nil
local progression: any = nil
local spawns: { BasePart } = {}
local coins: { Coin } = {}
local tally: CoinRules.Tally = {}
local nextSpawnAt = 0
local container: Folder? = nil

local function buildCoin(): Instance
	local template = ServerStorage:FindFirstChild(CoinConfig.Template)
	if template and (template:IsA("BasePart") or template:IsA("Model")) then
		return template:Clone()
	end
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.4, 3, 3)
	part.Color = Color3.fromRGB(255, 200, 61)
	part.Material = Enum.Material.Neon
	return part
end

local function place(instance: Instance, position: Vector3)
	for _, part in instance:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	if instance:IsA("Model") then
		instance:PivotTo(CFrame.new(position))
	elseif instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
		instance.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	end
	instance.Name = "Coin"
end

local function clearCoins()
	for _, coin in coins do
		coin.instance:Destroy()
	end
	table.clear(coins)
end

local function readSpawns()
	table.clear(spawns)
	local ok, arena = pcall(ArenaService.get)
	local folder = if ok then arena.scriptables:FindFirstChild("CoinSpawns") else nil
	if folder == nil then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(spawns, child)
		end
	end
end

local function scheduleSpawn()
	nextSpawnAt = os.clock() + random:NextNumber(CoinConfig.RespawnMin, CoinConfig.RespawnMax)
end

local function stop()
	active = false
	clearCoins()
	table.clear(spawns)
end

local function begin()
	active = true
	table.clear(tally)
	readSpawns()
	nextSpawnAt = os.clock() + CoinConfig.FirstSpawnDelay
end

local function spawnCoin()
	local occupied = {}
	for _, coin in coins do
		occupied[coin.spawnIndex] = true
	end
	local index = CoinRules.pickSpawn(#spawns, occupied, function(count)
		return random:NextInteger(1, count)
	end)
	local spawn = if index then spawns[index] else nil
	if index == nil or spawn == nil or spawn.Parent == nil then
		return
	end
	if container == nil or container.Parent == nil then
		local folder = Instance.new("Folder")
		folder.Name = "Coins"
		folder.Parent = Workspace
		container = folder
	end
	local instance = buildCoin()
	place(instance, spawn.Position)
	CollectionService:AddTag(instance, COIN_TAG)
	instance.Parent = container
	table.insert(coins, { instance = instance, spawnIndex = index, position = spawn.Position })
end

local function candidatesFor(position: Vector3): ({ CoinRules.Candidate }, { [string]: Player })
	local candidates = {}
	local byId = {}
	for _, player in Players:GetPlayers() do
		local id = tostring(player.UserId)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			root
			and root:IsA("BasePart")
			and character:GetAttribute("CombatAlive") ~= false
			and not CoinRules.atCap(tally, id, CoinConfig.MatchCapBonks)
			and ArenaSessionService.isRoundEligible(player)
		then
			table.insert(candidates, { id = id, distance = (root.Position - position).Magnitude })
			byId[id] = player
		end
	end
	return candidates, byId
end

local function collect(coin: Coin, player: Player): boolean
	local id = tostring(player.UserId)
	local bonks = CoinRules.grant(tally, id, CoinConfig.BonksPerCoin, CoinConfig.MatchCapBonks)
	if bonks <= 0 then
		return false
	end
	-- Roll the tally back unless the award actually took the Bonks, so a failed add never eats cap room.
	local ok, added = pcall(progression.addBonks, player, bonks)
	if not ok or not added then
		tally[id] -= bonks
		if not ok then
			warn(`[CoinService] addBonks failed for {player.Name}: {added}`)
		end
		return false
	end
	Network.fire("CoinCollected", player, coin.position, bonks)
	return true
end

local function step()
	if not active then
		return
	end
	for index = #coins, 1, -1 do
		local coin = coins[index]
		local candidates, byId = candidatesFor(coin.position)
		local winner = CoinRules.collector(candidates, CoinConfig.PickupRadius)
		local player = if winner then byId[winner] else nil
		if player and collect(coin, player) then
			coin.instance:Destroy()
			table.remove(coins, index)
		end
	end
	if #spawns > 0 and #coins < CoinConfig.MaxActive and os.clock() >= nextSpawnAt then
		spawnCoin()
		scheduleSpawn()
	end
end

function CoinService.start(match: any, progressionService: any)
	if started then
		return
	end
	started = true
	matchService = match
	progression = progressionService
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_INTERVAL then
			return
		end
		elapsed = 0
		local live = not ended and matchService.phase() == "Active" and GameModes.IsCombat(matchService.activeModeId())
		if live and not active then
			begin()
		elseif not live and active then
			stop()
		end
		local ok, err = pcall(step)
		if not ok then
			warn(`[CoinService] step failed: {err}`)
		end
	end)
	matchService.onEvent(function(event)
		if event.kind == "MatchStarted" then
			ended = false
		elseif event.kind == "MatchEnded" or event.kind == "MatchReset" then
			ended = true
			stop()
		end
	end)
end

return CoinService
