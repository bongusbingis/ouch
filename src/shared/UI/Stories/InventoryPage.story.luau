-- Description: Studio story previewing the locker page with fixture inventory data.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local InventoryPage = require(script.Parent.Parent.Components.InventoryPage)
local InventoryModel = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("InventoryModel")
)
local GamePasses = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("GamePasses"))
local mount = require(script.Parent.StoryRoot)

local function Story()
	local selectedTab, setSelectedTab = React.useState("EMOTES")
	local data, setData = React.useState(function()
		local owned = {}
		for _, itemId in GamePasses.Catalog.Showtime.EntitlementItemIds do
			owned[itemId] = true
		end
		return { Bonks = 0, Cosmetics = { Owned = owned, Equipped = {} } }
	end)
	return React.createElement(InventoryPage, {
		Data = data,
		SelectedTab = selectedTab,
		OnTabChanged = setSelectedTab,
		OnEquip = function(entry)
			local equipped = table.clone(data.Cosmetics.Equipped)
			equipped[entry.category] = InventoryModel.nextEquip(entry, equipped)
			setData({ Bonks = data.Bonks, Cosmetics = { Owned = data.Cosmetics.Owned, Equipped = equipped } })
		end,
	})
end

return function(target: Instance)
	return mount(target, React.createElement(Story))
end
