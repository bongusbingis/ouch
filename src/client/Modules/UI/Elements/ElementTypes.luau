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

export type RewardPayload = {
	kind: string,
	amount: number?,
	itemId: string?,
}

export type QuestCardData = {
	slot: number,
	questId: string,
	title: string,
	progress: number,
	goal: number,
	steps: number,
	claimed: boolean,
	completed: boolean,
	reward: RewardPayload,
}

export type QuestCardProps = {
	data: QuestCardData,
	claim: ((questId: string) -> ())?,
}

export type QuestCardHandle = ElementHandle & {
	instance: GuiObject,
	setData: (self: QuestCardHandle, data: QuestCardData) -> (),
}

return {}
