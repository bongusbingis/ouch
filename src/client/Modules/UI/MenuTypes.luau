--!strict

export type MenuId = "Quests" | "Shop" | "BattlePass" | "Inventory" | "Leaderboard" | "Settings"

export type ColorValue = {
	r: number,
	g: number,
	b: number,
}

export type CloseReason = "Api" | "Escape" | "Toggle" | "Switch" | "Startup" | "MissingView"

export type MenuState = {
	current: MenuId?,
	started: boolean,
}

export type MenuDefinition = {
	id: MenuId,
	viewName: string,
	label: string?,
	color: ColorValue?,
	sidebarOrder: number?,
	showInSidebar: boolean?,
	onOpen: ((view: GuiObject) -> ())?,
	onClose: ((view: GuiObject, reason: CloseReason) -> ())?,
}

export type ChangedCallback = (newMenu: MenuId?, oldMenu: MenuId?, reason: CloseReason?) -> ()
export type Disconnect = () -> ()

return {}
