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
		color = { r = 0.96, g = 0.16, b = 0.52 },
		sidebarOrder = 20,
	},
	BattlePass = {
		id = "BattlePass",
		viewName = "BattlePass",
		label = "Season",
		color = { r = 0.68, g = 0.34, b = 0.92 },
		sidebarOrder = 25,
	},
	Inventory = {
		id = "Inventory",
		viewName = "Inventory",
		label = "Inventory",
		color = { r = 0.48, g = 0.82, b = 0.12 },
		sidebarOrder = 30,
	},
	Leaderboard = {
		id = "Leaderboard",
		viewName = "Leaderboard",
		label = "Leaderboard",
		color = { r = 1, g = 0.62, b = 0.08 },
		sidebarOrder = 40,
		showInSidebar = true,
	},
	Settings = {
		id = "Settings",
		viewName = "Settings",
		label = "Settings",
		color = { r = 0.12, g = 0.68, b = 0.92 },
		sidebarOrder = 50,
		showInSidebar = true,
	},
}

return MenuRegistry
