-- Name: CharacterColorService.luau
-- Author: Jack C.
-- Description: Applies each player's equipped character color to their character's parts on spawn and whenever the equip changes.
-- Created: 2026-08-17

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local CharacterColorLogic = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Economy")
		:WaitForChild("CharacterColorLogic")
)

local CharacterColorService = {}

local ATTRIBUTE_NAME = "Equip_CharacterColor"

type PlayerBinding = {
	characterAdded: RBXScriptConnection,
	appearanceLoaded: RBXScriptConnection,
	colorChanged: RBXScriptConnection,
	descendantAdded: RBXScriptConnection?,
}

local started = false
local bindings: { [Player]: PlayerBinding } = {}

local function equippedColor(player: Player): Color3
	return CharacterColorLogic.resolve(Cosmetics, player:GetAttribute(ATTRIBUTE_NAME))
end

local function colorMeshPart(instance: Instance, color: Color3)
	if instance:IsA("MeshPart") then
		instance.Color = color
	end
end

local function applyCharacter(player: Player, character: Model)
	local binding = bindings[player]
	if binding == nil then
		return
	end
	if binding.descendantAdded ~= nil then
		binding.descendantAdded:Disconnect()
	end

	local color = equippedColor(player)
	for _, descendant in character:GetDescendants() do
		colorMeshPart(descendant, color)
	end

	binding.descendantAdded = character.DescendantAdded:Connect(function(descendant)
		if player.Character == character then
			colorMeshPart(descendant, equippedColor(player))
		end
	end)
end

local function bindPlayer(player: Player)
	if bindings[player] ~= nil then
		return
	end

	local binding: PlayerBinding
	binding = {
		characterAdded = player.CharacterAdded:Connect(function(character)
			applyCharacter(player, character)
		end),
		appearanceLoaded = player.CharacterAppearanceLoaded:Connect(function(character)
			if player.Character == character then
				applyCharacter(player, character)
			end
		end),
		colorChanged = player:GetAttributeChangedSignal(ATTRIBUTE_NAME):Connect(function()
			local character = player.Character
			if character ~= nil then
				applyCharacter(player, character)
			end
		end),
		descendantAdded = nil,
	}
	bindings[player] = binding

	local character = player.Character
	if character ~= nil then
		applyCharacter(player, character)
	end
end

local function unbindPlayer(player: Player)
	local binding = bindings[player]
	if binding == nil then
		return
	end
	binding.characterAdded:Disconnect()
	binding.appearanceLoaded:Disconnect()
	binding.colorChanged:Disconnect()
	if binding.descendantAdded ~= nil then
		binding.descendantAdded:Disconnect()
	end
	bindings[player] = nil
end

function CharacterColorService.start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(unbindPlayer)
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
end

return CharacterColorService
