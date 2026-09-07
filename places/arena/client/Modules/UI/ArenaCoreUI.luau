-- Owns suppression of replaced Roblox gameplay UI and restores captured state on teardown.
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Config = require(ReplicatedStorage.Config.Interface.ArenaPresentation)
local ArenaCoreUI = {}
local replaced = { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack }
local previous: { [Enum.CoreGuiType]: boolean } = {}
local watched: { [Player]: any } = {}
local connections: { RBXScriptConnection } = {}
local started = false
local generation = 0

local function releaseCharacter(entry)
	if entry.characterConnection then
		entry.characterConnection:Disconnect()
		entry.characterConnection = nil
	end
	if entry.humanoid and entry.humanoid.Parent then
		entry.humanoid.DisplayDistanceType = entry.display
		entry.humanoid.HealthDisplayType = entry.health
	end
	entry.humanoid = nil
end

local function watchCharacter(entry, character: Model)
	releaseCharacter(entry)
	local function suppress(instance: Instance)
		if not instance:IsA("Humanoid") or entry.humanoid == instance then
			return
		end
		entry.humanoid = instance
		entry.display = instance.DisplayDistanceType
		entry.health = instance.HealthDisplayType
		instance.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		instance.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		suppress(humanoid)
	end
	entry.characterConnection = character.ChildAdded:Connect(suppress)
end

local function forget(player: Player)
	local entry = watched[player]
	if entry == nil then
		return
	end
	releaseCharacter(entry)
	entry.added:Disconnect()
	entry.removing:Disconnect()
	watched[player] = nil
end

local function watch(player: Player)
	if watched[player] then
		return
	end
	local entry = {}
	watched[player] = entry
	entry.added = player.CharacterAdded:Connect(function(character)
		watchCharacter(entry, character)
	end)
	entry.removing = player.CharacterRemoving:Connect(function()
		releaseCharacter(entry)
	end)
	if player.Character then
		watchCharacter(entry, player.Character)
	end
end

function ArenaCoreUI.start()
	if started then
		return
	end
	started = true
	generation += 1
	local current = generation
	task.spawn(function()
		for _ = 1, Config.CoreUI.RetryCount do
			if not started or current ~= generation then
				return
			end
			local complete = pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false)
			for _, coreType in replaced do
				local ok = pcall(function()
					if previous[coreType] == nil then
						previous[coreType] = StarterGui:GetCoreGuiEnabled(coreType)
					end
					StarterGui:SetCoreGuiEnabled(coreType, false)
				end)
				complete = complete and ok
			end
			if complete then
				return
			end
			task.wait(Config.CoreUI.RetrySeconds)
		end
		warn("[ArenaCoreUI] Roblox gameplay UI could not be disabled")
	end)
	table.insert(connections, Players.PlayerAdded:Connect(watch))
	table.insert(connections, Players.PlayerRemoving:Connect(forget))
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

function ArenaCoreUI.destroy()
	pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", true)
	started = false
	generation += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for player in watched do
		forget(player)
	end
	for coreType, enabled in previous do
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, enabled)
	end
	table.clear(previous)
end

return ArenaCoreUI
