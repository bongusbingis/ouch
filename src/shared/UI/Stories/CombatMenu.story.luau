--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Fixtures = require(script.Parent.EconomyFixtures)
local mount = require(script.Parent.StoryRoot)

local CombatMenu = require(script.Parent.Parent.Components.CombatMenu)
return function(target: Instance)
	local _, snapshot = Fixtures.build(target:GetAttribute("PreviewState"))
	return mount(
		target,
		React.createElement(CombatMenu, {
			Available = true,
			Place = target:GetAttribute("Place") or "Arena",
			ShopClient = Fixtures.client(snapshot),
		})
	)
end
