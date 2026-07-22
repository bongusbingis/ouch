--!strict

-- Renders a crate as a featured merchandise card while routing purchases
-- through the existing authoritative crate action.

local ButtonElement = require(script.Parent.ButtonElement)
local ElementFactory = require(script.Parent.ElementFactory)
local ElementTypes = require(script.Parent.ElementTypes)
local TextSizer = require(script.Parent.Parent.TextSizer)

type CrateCardData = ElementTypes.CrateCardData
type CrateCardProps = ElementTypes.CrateCardProps
type CrateCardHandle = ElementTypes.CrateCardHandle

local CrateCardElement = {}

local function resolveTemplate(): CanvasGroup
	return ElementFactory.resolveTemplate("CrateCard", "CanvasGroup") :: CanvasGroup
end

local function waitLabel(parent: Instance, name: string): TextLabel
	local child = parent:WaitForChild(name)
	assert(child:IsA("TextLabel"), `[CrateCardElement] CrateCard.{name} must be a TextLabel`)
	return child
end

local function waitActionMount(parent: Instance): Frame
	local child = parent:WaitForChild("ActionMount")
	assert(child:IsA("Frame"), "[CrateCardElement] CrateCard.ActionMount must be a Frame")
	return child
end

function CrateCardElement.mount(parent: Instance, props: CrateCardProps): CrateCardHandle
	local card, handle = ElementFactory.cloneMount(resolveTemplate(), parent)
	assert(card:IsA("CanvasGroup"), "[CrateCardElement] cloned CrateCard must be a CanvasGroup")
	local title = waitLabel(card, "ItemName")
	local highlight = waitLabel(card, "Highlight")
	local odds = waitLabel(card, "Odds")
	local badge = waitLabel(card, "Badge")
	local actionMount = waitActionMount(card)
	local current = props.data
	local actionHandle: ElementTypes.ButtonHandle? = nil
	local config = game:GetService("ReplicatedStorage"):WaitForChild("Config")
	local actionColors = require(config:WaitForChild("Quests")).Button

	for _, label in { title, highlight, odds, badge } do
		handle:add(TextSizer.bind(label, label, { minSize = 8, maxSize = 24, padding = { x = 5, y = 2 } }))
	end
	handle:add(function()
		if actionHandle then
			actionHandle:destroy()
			actionHandle = nil
		end
	end)

	local function render(data: CrateCardData)
		current = data
		card.Name = `CrateCard_{data.id}`
		card.LayoutOrder = data.layoutOrder
		card.Visible = true
		title.Text = data.title
		highlight.Text = data.highlight
		odds.Text = data.odds
		badge.Text = if data.featured then "FEATURED CRATE" else "CRATE DROP"

		if actionHandle then
			actionHandle:destroy()
		end
		actionHandle = ButtonElement.mount(actionMount, {
			text = data.actionText,
			name = "Action",
			color = if data.actionEnabled then actionColors.EnabledColor else actionColors.DisabledColor,
			activated = function()
				if current.actionEnabled and props.activated then
					props.activated(current.id)
				end
			end,
		})
		actionHandle.instance.AnchorPoint = Vector2.new(0.5, 0.5)
		actionHandle.instance.Position = UDim2.fromScale(0.5, 0.5)
		actionHandle.instance.Size = UDim2.fromScale(1, 1)
		actionHandle:setEnabled(data.actionEnabled)
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
