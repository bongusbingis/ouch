--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Fixtures = require(script.Parent.EconomyFixtures)
local mount = require(script.Parent.StoryRoot)

local ShopPage = require(script.Parent.Parent.Components.ShopPage)
return function(target: Instance)
	local model = Fixtures.build(target:GetAttribute("PreviewState"))
	return mount(
		target,
		React.createElement(ShopPage, {
			Model = model,
			OnCardActivated = function() end,
			OnRefresh = function() end,
		})
	)
end
