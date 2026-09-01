-- Name: CosmeticsService.luau
-- Author: Jack C.
-- Description: The only writer of profile cosmetics: grants and equips items after validating ownership and slot, and projects each equip onto a player attribute so every client can render other players' looks.
-- Created: 2026-07-13

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Debug = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Debug"))
local AnalyticsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Analytics"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local CosmeticsLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CosmeticsLogic")
)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)

local CosmeticsService = {}

local function applyEquipAttributes(player: Player)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	for slot in Cosmetics.Slots do
		player:SetAttribute(`Equip_{slot}`, data.Cosmetics.Equipped[slot] or "")
	end
end

function CosmeticsService.grant(player: Player, itemId: string): (boolean, string?)
	local data = PlayerData.get(player)
	if data == nil then
		return false, "no_profile"
	end
	if Cosmetics.Items[itemId] == nil then
		return false, "unknown_item"
	end
	if data.Cosmetics.Owned[itemId] == true then
		return false, "already_owned"
	end
	data.Cosmetics.Owned[itemId] = true
	return true, nil
end

function CosmeticsService.equip(player: Player, slot: string, itemId: string?): (boolean, string?)
	local data = PlayerData.get(player)
	if data == nil then
		return false, "no_profile"
	end
	local ok, reason = CosmeticsLogic.canEquip(Cosmetics.Items, Cosmetics.Slots, data.Cosmetics.Owned, slot, itemId)
	if not ok then
		return false, reason
	end
	data.Cosmetics.Equipped[slot] = itemId
	player:SetAttribute(`Equip_{slot}`, itemId or "")
	if itemId ~= nil then
		AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.CosmeticEquipped, 1, {
			itemId = itemId,
			slot = slot,
		})
	end
	return true
end

function CosmeticsService.grantAllForTesting(player: Player): number
	local granted = 0
	for itemId in Cosmetics.Items do
		if CosmeticsService.grant(player, itemId) then
			granted += 1
		end
	end
	return granted
end

function CosmeticsService.revokeForTesting(player: Player, itemId: string): (boolean, string?)
	local data = PlayerData.get(player)
	local item = Cosmetics.Items[itemId]
	if data == nil then
		return false, "no_profile"
	end
	if item == nil then
		return false, "unknown_item"
	end
	if data.Cosmetics.Owned[itemId] ~= true then
		return false, "not_owned"
	end

	if data.Cosmetics.Equipped[item.Category] == itemId then
		local ok, reason = CosmeticsService.equip(player, item.Category, nil)
		if not ok then
			return false, reason
		end
	end
	data.Cosmetics.Owned[itemId] = nil
	return true
end

local function onProfileReady(player: Player)
	task.spawn(function()
		while player.Parent ~= nil and PlayerData.get(player) == nil do
			task.wait(0.2)
		end
		if player.Parent == nil then
			return
		end
		if Debug.AutoGrantAllItemsInStudio and RunService:IsStudio() then
			CosmeticsService.grantAllForTesting(player)
		end
		applyEquipAttributes(player)
	end)
end

function CosmeticsService.start()
	Network.handleProtected("EquipCosmetic", {
		rateLimit = 5,
		validate = function(_player, slot, itemId)
			if typeof(slot) ~= "string" then
				return false, "slot must be a string"
			end
			if itemId ~= nil and typeof(itemId) ~= "string" then
				return false, "itemId must be a string or nil"
			end
			return true
		end,
	}, function(player, slot, itemId)
		return CosmeticsService.equip(player, slot, itemId)
	end)

	Players.PlayerAdded:Connect(onProfileReady)
	for _, player in Players:GetPlayers() do
		onProfileReady(player)
	end
end

return CosmeticsService
