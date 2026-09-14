-- Description: Renders the shop and crate modals for whichever economy interaction is currently open, driven by the shared menu controller.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = script.Parent.Parent
local ControllerModule = require(UI:WaitForChild("Hooks"):WaitForChild("EconomyMenuController"))
local CrateRevealModal = require(script.Parent:WaitForChild("CrateRevealModal"))
local ShopDetailsModal = require(script.Parent:WaitForChild("ShopDetailsModal"))
local EffectPreviewScene = require(script.Parent:WaitForChild("EffectPreviewScene"))
local PreviewClient = require(UI.Services.CosmeticPreviewClient)
local useExternalStore = require(UI.Hooks.useExternalStore)

local c = React.createElement

export type Props = {
	Controller: ControllerModule.Controller,
	FocusEnabled: boolean?,
}

return function(props: Props)
	local controller = props.Controller
	local preview = useExternalStore(PreviewClient.getSnapshot, PreviewClient.subscribe)
	return c(React.Fragment, nil, {
		EffectPreview = c(EffectPreviewScene, {
			Enabled = controller.previewItem ~= nil and props.FocusEnabled ~= false,
			ItemId = if controller.previewItem then controller.previewItem.itemId else nil,
			Category = if controller.previewItem then controller.previewItem.category else nil,
			OnClose = controller.closePreview,
		}),
		ShopDetails = c(ShopDetailsModal, {
			Visible = controller.crateReveal == nil or controller.inspectingReward,
			Card = controller.selectedShopCard,
			BackRef = controller.detailsBackRef,
			FocusEnabled = props.FocusEnabled ~= false
				and (controller.crateReveal == nil or controller.inspectingReward)
				and not preview.active,
			OnPreviewEffect = controller.previewEffect,
			OnEquipItem = controller.equipPreview,
			OnViewInventory = controller.viewInventory,
			Owned = if controller.economyData then controller.economyData.Cosmetics.Owned else {},
			Equipped = if controller.economyData then controller.economyData.Cosmetics.Equipped else {},
			BusySlots = controller.busySlots,
			SeasonState = controller.seasonState,
			OnClaimSeason = controller.claimSeason,
			ClaimPending = controller.claimPending,
			OnClose = controller.closeSelectedShopCard,
			OnPurchaseBonks = controller.purchaseSelectedBonks,
			OnPurchaseRobux = controller.purchaseSelectedRobux,
		}),
		CrateReveal = c(CrateRevealModal, {
			Reveal = controller.crateReveal,
			Visible = not controller.inspectingReward,
			FocusEnabled = props.FocusEnabled ~= false and not preview.active and not controller.inspectingReward,
			Owned = if controller.economyData then controller.economyData.Cosmetics.Owned else {},
			Equipped = if controller.economyData then controller.economyData.Cosmetics.Equipped else {},
			BusySlots = controller.busySlots,
			OnEquipItem = controller.equipPreview,
			OnInspectItem = controller.inspectReward,
			OnViewInventory = controller.viewInventory,
			OnClose = controller.closeReveal,
			OnOpenAgain = if controller.crateReplay then controller.openAgain else nil,
			OpenAgainEnabled = controller.crateReplay ~= nil and controller.crateReplay.affordable,
			OpenAgainText = if controller.crateReplay then controller.crateReplay.label else nil,
			OpenAgainCount = if controller.crateReplay then controller.crateReplay.count else nil,
			OpenAgainBonks = if controller.crateReplay then controller.crateReplay.total else nil,
		}),
	})
end
