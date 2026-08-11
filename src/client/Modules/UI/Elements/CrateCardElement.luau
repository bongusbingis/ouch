--!strict

-- Renders a crate with earned-Cash, direct-Robux, and disclosure actions.

local ButtonElement = require(script.Parent.ButtonElement)
local ElementFactory = require(script.Parent.ElementFactory)
local ElementTypes = require(script.Parent.ElementTypes)
local TextSizer = require(script.Parent.Parent.TextSizer)

type CrateCardData = ElementTypes.CrateCardData
type CrateCardProps = ElementTypes.CrateCardProps
type CrateCardHandle = ElementTypes.CrateCardHandle
type CrateAction = ElementTypes.CrateAction

local CrateCardElement = {}

local CASH_COLOR = { r = 0.16, g = 0.72, b = 0.55 }
local ROBUX_COLOR = { r = 0.63, g = 0.31, b = 0.88 }
local DETAILS_COLOR = { r = 0.22, g = 0.52, b = 0.86 }

local function resolveTemplate(): CanvasGroup
	return ElementFactory.resolveTemplate("CrateCard", "CanvasGroup") :: CanvasGroup
end

local function waitLabel(parent: Instance, name: string): TextLabel
	local child = parent:WaitForChild(name)
	assert(child:IsA("TextLabel"), `[CrateCardElement] CrateCard.{name} must be a TextLabel`)
	return child
end

local function waitActionMount(parent: Instance, name: string): Frame
	local child = parent:WaitForChild(name)
	assert(child:IsA("Frame"), `[CrateCardElement] CrateCard.{name} must be a Frame`)
	return child
end

function CrateCardElement.mount(parent: Instance, props: CrateCardProps): CrateCardHandle
	local card, handle = ElementFactory.cloneMount(resolveTemplate(), parent)
	assert(card:IsA("CanvasGroup"), "[CrateCardElement] cloned CrateCard must be a CanvasGroup")
	local title = waitLabel(card, "ItemName")
	local highlight = waitLabel(card, "Highlight")
	local odds = waitLabel(card, "Odds")
	local badge = waitLabel(card, "Badge")
	local cashMount = waitActionMount(card, "CashActionMount")
	local robuxMount = waitActionMount(card, "RobuxActionMount")
	local detailsMount = waitActionMount(card, "DetailsActionMount")
	local current = props.data
	local actionHandles: { ElementTypes.ButtonHandle } = {}
	local disabledColor =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Quests")).Button.DisabledColor

	for _, label in { title, highlight, odds, badge } do
		handle:add(TextSizer.bind(label, label, { minSize = 8, maxSize = 24, padding = { x = 5, y = 2 } }))
	end
	handle:add(function()
		for _, actionHandle in actionHandles do
			actionHandle:destroy()
		end
		table.clear(actionHandles)
	end)

	local function mountAction(
		mount: Frame,
		name: string,
		text: string,
		enabled: boolean,
		color: any,
		action: CrateAction
	)
		local actionHandle = ButtonElement.mount(mount, {
			text = text,
			name = name,
			color = if enabled then color else disabledColor,
			activated = function()
				if props.activated then
					props.activated(current.id, action)
				end
			end,
		})
		actionHandle.instance.AnchorPoint = Vector2.new(0.5, 0.5)
		actionHandle.instance.Position = UDim2.fromScale(0.5, 0.5)
		actionHandle.instance.Size = UDim2.fromScale(1, 1)
		actionHandle:setEnabled(enabled)
		table.insert(actionHandles, actionHandle)
	end

	local function render(data: CrateCardData)
		current = data
		card.Name = `CrateCard_{data.id}`
		card.LayoutOrder = data.layoutOrder
		card.Visible = true
		title.Text = data.title
		highlight.Text = data.highlight
		odds.Text = data.odds
		badge.Text = if data.featured then "FEATURED CRATE" else "CRATE DROP"

		for _, actionHandle in actionHandles do
			actionHandle:destroy()
		end
		table.clear(actionHandles)
		mountAction(cashMount, "CashAction", data.cashActionText, data.cashActionEnabled, CASH_COLOR, "Cash")
		mountAction(robuxMount, "RobuxAction", data.robuxActionText, data.robuxActionEnabled, ROBUX_COLOR, "Robux")
		mountAction(detailsMount, "DetailsAction", data.detailsActionText, true, DETAILS_COLOR, "Details")
	end

	local crateHandle = handle :: any
	crateHandle.instance = card
	function crateHandle:setData(data: CrateCardData)
		render(data)
	end

	render(current)
	return crateHandle :: CrateCardHandle
end

return CrateCardElement
