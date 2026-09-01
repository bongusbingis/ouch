-- Name: PlayerHighlights.luau
-- Author: Jack C.
-- Description: Applies and clears the team and teammate outline highlights on other players' characters as they spawn, change team, and leave.
-- Created: 2026-08-18

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI"))

local PlayerHighlights = {}

local config = UI.PlayerHighlight

local started = false
local highlights: { [Player]: Highlight } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}

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
			apply(player, character)
		end),
		player.CharacterRemoving:Connect(function()
			clear(player)
		end),
	}
	local character = player.Character
	if character then
		apply(player, character)
	end
end

function PlayerHighlights.start()
	if started then
		return
	end
	started = true

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
end

return PlayerHighlights
