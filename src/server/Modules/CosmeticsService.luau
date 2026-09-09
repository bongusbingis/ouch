-- Description: The only writer of profile cosmetics: grants and equips items after validating ownership and slot, and projects each equip onto a player attribute so every client can render other players' looks.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Emotes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Emotes"))
local GamePasses = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("GamePasses"))
local Debug = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Debug"))
local AnalyticsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Analytics"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local CosmeticsLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CosmeticsLogic")
)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)
local EntitlementService = require(script.Parent.EntitlementService)

local CosmeticsService = {}

local lastPlayAt: { [number]: number } = {}

local function emoteCapacity(player: Player): number
	local capacity = Emotes.BaseSlots
	for key, definition in GamePasses.Catalog do
		if definition.EmoteSlots ~= nil and definition.Id ~= nil and EntitlementService.has(player, key) then
			capacity = math.max(capacity, definition.EmoteSlots)
		end
	end
	return math.min(capacity, Emotes.MaxSlots)
end

local function applyEquipAttributes(player: Player)
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	for slot in Cosmetics.Slots do
		player:SetAttribute(`Equip_{slot}`, data.Cosmetics.Equipped[slot] or "")
	end
	for i = 1, Emotes.MaxSlots do
		player:SetAttribute(`EmoteSlot_{i}`, data.Cosmetics.EmoteSlots[i] or "")
	end
	player:SetAttribute("EmoteSlotCapacity", emoteCapacity(player))
end

-- Pass ownership resolves asynchronously after the profile loads, so the
-- wheel capacity is re-published whenever entitlements change.
function CosmeticsService.refreshEquipAttributes(player: Player)
	applyEquipAttributes(player)
end

function CosmeticsService.grant(player: Player, itemId: string): (boolean, string?)
	local data = PlayerData.get(player)
	if data == nil then
		return false, "no_profile"
	end
	local grantIds = CosmeticsLogic.grantIds(Cosmetics.Items, itemId)
	if grantIds == nil then
		return false, "unknown_item"
	end
	if CosmeticsLogic.isOwned(Cosmetics.Items, data.Cosmetics.Owned, itemId) then
		return false, "already_owned"
	end
	for _, atomicId in grantIds do
		data.Cosmetics.Owned[atomicId] = true
	end
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

function CosmeticsService.setEmoteSlot(player: Player, slotIndex: number, itemId: string?): (boolean, string?)
	local data = PlayerData.get(player)
	if data == nil then
		return false, "no_profile"
	end
	local capacity = emoteCapacity(player)
	if slotIndex % 1 ~= 0 or slotIndex < 1 or slotIndex > capacity then
		return false, "bad_slot"
	end
	if itemId ~= nil then
		local item = Cosmetics.Items[itemId]
		if item == nil then
			return false, "unknown_item"
		end
		if item.Category ~= "EmoteAssets" then
			return false, "not_emote"
		end
		if not CosmeticsLogic.isOwned(Cosmetics.Items, data.Cosmetics.Owned, itemId) then
			return false, "not_owned"
		end
		for index = 1, Emotes.MaxSlots do
			if data.Cosmetics.EmoteSlots[index] == itemId and index ~= slotIndex then
				data.Cosmetics.EmoteSlots[index] = ""
			end
		end
	end
	data.Cosmetics.EmoteSlots[slotIndex] = itemId or ""
	applyEquipAttributes(player)
	return true
end

function CosmeticsService.grantAllForAdmin(player: Player): number
	local granted = 0
	for itemId in Cosmetics.Items do
		if CosmeticsService.grant(player, itemId) then
			granted += 1
		end
	end
	return granted
end

function CosmeticsService.revokeForAdmin(player: Player, itemId: string): (boolean, string?)
	local data = PlayerData.get(player)
	local item = Cosmetics.Items[itemId]
	if data == nil then
		return false, "no_profile"
	end
	if item == nil then
		return false, "unknown_item"
	end
	local grantIds = CosmeticsLogic.grantIds(Cosmetics.Items, itemId) :: { string }
	local hasAny = false
	for _, atomicId in grantIds do
		hasAny = hasAny or data.Cosmetics.Owned[atomicId] == true
	end
	if not hasAny then
		return false, "not_owned"
	end

	for _, atomicId in grantIds do
		data.Cosmetics.Owned[atomicId] = nil
	end
	local equippedId = data.Cosmetics.Equipped[item.Category]
	if equippedId and not CosmeticsLogic.isOwned(Cosmetics.Items, data.Cosmetics.Owned, equippedId) then
		CosmeticsService.equip(player, item.Category, nil)
	end
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
			CosmeticsService.grantAllForAdmin(player)
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

	Network.handleProtected("SetEmoteSlot", {
		rateLimit = 5,
		validate = function(_player, slotIndex, itemId)
			return type(slotIndex) == "number" and slotIndex % 1 == 0 and (itemId == nil or type(itemId) == "string")
		end,
	}, function(player, slotIndex, itemId)
		return CosmeticsService.setEmoteSlot(player, slotIndex, itemId)
	end)

	Network.handleProtected("PlayEmote", {
		rateLimit = 2,
		validate = function(_player, emoteId)
			return type(emoteId) == "string"
		end,
	}, function(player, emoteId)
		local data = PlayerData.get(player)
		if data == nil then
			return false, "no_profile"
		end
		local slotted = false
		for i = 1, emoteCapacity(player) do
			if data.Cosmetics.EmoteSlots[i] == emoteId then
				slotted = true
				break
			end
		end
		if not slotted then
			return false, "not_equipped"
		end
		local last = lastPlayAt[player.UserId]
		if last ~= nil and os.clock() - last < Emotes.MinReplaySeconds then
			return false, "too_soon"
		end
		lastPlayAt[player.UserId] = os.clock()
		Network.fire("EmotePlayed", nil, player.UserId, emoteId)
		return true
	end)

	Players.PlayerAdded:Connect(onProfileReady)
	Players.PlayerRemoving:Connect(function(player)
		lastPlayAt[player.UserId] = nil
	end)
	for _, player in Players:GetPlayers() do
		onProfileReady(player)
	end
end

return CosmeticsService
