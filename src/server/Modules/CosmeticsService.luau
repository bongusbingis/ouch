--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Debug = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Debug"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local CosmeticsLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CosmeticsLogic")
)
local PlayerData = require(script.Parent.PlayerData)

-- The only writer of profile Cosmetics.*. The profile is the source of truth
-- (replicated to the owning client via Replica); Equip_<Slot> player
-- attributes are a read-only projection so every client can render other
-- players' equips.
--
-- TODO(ui): the locker reads own inventory from the GameProfile replica and
-- calls the EquipCosmetic remote; other-player displays read the attributes.

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

function CosmeticsService.grant(player: Player, itemId: string): boolean
	local data = PlayerData.get(player)
	if data == nil or Cosmetics.Items[itemId] == nil then
		return false
	end
	if data.Cosmetics.Owned[itemId] == true then
		return false
	end
	data.Cosmetics.Owned[itemId] = true
	return true
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
	return true
end

local function grantAllForTesting(player: Player)
	for itemId in Cosmetics.Items do
		CosmeticsService.grant(player, itemId)
	end
end

local function onProfileReady(player: Player)
	task.spawn(function()
		while player.Parent ~= nil and PlayerData.get(player) == nil do
			task.wait(0.2)
		end
		if player.Parent == nil then
			return
		end
		if Debug.CosmeticsGrantAll and RunService:IsStudio() then
			grantAllForTesting(player)
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
