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

export type MenuButtonHandle = ElementHandle & {
	instance: GuiButton,
	setSelected: (self: MenuButtonHandle, selected: boolean) -> (),
	setEnabled: (self: MenuButtonHandle, enabled: boolean) -> (),
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

export type EconomyItemData = {
	id: string,
	title: string,
	details: string,
	rarity: string?,
	state: string,
	actionText: string,
	actionEnabled: boolean,
	layoutOrder: number,
}

export type EconomyItemProps = {
	data: EconomyItemData,
	activated: ((itemId: string) -> ())?,
}

export type EconomyItemHandle = ElementHandle & {
	instance: GuiObject,
	setData: (self: EconomyItemHandle, data: EconomyItemData) -> (),
}

export type CrateAction = "Cash" | "Robux" | "Details"

export type CrateCardData = {
	id: string,
	title: string,
	highlight: string,
	odds: string,
	cashActionText: string,
	cashActionEnabled: boolean,
	robuxActionText: string,
	robuxActionEnabled: boolean,
	detailsActionText: string,
	layoutOrder: number,
	featured: boolean,
}

export type CrateCardProps = {
	data: CrateCardData,
	activated: ((crateId: string, action: CrateAction) -> ())?,
}

export type CrateCardHandle = ElementHandle & {
	instance: GuiObject,
	setData: (self: CrateCardHandle, data: CrateCardData) -> (),
}

export type StoreOfferCardData = {
	id: string,
	title: string,
	details: string,
	badge: string,
	image: string,
	style: string,
	actionText: string,
	actionEnabled: boolean,
	layoutOrder: number,
}

export type StoreOfferCardProps = {
	data: StoreOfferCardData,
	activated: ((offerId: string) -> ())?,
}

export type StoreOfferCardHandle = ElementHandle & {
	instance: GuiObject,
	setData: (self: StoreOfferCardHandle, data: StoreOfferCardData) -> (),
}

return {}
