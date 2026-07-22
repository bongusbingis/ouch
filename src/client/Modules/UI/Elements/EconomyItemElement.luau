--!strict

-- Styled economy list row shared by Shop and Inventory.

local ButtonElement = require(script.Parent.ButtonElement)
local ElementFactory = require(script.Parent.ElementFactory)
local ElementTypes = require(script.Parent.ElementTypes)
local EconomyPrototypeLayout = require(script.Parent.Parent.EconomyPrototypeLayout)
local TextSizer = require(script.Parent.Parent.TextSizer)

type EconomyItemData = ElementTypes.EconomyItemData
type EconomyItemProps = ElementTypes.EconomyItemProps
type EconomyItemHandle = ElementTypes.EconomyItemHandle

type MountOptions = {
	template: GuiObject?,
}

local EconomyItemElement = {}

local function resolveTemplate(): GuiObject
	return ElementFactory.resolveTemplate("EconomyItem", "CanvasGroup") :: GuiObject
end

local function waitLabel(parent: Instance, name: string): TextLabel
	local child = parent:WaitForChild(name)
	assert(child:IsA("TextLabel"), `[EconomyItemElement] EconomyItem.{name} must be a TextLabel`)
	return child
end

local function waitActionMount(parent: Instance): Frame
	local child = parent:WaitForChild("ActionMount")
	assert(child:IsA("Frame"), "[EconomyItemElement] EconomyItem.ActionMount must be a Frame")
	return child
end

local function waitStateChip(parent: Instance): Frame
	local child = parent:WaitForChild("StateChip")
	assert(child:IsA("Frame"), "[EconomyItemElement] EconomyItem.StateChip must be a Frame")
	return child
end

local function waitAccent(parent: Instance): Frame
	local child = parent:WaitForChild("Accent")
	assert(child:IsA("Frame"), "[EconomyItemElement] EconomyItem.Accent must be a Frame")
	return child
end

local function waitLegacyAction(parent: Instance): TextButton
	local child = parent:WaitForChild("Action")
	assert(child:IsA("TextButton"), "[EconomyItemElement] EconomyItem.Action must be a TextButton")
	return child
end

local function stateColors(state: string): (Color3, Color3)
	if state == "Equipped" then
		return Color3.fromRGB(150, 235, 119), Color3.fromRGB(89, 192, 93)
	elseif state == "Available" then
		return Color3.fromRGB(133, 235, 224), Color3.fromRGB(70, 187, 186)
	elseif state == "Owned" then
		return Color3.fromRGB(255, 224, 126), Color3.fromRGB(242, 174, 64)
	elseif state == "Opening" then
		return Color3.fromRGB(255, 170, 207), Color3.fromRGB(239, 95, 164)
	elseif state == "Default" then
		return Color3.fromRGB(205, 242, 153), Color3.fromRGB(116, 190, 75)
	end
	return Color3.fromRGB(255, 232, 170), Color3.fromRGB(237, 183, 89)
end

local function rarityColor(rarity: string?): Color3
	if rarity == "Rare" then
		return Color3.fromRGB(70, 139, 235)
	elseif rarity == "Epic" then
		return Color3.fromRGB(204, 76, 221)
	elseif rarity == "Legendary" then
		return Color3.fromRGB(244, 151, 39)
	elseif rarity == "Exclusive" then
		return Color3.fromRGB(143, 88, 226)
	elseif rarity == "Default" then
		return Color3.fromRGB(113, 194, 72)
	end
	return Color3.fromRGB(48, 187, 178)
end

function EconomyItemElement.mount(parent: Instance, props: EconomyItemProps, options: MountOptions?): EconomyItemHandle
	local template = if options and options.template then options.template else resolveTemplate()
	local row, handle = ElementFactory.cloneMount(template, parent)
	local styled = row:IsA("CanvasGroup")
	if not styled then
		EconomyPrototypeLayout.applyEconomyItem(row)
	end
	local nameLabel = waitLabel(row, "ItemName")
	local detailsLabel = waitLabel(row, "Details")
	local stateLabel = waitLabel(row, "State")
	local actionMount = if styled then waitActionMount(row) else nil
	local stateChip = if styled then waitStateChip(row) else nil
	local accent = if styled then waitAccent(row) else nil
	local legacyAction = if styled then nil else waitLegacyAction(row)
	local legacyButton = legacyAction :: TextButton
	local current = props.data
	local actionHandle: ElementTypes.ButtonHandle? = nil
	local actionColors: any = nil
	local stateGradient: UIGradient? = nil

	if styled then
		local config = game:GetService("ReplicatedStorage"):WaitForChild("Config")
		local uiConfig = require(config:WaitForChild("UI"))
		actionColors = require(config:WaitForChild("Quests")).Button
		local chip = stateChip :: Frame
		local gradient = chip:WaitForChild("ColorWash")
		assert(gradient:IsA("UIGradient"), "[EconomyItemElement] EconomyItem.StateChip.ColorWash must be a UIGradient")
		stateGradient = gradient
		for _, label in { nameLabel, detailsLabel, stateLabel } do
			label.FontFace = uiConfig.Text.DefaultFont
			label.TextScaled = false
		end
		handle:add(TextSizer.bind(nameLabel, nameLabel, { minSize = 12, maxSize = 20, padding = { x = 6, y = 2 } }))
		handle:add(
			TextSizer.bind(detailsLabel, detailsLabel, { minSize = 10, maxSize = 16, padding = { x = 6, y = 2 } })
		)
		handle:add(TextSizer.bind(stateLabel, stateLabel, { minSize = 10, maxSize = 15, padding = { x = 6, y = 2 } }))
	else
		handle:add(legacyButton.Activated:Connect(function()
			if current.actionEnabled and props.activated then
				props.activated(current.id)
			end
		end))
	end
	handle:add(function()
		if actionHandle then
			actionHandle:destroy()
			actionHandle = nil
		end
	end)

	local function render(data: EconomyItemData)
		current = data
		row.Name = `EconomyItem_{data.id}`
		row.LayoutOrder = data.layoutOrder
		row.Rotation = 0
		row.Visible = true
		nameLabel.Text = data.title
		detailsLabel.Text = data.details
		stateLabel.Text = data.state
		if styled then
			local lightColor, darkColor = stateColors(data.state)
			local rarityAccent = rarityColor(data.rarity)
			local chip = stateChip :: Frame
			local accentBar = accent :: Frame
			chip.BackgroundColor3 = lightColor
			accentBar.BackgroundColor3 = rarityAccent
			detailsLabel.TextColor3 = rarityAccent
			local gradient = stateGradient :: UIGradient
			gradient.Color = ColorSequence.new(lightColor, darkColor)
			if actionHandle then
				actionHandle:destroy()
			end
			actionHandle = ButtonElement.mount(actionMount :: Frame, {
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
		else
			legacyButton.Text = data.actionText
			legacyButton.Active = data.actionEnabled
			legacyButton.Selectable = data.actionEnabled
		end
	end

	local itemHandle = handle :: any
	itemHandle.instance = row
	function itemHandle:setData(data: EconomyItemData)
		render(data)
	end

	render(current)
	return itemHandle :: EconomyItemHandle
end

return EconomyItemElement
