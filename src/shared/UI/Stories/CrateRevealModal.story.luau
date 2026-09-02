--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local CrateRevealModal = require(script.Parent.Parent.Components.CrateRevealModal)
local mount = require(script.Parent.StoryRoot)

local RESULTS = {}
for index = 1, 10 do
	table.insert(RESULTS, {
		displayName = if index == 10 then "Legendary Hammer" else `Reward {index}`,
		rarity = if index == 10 then "Legendary" else if index % 3 == 0 then "Rare" else "Common",
		isDupe = index % 4 == 0,
		bonksRefund = if index % 4 == 0 then 100 else 0,
	})
end

return function(target: Instance)
	return mount(
		target,
		React.createElement(CrateRevealModal, {
			Reveal = {
				results = RESULTS,
				totalRefund = 200,
			},
			OnClose = function() end,
		})
	)
end
