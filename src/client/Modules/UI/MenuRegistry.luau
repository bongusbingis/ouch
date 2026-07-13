--!strict

local MenuTypes = require(script.Parent.MenuTypes)

type MenuId = MenuTypes.MenuId
type MenuDefinition = MenuTypes.MenuDefinition

local MenuRegistry: { [MenuId]: MenuDefinition } = {
	Shop = {
		id = "Shop",
		viewName = "Shop",
	},
	Inventory = {
		id = "Inventory",
		viewName = "Inventory",
	},
}

return MenuRegistry
