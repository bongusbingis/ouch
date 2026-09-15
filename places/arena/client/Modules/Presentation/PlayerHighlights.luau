-- Description: Applies and clears the team and teammate outline highlights on other players' characters as they spawn, change team, and leave.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("GameModes"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))

local PlayerHighlights = {}

local config = UI.PlayerHighlight

local started = false
local highlights: { [Player]: Highlight } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local matchState: Folder? = nil
local matchStateConnection: RBXScriptConnection? = nil
local matchStateChildAdded: RBXScriptConnection? = nil
local combatMode = true

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
	clear(player)
	local playerConnections = connections[player]
	if playerConnections then
		for _, connection in playerConnections do
			connection:Disconnect()
		end
		connections[player] = nil
	end
end

local function watch(player: Player)
	if player == Players.LocalPlayer then
		return
	end
	connections[player] = {
		player.CharacterAdded:Connect(function(character)
			if combatMode then
				apply(player, character)
			end
		end),
		player.CharacterRemoving:Connect(function()
			clear(player)
		end),
	}
	local character = player.Character
	if character and combatMode then
		apply(player, character)
	end
end

-- Splashdown and any other non-combat mode has no enemies to spot, so the
-- enemy outline goes fully dark rather than tinting a race with combat UI.
local function refreshHighlights()
	if combatMode then
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if player ~= Players.LocalPlayer and character then
				apply(player, character)
			end
		end
	else
		for player in highlights do
			clear(player)
		end
	end
end

local function updateCombatMode()
	local modeId = if matchState then matchState:GetAttribute("modeId") else nil
	local nextCombatMode = GameModes.IsCombat(modeId)
	if nextCombatMode == combatMode then
		return
	end
	combatMode = nextCombatMode
	refreshHighlights()
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

	local existingMatchState = ReplicatedStorage:FindFirstChild("MatchState")
	if existingMatchState and existingMatchState:IsA("Folder") then
		attachMatchState(existingMatchState)
	end
	matchStateChildAdded = ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "MatchState" and child:IsA("Folder") then
			attachMatchState(child)
		end
	end)

	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(forget)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

function PlayerHighlights.destroy()
	for player in connections do
		forget(player)
	end
	for player in highlights do
		clear(player)
	end
	if matchStateConnection then
		matchStateConnection:Disconnect()
		matchStateConnection = nil
	end
	if matchStateChildAdded then
		matchStateChildAdded:Disconnect()
		matchStateChildAdded = nil
	end
	matchState = nil
end

return PlayerHighlights
