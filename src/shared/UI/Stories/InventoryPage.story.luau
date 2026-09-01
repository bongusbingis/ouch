-- Name: InventoryPage.story.luau
-- Author: Jack C.
-- Description: Studio story previewing the locker page with fixture inventory data.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local InventoryPage = require(script.Parent.Parent.Components.InventoryPage)
local mount = require(script.Parent.StoryRoot)

local function Story()
	local selectedTab, setSelectedTab = React.useState("OUTFITS")
	return React.createElement(InventoryPage, {
		Data = { Bonks = 0, Cosmetics = { Owned = {}, Equipped = {} } },
		SelectedTab = selectedTab,
		OnTabChanged = setSelectedTab,
		OnEquip = function() end,
	})
end

return function(target: Instance)
	return mount(target, React.createElement(Story))
end
