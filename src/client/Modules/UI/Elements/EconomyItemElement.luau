--!strict

-- PROTOTYPE: Functional, unstyled economy list row shared by Shop and
-- Inventory. Presentation comes from the runtime-generated EconomyItem template.

local ElementFactory = require(script.Parent.ElementFactory)
local ElementTypes = require(script.Parent.ElementTypes)
local EconomyPrototypeLayout = require(script.Parent.Parent.EconomyPrototypeLayout)
local EconomyPrototypeUI = require(script.Parent.Parent.EconomyPrototypeUI)

type EconomyItemData = ElementTypes.EconomyItemData
type EconomyItemProps = ElementTypes.EconomyItemProps
type EconomyItemHandle = ElementTypes.EconomyItemHandle

type MountOptions = {
	template: GuiObject?,
}

local EconomyItemElement = {}

local function resolveTemplate(): GuiObject
	return EconomyPrototypeUI.getItemTemplate()
end

local function waitLabel(parent: Instance, name: string): TextLabel
	local child = parent:WaitForChild(name)
	assert(child:IsA("TextLabel"), `[EconomyItemElement] EconomyItem.{name} must be a TextLabel`)
	return child
end

local function waitAction(parent: Instance): TextButton
	local child = parent:WaitForChild("Action")
	assert(child:IsA("TextButton"), "[EconomyItemElement] EconomyItem.Action must be a TextButton")
	return child
end

function EconomyItemElement.mount(parent: Instance, props: EconomyItemProps, options: MountOptions?): EconomyItemHandle
	local template = if options and options.template then options.template else resolveTemplate()
	local row, handle = ElementFactory.cloneMount(template, parent)
	EconomyPrototypeLayout.applyEconomyItem(row)
	local nameLabel = waitLabel(row, "ItemName")
	local detailsLabel = waitLabel(row, "Details")
	local stateLabel = waitLabel(row, "State")
	local action = waitAction(row)
	local current = props.data

	local function render(data: EconomyItemData)
		current = data
		row.Name = `EconomyItem_{data.id}`
		row.LayoutOrder = data.layoutOrder
		row.Visible = true
		nameLabel.Text = data.title
		detailsLabel.Text = data.details
		stateLabel.Text = data.state
		action.Text = data.actionText
		action.Active = data.actionEnabled
		action.Selectable = data.actionEnabled
	end

	handle:add(action.Activated:Connect(function()
		if current.actionEnabled and props.activated then
			props.activated(current.id)
		end
	end))

	local itemHandle = handle :: any
	itemHandle.instance = row
	function itemHandle:setData(data: EconomyItemData)
		render(data)
	end

	render(current)
	return itemHandle :: EconomyItemHandle
end

return EconomyItemElement
