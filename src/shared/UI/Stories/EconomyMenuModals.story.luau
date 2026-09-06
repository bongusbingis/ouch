--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Fixtures = require(script.Parent.EconomyFixtures)
local mount = require(script.Parent.StoryRoot)

local EconomyMenuModals = require(script.Parent.Parent.Components.EconomyMenuModals)
local function Story(props)
	local selected, setSelected = React.useState(props.Card)
	local reveal, setReveal = React.useState(nil)
	local function open()
		local outcome = props.Card.odds[1]
		setReveal({ results = { outcome }, totalRefund = 0 })
	end
	return React.createElement(EconomyMenuModals, {
		Controller = {
			selectedShopCard = selected,
			crateReveal = reveal,
			closeSelectedShopCard = function()
				setSelected(nil)
			end,
			closeReveal = function()
				setReveal(nil)
			end,
			purchaseSelectedBonks = open,
			purchaseSelectedRobux = function() end,
		},
	})
end
return function(target: Instance)
	local model = Fixtures.build(target:GetAttribute("PreviewState"))
	return mount(target, React.createElement(Story, { Card = model.byId["Crate:EffectsCrate"] }))
end
