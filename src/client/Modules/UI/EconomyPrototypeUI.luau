--!strict

-- PROTOTYPE: Creates the unstyled economy UI in PlayerGui at runtime. The
-- generated tree is provisional; economy behavior remains in its controllers.

local EconomyPrototypeLayout = require(script.Parent.EconomyPrototypeLayout)

type NodeSpec = {
	className: string,
	name: string,
	properties: { [string]: any }?,
	children: { NodeSpec }?,
}

local EconomyPrototypeUI = {}

local itemTemplate: GuiObject? = nil

local function applyProperties(instance: Instance, properties: { [string]: any }?)
	for property, value in properties or {} do
		(instance :: any)[property] = value
	end
end

local function ensureTree(parent: Instance, spec: NodeSpec): Instance
	local instance = parent:FindFirstChild(spec.name)
	if instance == nil then
		instance = Instance.new(spec.className)
		instance.Name = spec.name
		instance.Parent = parent
	else
		assert(
			instance.ClassName == spec.className,
			`[EconomyPrototypeUI] {instance:GetFullName()} must be a {spec.className}`
		)
	end

	applyProperties(instance, spec.properties)
	for _, childSpec in spec.children or {} do
		ensureTree(instance, childSpec)
	end
	return instance
end

local function textConstraint(): NodeSpec
	return {
		className = "UITextSizeConstraint",
		name = "PrototypeTextSize",
		properties = {
			MinTextSize = 10,
			MaxTextSize = 22,
		},
	}
end

local function textLabel(name: string, text: string): NodeSpec
	return {
		className = "TextLabel",
		name = name,
		properties = {
			Text = text,
			TextScaled = true,
			TextWrapped = true,
		},
		children = { textConstraint() },
	}
end

local function actionButton(): NodeSpec
	return {
		className = "TextButton",
		name = "Action",
		properties = {
			Text = "Action",
			TextScaled = true,
			TextWrapped = true,
		},
		children = { textConstraint() },
	}
end

local function holder(): NodeSpec
	return {
		className = "ScrollingFrame",
		name = "Holder",
		properties = {
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.fromOffset(0, 0),
			ScrollingDirection = Enum.ScrollingDirection.Y,
		},
		children = {
			{
				className = "UIListLayout",
				name = "List",
				properties = {
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
			},
		},
	}
end

local function viewConstraint(): NodeSpec
	return {
		className = "UISizeConstraint",
		name = "PrototypeViewSize",
		properties = {
			MinSize = Vector2.new(280, 240),
			MaxSize = Vector2.new(960, 720),
		},
	}
end

local function shopView(): NodeSpec
	return {
		className = "Frame",
		name = "Shop",
		properties = { Visible = false },
		children = {
			textLabel("Title", "Shop"),
			textLabel("Cash", "Cash: loading"),
			textLabel("Status", "Economy data is loading."),
			holder(),
			viewConstraint(),
		},
	}
end

local function inventoryView(): NodeSpec
	return {
		className = "Frame",
		name = "Inventory",
		properties = { Visible = false },
		children = {
			textLabel("Title", "Inventory"),
			textLabel("Status", "Economy data is loading."),
			holder(),
			viewConstraint(),
		},
	}
end

local function itemRow(): NodeSpec
	return {
		className = "Frame",
		name = "EconomyItem",
		properties = { Visible = false },
		children = {
			textLabel("ItemName", "Item"),
			textLabel("Details", "Details"),
			textLabel("State", "State"),
			actionButton(),
		},
	}
end

function EconomyPrototypeUI.mount()
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local views = playerGui:WaitForChild("MainGui"):WaitForChild("BaseClip"):WaitForChild("Views")
	local templates = ensureTree(playerGui, {
		className = "Folder",
		name = "EconomyPrototypeTemplates",
	})

	local shop = ensureTree(views, shopView())
	local inventory = ensureTree(views, inventoryView())
	local template = ensureTree(templates, itemRow())
	assert(shop:IsA("GuiObject"), "[EconomyPrototypeUI] Shop must be a GuiObject")
	assert(inventory:IsA("GuiObject"), "[EconomyPrototypeUI] Inventory must be a GuiObject")
	assert(template:IsA("GuiObject"), "[EconomyPrototypeUI] EconomyItem must be a GuiObject")

	EconomyPrototypeLayout.applyShop(shop)
	EconomyPrototypeLayout.applyInventory(inventory)
	EconomyPrototypeLayout.applyEconomyItem(template)
	itemTemplate = template
end

function EconomyPrototypeUI.getItemTemplate(): GuiObject
	if itemTemplate == nil or itemTemplate.Parent == nil then
		EconomyPrototypeUI.mount()
	end
	return itemTemplate :: GuiObject
end

return EconomyPrototypeUI
