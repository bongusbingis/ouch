--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local CrateRevealModal = require(script.Parent.Parent.Components.CrateRevealModal)
local mount = require(script.Parent.StoryRoot)

local Fixtures = require(script.Parent.EconomyFixtures)
local model = Fixtures.build("Ready")
local RESULTS = {}
local totalRefund = 0
for index, outcome in model.byId["Crate:EffectsCrate"].odds do
	local result = table.clone(outcome)
	result.isDupe = index % 4 == 0
	result.bonksRefund = if result.isDupe then outcome.bonksRefund else 0
	totalRefund += result.bonksRefund
	table.insert(RESULTS, result)
end

return function(target: Instance)
	return mount(
		target,
		React.createElement(CrateRevealModal, {
			Reveal = {
				results = RESULTS,
				totalRefund = totalRefund,
			},
			OnClose = function() end,
		})
	)
end
