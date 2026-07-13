--!strict

export type ColorValue = {
	r: number,
	g: number,
	b: number,
}

export type Cleanup = RBXScriptConnection | Instance | (() -> ()) | any

export type ElementHandle = {
	instance: GuiObject?,
	add: (self: ElementHandle, cleanup: Cleanup) -> Cleanup,
	destroy: (self: ElementHandle) -> (),
	isDestroyed: (self: ElementHandle) -> boolean,
}

export type TweenSpec = {
	Time: number,
	EasingStyle: any?,
	EasingDirection: any?,
}

export type ButtonProps = {
	text: string,
	name: string?,
	color: ColorValue?,
	selectedColor: ColorValue?,
	layoutOrder: number?,
	selected: boolean?,
	activated: (() -> ())?,
}

export type ButtonHandle = ElementHandle & {
	instance: ImageButton,
	setSelected: (self: ButtonHandle, selected: boolean) -> (),
	setEnabled: (self: ButtonHandle, enabled: boolean) -> (),
}

return {}
