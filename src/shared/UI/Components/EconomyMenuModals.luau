-- Name: EconomyMenuModals.luau
-- Author: Jack C.
-- Description: Renders the shop and crate modals for whichever economy interaction is currently open, driven by the shared menu controller.
-- Created: 2026-08-24

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = script.Parent.Parent
local ControllerModule = require(UI:WaitForChild("Hooks"):WaitForChild("EconomyMenuController"))
local CrateRevealModal = require(script.Parent:WaitForChild("CrateRevealModal"))
local ShopDetailsModal = require(script.Parent:WaitForChild("ShopDetailsModal"))

local c = React.createElement

export type Props = {
	Controller: ControllerModule.Controller,
	FocusEnabled: boolean?,
}

return function(props: Props)
	local controller = props.Controller
	return c(React.Fragment, nil, {
		ShopDetails = c(ShopDetailsModal, {
			Card = controller.selectedShopCard,
			FocusEnabled = props.FocusEnabled ~= false and controller.crateReveal == nil,
			OnClose = controller.closeSelectedShopCard,
			OnPurchaseBonks = controller.purchaseSelectedBonks,
			OnPurchaseRobux = controller.purchaseSelectedRobux,
		}),
		CrateReveal = c(CrateRevealModal, {
			Reveal = controller.crateReveal,
			FocusEnabled = props.FocusEnabled,
			OnClose = controller.closeReveal,
			OnOpenAgain = if controller.crateReplay then controller.openAgain else nil,
			OpenAgainEnabled = controller.crateReplay ~= nil and controller.crateReplay.affordable,
			OpenAgainText = if controller.crateReplay then controller.crateReplay.label else nil,
		}),
	})
end
