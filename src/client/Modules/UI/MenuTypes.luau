--!strict

export type MenuId = "Shop" | "Inventory"

export type CloseReason = "Api" | "Escape" | "Toggle" | "Switch" | "Startup" | "MissingView"

export type MenuState = {
	current: MenuId?,
	started: boolean,
}

export type MenuDefinition = {
	id: MenuId,
	viewName: string,
	onOpen: ((view: GuiObject) -> ())?,
	onClose: ((view: GuiObject, reason: CloseReason) -> ())?,
}

export type ChangedCallback = (newMenu: MenuId?, oldMenu: MenuId?, reason: CloseReason?) -> ()
export type Disconnect = () -> ()

return {}
