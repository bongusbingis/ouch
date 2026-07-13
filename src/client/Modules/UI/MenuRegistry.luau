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
}

return MenuRegistry
