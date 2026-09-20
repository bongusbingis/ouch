-- Description: Applies and clears the team and teammate outline highlights on other players' characters as they spawn, change team, and leave.
-- Viewport and distance culling is managed via VisibilityCuller, rendering highlights only when the character is inside the player's view, with a capacity fallback.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("GameModes"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local VisibilityCuller = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Util"):WaitForChild("VisibilityCuller")
)

local PlayerHighlights = {}

local config = UI.PlayerHighlight

local started = false
local highlights: { [Player]: Highlight } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local playerLifecycleConnections: { RBXScriptConnection } = {}
local matchState: Folder? = nil
local matchStateConnection: RBXScriptConnection? = nil
local matchStateChildAdded: RBXScriptConnection? = nil
local combatMode = true

local culler: VisibilityCuller.Group? = nil

local function clear(player: Player)
	local highlight = highlights[player]
	if highlight then
		highlight:Destroy()
		highlights[player] = nil
	end
end

local function apply(player: Player, character: Model)
	clear(player)
	local highlight = Instance.new("Highlight")
	highlight.Name = "PlayerHighlight"
	highlight.FillColor = config.FillColor
	highlight.OutlineColor = config.OutlineColor
	highlight.FillTransparency = config.FillTransparency
	highlight.OutlineTransparency = config.OutlineTransparency
	highlight.DepthMode = config.DepthMode
	highlight.Adornee = character
	highlight.Parent = character
	highlights[player] = highlight
end

local function forget(player: Player)
	if culler then
		culler.untrack(player)
	end
	clear(player)
	local playerConnections = connections[player]
	if playerConnections then
		for _, connection in playerConnections do
			connection:Disconnect()
		end
		connections[player] = nil
	end
end

local function trackCharacter(player: Player, character: Model)
	if culler == nil then
		return
	end
	culler.track(player, {
		target = character,
		onVisible = function()
			if combatMode then
				apply(player, character)
			end
		end,
		onHidden = function()
			clear(player)
		end,
	})
end

local function watch(player: Player)
	if player == Players.LocalPlayer then
		return
	end
	connections[player] = {
		player.CharacterAdded:Connect(function(character)
			trackCharacter(player, character)
		end),
		player.CharacterRemoving:Connect(function()
			if culler then
				culler.untrack(player)
			end
			clear(player)
		end),
	}
	local character = player.Character
	if character then
		trackCharacter(player, character)
	end
end

local function updateCombatMode()
	local modeId = if matchState then matchState:GetAttribute("modeId") else nil
	local nextCombatMode = GameModes.IsCombat(modeId)
	if nextCombatMode == combatMode then
		return
	end
	combatMode = nextCombatMode

	if not combatMode then
		for player in highlights do
			clear(player)
		end
	elseif culler then
		for _, player in Players:GetPlayers() do
			if player ~= Players.LocalPlayer and culler.isTargetVisible(player) and player.Character then
				apply(player, player.Character)
			end
		end
	end
end

local function attachMatchState(folder: Folder)
	if matchStateConnection then
		matchStateConnection:Disconnect()
	end
	matchState = folder
	matchStateConnection = folder:GetAttributeChangedSignal("modeId"):Connect(updateCombatMode)
	updateCombatMode()
end

function PlayerHighlights.start()
	if started then
		return
	end
	started = true

	culler = VisibilityCuller.createGroup({
		activateDistance = 160,
		deactivateDistance = 185,
		viewportMarginPx = 48,
		maxVisible = 20, -- Fallback hard limit, safely under Roblox engine's 31-limit
		checkHz = 10,
	})

	local existingMatchState = ReplicatedStorage:FindFirstChild("MatchState")
	if existingMatchState and existingMatchState:IsA("Folder") then
		attachMatchState(existingMatchState)
	end
	matchStateChildAdded = ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "MatchState" and child:IsA("Folder") then
			attachMatchState(child)
		end
	end)

	table.insert(playerLifecycleConnections, Players.PlayerAdded:Connect(watch))
	table.insert(playerLifecycleConnections, Players.PlayerRemoving:Connect(forget))
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

function PlayerHighlights.destroy()
	if culler then
		culler.destroy()
		culler = nil
	end
	for player in connections do
		forget(player)
	end
	for player in highlights do
		clear(player)
	end
	for _, conn in playerLifecycleConnections do
		conn:Disconnect()
	end
	table.clear(playerLifecycleConnections)
	if matchStateConnection then
		matchStateConnection:Disconnect()
		matchStateConnection = nil
	end
	if matchStateChildAdded then
		matchStateChildAdded:Disconnect()
		matchStateChildAdded = nil
	end
	matchState = nil
	started = false
end

return PlayerHighlights
