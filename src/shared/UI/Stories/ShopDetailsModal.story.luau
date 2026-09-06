--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Fixtures = require(script.Parent.EconomyFixtures)
local mount = require(script.Parent.StoryRoot)

local ShopDetailsModal = require(script.Parent.Parent.Components.ShopDetailsModal)
return function(target: Instance)
	local model = Fixtures.build(target:GetAttribute("PreviewState"))
	return mount(
		target,
		React.createElement(ShopDetailsModal, {
			Card = model.byId[target:GetAttribute("CardId") or "Crate:EffectsCrate"],
			OnClose = function() end,
			OnPurchaseBonks = function() end,
			OnPurchaseRobux = function() end,
		})
	)
end
