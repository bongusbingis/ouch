--!strict

local MenuTypes = require(script.Parent.MenuTypes)

type MenuId = MenuTypes.MenuId
type MenuDefinition = MenuTypes.MenuDefinition

local MenuRegistry: { [MenuId]: MenuDefinition } = {
	Quests = {
		id = "Quests",
		viewName = "Quests",
		label = "Quests",
		color = { r = 0.22, g = 0.44, b = 0.95 },
		sidebarOrder = 10,
	},
	Shop = {
		id = "Shop",
		viewName = "Shop",
		label = "Shop",
		sidebarOrder = 20,
		prototype = true,
	},
	Inventory = {
		id = "Inventory",
		viewName = "Inventory",
		label = "Inventory",
		sidebarOrder = 30,
		prototype = true,
	},
}

return MenuRegistry
