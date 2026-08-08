--!strict

-- Renders live-priced game-pass and developer-product offers without owning
-- platform purchase or entitlement state.

local ButtonElement = require(script.Parent.ButtonElement)
local ElementFactory = require(script.Parent.ElementFactory)
local ElementTypes = require(script.Parent.ElementTypes)
local TextSizer = require(script.Parent.Parent.TextSizer)

type StoreOfferCardData = ElementTypes.StoreOfferCardData
type StoreOfferCardProps = ElementTypes.StoreOfferCardProps
type StoreOfferCardHandle = ElementTypes.StoreOfferCardHandle

local StoreOfferCardElement = {}

local GLYPHS = {
	GamePass = "★",
	Cash = "$",
	Crate = "?",
	SeasonPass = "◆",
}

local function resolveTemplate(): CanvasGroup
	return ElementFactory.resolveTemplate("StoreOfferCard", "CanvasGroup") :: CanvasGroup
end

local function waitLabel(parent: Instance, name: string): TextLabel
	local child = parent:WaitForChild(name)
	assert(child:IsA("TextLabel"), `[StoreOfferCardElement] StoreOfferCard.{name} must be a TextLabel`)
	return child
end

local function waitFrame(parent: Instance, name: string): Frame
	local child = parent:WaitForChild(name)
	assert(child:IsA("Frame"), `[StoreOfferCardElement] StoreOfferCard.{name} must be a Frame`)
	return child
end

function StoreOfferCardElement.mount(parent: Instance, props: StoreOfferCardProps): StoreOfferCardHandle
	local card, handle = ElementFactory.cloneMount(resolveTemplate(), parent)
	assert(card:IsA("CanvasGroup"), "[StoreOfferCardElement] cloned StoreOfferCard must be a CanvasGroup")
	local title = waitLabel(card, "ItemName")
	local details = waitLabel(card, "Details")
	local badge = waitLabel(card, "Badge")
	local glyph = waitLabel(card, "Glyph")
	local accent = waitFrame(card, "Accent")
	local badgeChip = waitFrame(card, "BadgeChip")
	local iconWell = waitFrame(card, "IconWell")
	local iconInstance = iconWell:WaitForChild("Icon")
	assert(iconInstance:IsA("ImageLabel"), "[StoreOfferCardElement] StoreOfferCard.IconWell.Icon must be an ImageLabel")
	local icon = iconInstance :: ImageLabel
	local actionMount = waitFrame(card, "ActionMount")
	local colorWash = card:WaitForChild("ColorWash")
	assert(colorWash:IsA("UIGradient"), "[StoreOfferCardElement] StoreOfferCard.ColorWash must be a UIGradient")
	local current = props.data
	local actionHandle: ElementTypes.ButtonHandle? = nil
	local config = game:GetService("ReplicatedStorage"):WaitForChild("Config")
	local uiConfig = require(config:WaitForChild("UI"))
	local disabledColor = require(config:WaitForChild("Quests")).Button.DisabledColor

	for _, label in { title, details, badge, glyph } do
		handle:add(TextSizer.bind(label, label, { minSize = 8, maxSize = 21, padding = { x = 4, y = 2 } }))
	end
	handle:add(function()
		if actionHandle then
			actionHandle:destroy()
			actionHandle = nil
		end
	end)

	local function render(data: StoreOfferCardData)
		current = data
		local palette = uiConfig.Elements.StoreOffer.Palettes[data.style]
			or uiConfig.Elements.StoreOffer.Palettes.GamePass
		card.Name = `StoreOfferCard_{data.id}`
		card.LayoutOrder = data.layoutOrder
		card.BackgroundColor3 = palette.Background
		card.Visible = true
		colorWash.Color = ColorSequence.new(palette.Top, palette.Bottom)
		accent.BackgroundColor3 = palette.Accent
		badgeChip.BackgroundColor3 = palette.Accent
		iconWell.BackgroundColor3 = palette.Icon
		title.Text = data.title
		details.Text = data.details
		badge.Text = data.badge
		glyph.Text = GLYPHS[data.style] or "★"
		icon.Image = data.image
		icon.Visible = data.image ~= ""
		glyph.Visible = not icon.Visible

		if actionHandle then
			actionHandle:destroy()
		end
		actionHandle = ButtonElement.mount(actionMount, {
			text = data.actionText,
			name = "Action",
			color = if data.actionEnabled then palette.Button else disabledColor,
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

	local offerHandle = handle :: any
	offerHandle.instance = card
	function offerHandle:setData(data: StoreOfferCardData)
		render(data)
	end

	render(current)
	return offerHandle :: StoreOfferCardHandle
end

return StoreOfferCardElement
