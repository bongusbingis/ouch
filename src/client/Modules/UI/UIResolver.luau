--!strict

-- Resolves and styles the client menu views and reusable UI templates.
-- Complete Studio-authored trees are reused; incomplete authored shells receive
-- only the exact temporary fallback children required by the same hierarchy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TextSizer = require(script.Parent.TextSizer)

local UIResolver = {}

local BUTTON_IMAGE = "rbxassetid://83760294607871"
local INVENTORY_IMAGE = "rbxassetid://100048560712929"
local SHOP_IMAGE = "rbxassetid://80022054809064"
local LEADERBOARD_IMAGE = "rbxassetid://95850040271266"
local SETTINGS_IMAGE = "rbxassetid://84958958438571"
local NOTIFICATION_IMAGE = "rbxassetid://128975504294668"
local LEADERBOARD_ROW_IMAGE = "rbxassetid://139613458882714"
local ECONOMY_CARD_ASPECT = 2.08
local SHOP_ASPECT = 1.4415
local INVENTORY_NATIVE_ASPECT = 4 / 3
local INVENTORY_ART_ASPECT = 1612 / 1142
local INVENTORY_PANEL_WIDTH = INVENTORY_ART_ASPECT / SHOP_ASPECT
local INVENTORY_ART_INSET = 0.012
local INVENTORY_ART_SCALE = 1 - INVENTORY_ART_INSET * 2
local INVENTORY_IMAGE_X = INVENTORY_ART_INSET - INVENTORY_ART_SCALE * 298 / 1612
local INVENTORY_IMAGE_Y = INVENTORY_ART_INSET - INVENTORY_ART_SCALE * 204 / 1142
local INVENTORY_IMAGE_WIDTH = INVENTORY_ART_SCALE * 2160 / 1612
local INVENTORY_IMAGE_HEIGHT = INVENTORY_ART_SCALE * 1620 / 1142

local INVENTORY_TABS = {
	{ id = "BallAssets", label = "BALLS" },
	{ id = "HammerAssets", label = "HAMMERS" },
	{ id = "TrailAssets", label = "TRAILS" },
	{ id = "CostumeAssets", label = "OUTFITS" },
	{ id = "EmoteAssets", label = "EMOTES" },
}

local PAPER_TEXT = Color3.fromRGB(42, 28, 22)
local MUTED_TEXT = Color3.fromRGB(102, 65, 45)
local cleanups: { () -> () } = {}
local mounted = false
local cachedConfig: any = nil

local function uiConfig(): any
	if cachedConfig == nil then
		cachedConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI"))
	end
	return cachedConfig
end

local function topLeft(gui: GuiObject, x: number, y: number, width: number, height: number, zIndex: number)
	gui.AnchorPoint = Vector2.zero
	gui.Position = UDim2.fromScale(x, y)
	gui.Size = UDim2.fromScale(width, height)
	gui.ZIndex = zIndex
end

local function centered(gui: GuiObject, x: number, y: number, width: number, height: number, zIndex: number)
	gui.AnchorPoint = Vector2.new(0.5, 0.5)
	gui.Position = UDim2.fromScale(x, y)
	gui.Size = UDim2.fromScale(width, height)
	gui.ZIndex = zIndex
end

local function ensureAspect(parent: Instance, ratio: number): UIAspectRatioConstraint
	local existing = parent:FindFirstChild("AspectRatio") or parent:FindFirstChildWhichIsA("UIAspectRatioConstraint")
	local constraint: UIAspectRatioConstraint
	if existing then
		assert(
			existing:IsA("UIAspectRatioConstraint"),
			`[UIResolver] {parent.Name}.AspectRatio must be a UIAspectRatioConstraint`
		)
		constraint = existing
		constraint.Name = "AspectRatio"
	else
		constraint = Instance.new("UIAspectRatioConstraint")
		constraint.Name = "AspectRatio"
		constraint.Parent = parent
	end
	constraint.AspectRatio = ratio
	constraint.AspectType = Enum.AspectType.FitWithinMaxSize
	constraint.DominantAxis = Enum.DominantAxis.Width
	return constraint
end

local function styleText(
	label: TextLabel,
	text: string,
	x: number,
	y: number,
	width: number,
	height: number,
	minSize: number,
	maxSize: number,
	zIndex: number,
	alignment: Enum.TextXAlignment?
)
	label.BackgroundTransparency = 1
	label.FontFace = uiConfig().Text.DefaultFont
	label.Text = text
	label.TextColor3 = PAPER_TEXT
	label.TextScaled = false
	label.TextWrapped = true
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Visible = true
	topLeft(label, x, y, width, height, zIndex)
	table.insert(
		cleanups,
		TextSizer.bind(label, label, {
			minSize = minSize,
			maxSize = maxSize,
			padding = { x = 6, y = 2 },
		})
	)
end

local function resolveText(
	parent: Instance,
	name: string,
	text: string,
	x: number,
	y: number,
	width: number,
	height: number,
	minSize: number,
	maxSize: number,
	zIndex: number,
	alignment: Enum.TextXAlignment?
): TextLabel
	local existing = parent:FindFirstChild(name)
	local label: TextLabel
	if existing then
		assert(existing:IsA("TextLabel"), `[UIResolver] {parent.Name}.{name} must be a TextLabel`)
		label = existing
	else
		label = Instance.new("TextLabel")
		label.Name = name
		label.Parent = parent
	end
	styleText(label, text, x, y, width, height, minSize, maxSize, zIndex, alignment)
	return label
end

local function styleImage(
	label: ImageLabel,
	image: string,
	ratio: number,
	x: number,
	y: number,
	width: number,
	height: number,
	zIndex: number,
	color: Color3?
)
	label.BackgroundTransparency = 1
	label.Image = image
	label.ImageColor3 = color or Color3.new(1, 1, 1)
	label.ImageRectOffset = Vector2.zero
	label.ImageRectSize = Vector2.zero
	label.ImageTransparency = 0
	label.ScaleType = Enum.ScaleType.Fit
	label.Visible = true
	topLeft(label, x, y, width, height, zIndex)
	ensureAspect(label, ratio)
end

local function resolveImage(
	parent: Instance,
	name: string,
	image: string,
	ratio: number,
	x: number,
	y: number,
	width: number,
	height: number,
	zIndex: number,
	color: Color3?
): ImageLabel
	local existing = parent:FindFirstChild(name)
	local label: ImageLabel
	if existing then
		assert(existing:IsA("ImageLabel"), `[UIResolver] {parent.Name}.{name} must be an ImageLabel`)
		label = existing
	else
		label = Instance.new("ImageLabel")
		label.Name = name
		label.Parent = parent
	end
	styleImage(label, image, ratio, x, y, width, height, zIndex, color)
	return label
end

local function styleNativePanel(
	panel: GuiObject,
	background: Color3,
	gradientTop: Color3,
	gradientBottom: Color3,
	strokeColor: Color3,
	radius: number
)
	panel.BackgroundColor3 = background
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0

	local cornerInstance = panel:FindFirstChild("Corner")
	local corner: UICorner
	if cornerInstance then
		assert(cornerInstance:IsA("UICorner"), `[UIResolver] {panel.Name}.Corner must be a UICorner`)
		corner = cornerInstance
	else
		corner = Instance.new("UICorner")
		corner.Name = "Corner"
		corner.Parent = panel
	end
	corner.CornerRadius = UDim.new(radius, 0)

	local strokeInstance = panel:FindFirstChild("Outline")
	local stroke: UIStroke
	if strokeInstance then
		assert(strokeInstance:IsA("UIStroke"), `[UIResolver] {panel.Name}.Outline must be a UIStroke`)
		stroke = strokeInstance
	else
		stroke = Instance.new("UIStroke")
		stroke.Name = "Outline"
		stroke.Parent = panel
	end
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = strokeColor
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = 2.5
	stroke.Transparency = 0.12

	local gradientInstance = panel:FindFirstChild("ColorWash")
	local gradient: UIGradient
	if gradientInstance then
		assert(gradientInstance:IsA("UIGradient"), `[UIResolver] {panel.Name}.ColorWash must be a UIGradient`)
		gradient = gradientInstance
	else
		gradient = Instance.new("UIGradient")
		gradient.Name = "ColorWash"
		gradient.Parent = panel
	end
	gradient.Color = ColorSequence.new(gradientTop, gradientBottom)
	gradient.Rotation = 105
end

local function resolveNativePanel(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	width: number,
	height: number,
	zIndex: number,
	background: Color3,
	gradientTop: Color3,
	gradientBottom: Color3,
	strokeColor: Color3,
	radius: number
): Frame
	local existing = parent:FindFirstChild(name)
	local panel: Frame
	if existing then
		assert(existing:IsA("Frame"), `[UIResolver] {parent.Name}.{name} must be a Frame`)
		panel = existing
	else
		panel = Instance.new("Frame")
		panel.Name = name
		panel.Parent = parent
	end
	topLeft(panel, x, y, width, height, zIndex)
	styleNativePanel(panel, background, gradientTop, gradientBottom, strokeColor, radius)
	panel.Visible = true
	return panel
end

local function resolveContainer(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	width: number,
	height: number,
	zIndex: number
): Frame
	local existing = parent:FindFirstChild(name)
	local frame: Frame
	if existing then
		assert(existing:IsA("Frame"), `[UIResolver] {parent.Name}.{name} must be a Frame`)
		frame = existing
	else
		frame = Instance.new("Frame")
		frame.Name = name
		frame.Parent = parent
	end
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Visible = true
	topLeft(frame, x, y, width, height, zIndex)
	return frame
end

local function hideLegacyGui(parent: Instance, name: string)
	local legacy = parent:FindFirstChild(name)
	if legacy and legacy:IsA("GuiObject") then
		legacy.Visible = false
	end
end

local function resolveAccent(
	parent: Instance,
	name: string,
	color: Color3,
	x: number,
	y: number,
	width: number,
	height: number
)
	local existing = parent:FindFirstChild(name)
	local accent: Frame
	if existing then
		assert(existing:IsA("Frame"), `[UIResolver] {parent.Name}.{name} must be a Frame`)
		accent = existing
	else
		accent = Instance.new("Frame")
		accent.Name = name
		accent.Parent = parent
	end
	accent.BackgroundColor3 = color
	accent.BorderSizePixel = 0
	accent.Visible = true
	topLeft(accent, x, y, width, height, 15)

	local existingCorner = accent:FindFirstChild("Corner")
	local corner: UICorner
	if existingCorner then
		assert(existingCorner:IsA("UICorner"), `[UIResolver] {parent.Name}.{name}.Corner must be a UICorner`)
		corner = existingCorner
	else
		corner = Instance.new("UICorner")
		corner.Name = "Corner"
		corner.Parent = accent
	end
	corner.CornerRadius = UDim.new(0.5, 0)
	return accent
end

local function styleScroll(holder: ScrollingFrame, x: number, y: number, width: number, height: number)
	holder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.CanvasSize = UDim2.fromScale(0, 0)
	holder.ClipsDescendants = true
	holder.ScrollBarImageColor3 = Color3.fromRGB(68, 40, 31)
	holder.ScrollBarThickness = 4
	holder.ScrollingDirection = Enum.ScrollingDirection.Y
	holder.Visible = true
	topLeft(holder, x, y, width, height, 12)
end

local function resolveScroll(parent: Instance, x: number, y: number, width: number, height: number): ScrollingFrame
	local existing = parent:FindFirstChild("Holder")
	local holder: ScrollingFrame
	if existing then
		assert(existing:IsA("ScrollingFrame"), `[UIResolver] {parent.Name}.Holder must be a ScrollingFrame`)
		holder = existing
	else
		holder = Instance.new("ScrollingFrame")
		holder.Name = "Holder"
		holder.Parent = parent
	end
	styleScroll(holder, x, y, width, height)
	return holder
end

local function resolveListHolder(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	height: number,
	padding: number
): ScrollingFrame
	local holder = resolveScroll(parent, x, y, width, height)
	local existing = holder:FindFirstChild("List") or holder:FindFirstChildWhichIsA("UIListLayout")
	local layout: UIListLayout
	if existing then
		assert(existing:IsA("UIListLayout"), `[UIResolver] {parent.Name}.Holder.List must be a UIListLayout`)
		layout = existing
		layout.Name = "List"
	else
		layout = Instance.new("UIListLayout")
		layout.Name = "List"
		layout.Parent = holder
	end
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(padding, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	return holder
end

local function resolveEconomyHolder(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	height: number
): ScrollingFrame
	local holder = resolveScroll(parent, x, y, width, height)
	local oldList = holder:FindFirstChild("List") or holder:FindFirstChildWhichIsA("UIListLayout")
	if oldList and oldList:IsA("UIListLayout") then
		oldList:Destroy()
	end
	local existing = holder:FindFirstChild("Grid") or holder:FindFirstChildWhichIsA("UIGridLayout")
	local grid: UIGridLayout
	if existing then
		assert(existing:IsA("UIGridLayout"), `[UIResolver] {parent.Name}.Holder.Grid must be a UIGridLayout`)
		grid = existing
		grid.Name = "Grid"
	else
		grid = Instance.new("UIGridLayout")
		grid.Name = "Grid"
		grid.Parent = holder
	end
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.StartCorner = Enum.StartCorner.TopLeft
	grid.VerticalAlignment = Enum.VerticalAlignment.Top

	local function refreshGrid()
		local wide = holder.AbsoluteSize.X >= 520
		local widthScale = if wide then 0.47 else 0.92
		local holderSize = holder.AbsoluteSize
		local heightScale = if holderSize.Y > 0
			then (holderSize.X * widthScale / ECONOMY_CARD_ASPECT) / holderSize.Y
			else 0.52
		local gapScale = if holderSize.Y > 0 then (holderSize.X * 0.018) / holderSize.Y else 0.04
		grid.CellPadding = UDim2.fromScale(if wide then 0.025 else 0.04, gapScale)
		grid.CellSize = UDim2.fromScale(widthScale, heightScale)
	end
	refreshGrid()
	local connection = holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshGrid)
	table.insert(cleanups, function()
		connection:Disconnect()
	end)
	return holder
end

local function resolveCrateShelf(parent: Instance, x: number, y: number, width: number, height: number): ScrollingFrame
	local holder = resolveScroll(parent, x, y, width, height)
	holder.AutomaticCanvasSize = Enum.AutomaticSize.X
	holder.ScrollingDirection = Enum.ScrollingDirection.X
	holder.ScrollBarThickness = 3

	local oldGrid = holder:FindFirstChild("Grid") or holder:FindFirstChildWhichIsA("UIGridLayout")
	if oldGrid then
		oldGrid:Destroy()
	end
	local existing = holder:FindFirstChild("Shelf") or holder:FindFirstChildWhichIsA("UIListLayout")
	local layout: UIListLayout
	if existing then
		assert(existing:IsA("UIListLayout"), `[UIResolver] {parent.Name}.Holder.Shelf must be a UIListLayout`)
		layout = existing
		layout.Name = "Shelf"
	else
		layout = Instance.new("UIListLayout")
		layout.Name = "Shelf"
		layout.Parent = holder
	end
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Padding = UDim.new(0.025, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	return holder
end

local function styleMenuRoot(view: CanvasGroup, ratio: number)
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.BackgroundTransparency = 1
	view.ClipsDescendants = false
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Visible = false
	view.ZIndex = 10
	ensureAspect(view, ratio)

	local sizeConstraint = view:FindFirstChild("ViewSize") or view:FindFirstChildWhichIsA("UISizeConstraint")
	if sizeConstraint then
		sizeConstraint:Destroy()
	end

	local boundsParent = view.Parent
	while boundsParent and not boundsParent:IsA("GuiObject") do
		boundsParent = boundsParent.Parent
	end

	local function refreshSize()
		local portrait = boundsParent
			and (boundsParent :: GuiObject).AbsoluteSize.Y > (boundsParent :: GuiObject).AbsoluteSize.X
		view.Size = if portrait then UDim2.fromScale(0.92, 0.82) else UDim2.fromScale(0.7, 0.74)
	end
	refreshSize()
	if boundsParent then
		local connection = (boundsParent :: GuiObject):GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshSize)
		table.insert(cleanups, function()
			connection:Disconnect()
		end)
	end
end

local function buildMenuRoot(parent: Instance, name: string): CanvasGroup
	local view = Instance.new("CanvasGroup")
	view.Name = name
	view.Parent = parent
	return view
end

local function populateButtonTemplate(button: ImageButton)
	button.AnchorPoint = Vector2.zero
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Image = BUTTON_IMAGE
	button.ImageRectOffset = Vector2.zero
	button.ImageRectSize = Vector2.zero
	button.ImageTransparency = 0
	button.Position = UDim2.fromScale(0, 0)
	button.ScaleType = Enum.ScaleType.Fit
	button.Size = UDim2.fromScale(0.92, 0.14)
	button.Visible = false
	ensureAspect(button, 1.962)
	local label = resolveText(button, "Label", "Button", 0.1, 0.16, 0.8, 0.68, 12, 26, 2, Enum.TextXAlignment.Center)
	label.TextColor3 = Color3.fromRGB(31, 22, 20)
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is an
-- Assets.UI.Templates.ButtonTemplate ImageButton with Label and AspectRatio.
local function resolveButtonTemplate(templates: Instance): ImageButton
	local authored = templates:FindFirstChild("ButtonTemplate")
	local button: ImageButton
	if authored then
		assert(authored:IsA("ImageButton"), "[UIResolver] Assets.UI.Templates.ButtonTemplate must be an ImageButton")
		button = authored
	else
		button = Instance.new("ImageButton")
		button.Name = "ButtonTemplate"
		button.Parent = templates
	end
	populateButtonTemplate(button)
	return button
end

local function populateEconomyItem(row: CanvasGroup)
	row.AnchorPoint = Vector2.zero
	row.BackgroundTransparency = 0.02
	row.BorderSizePixel = 0
	row.ClipsDescendants = false
	row.GroupTransparency = 0
	row.Position = UDim2.fromScale(0, 0)
	row.Size = UDim2.fromScale(1, 1)
	row.ZIndex = 13
	row.Visible = false
	styleNativePanel(
		row,
		Color3.fromRGB(255, 247, 221),
		Color3.fromRGB(255, 252, 238),
		Color3.fromRGB(255, 225, 190),
		Color3.fromRGB(75, 45, 38),
		0.12
	)
	resolveAccent(row, "Accent", Color3.fromRGB(48, 209, 187), 0.035, 0.13, 0.022, 0.72)
	resolveText(row, "ItemName", "Item", 0.09, 0.08, 0.53, 0.24, 12, 20, 14, nil)
	resolveText(row, "Details", "Details", 0.09, 0.33, 0.53, 0.2, 10, 16, 14, nil)
	resolveNativePanel(
		row,
		"StateChip",
		0.09,
		0.62,
		0.31,
		0.19,
		13,
		Color3.fromRGB(255, 211, 103),
		Color3.fromRGB(255, 231, 144),
		Color3.fromRGB(255, 190, 86),
		Color3.fromRGB(105, 61, 37),
		0.45
	)
	local state = resolveText(row, "State", "State", 0.09, 0.62, 0.31, 0.19, 10, 15, 14, Enum.TextXAlignment.Center)
	state.TextColor3 = Color3.fromRGB(65, 39, 30)

	local existingMount = row:FindFirstChild("ActionMount")
	local actionMount: Frame
	if existingMount then
		assert(existingMount:IsA("Frame"), "[UIResolver] EconomyItem.ActionMount must be a Frame")
		actionMount = existingMount
	else
		actionMount = Instance.new("Frame")
		actionMount.Name = "ActionMount"
		actionMount.Parent = row
	end
	actionMount.BackgroundTransparency = 1
	topLeft(actionMount, 0.61, 0.54, 0.34, 0.34, 14)
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is an
-- Assets.UI.Templates.EconomyItem CanvasGroup with Corner, Outline, ColorWash,
-- Accent, ItemName, Details, StateChip, State, and ActionMount.
local function resolveEconomyItemTemplate(templates: Instance): CanvasGroup
	local authored = templates:FindFirstChild("EconomyItem")
	local row: CanvasGroup
	if authored then
		assert(authored:IsA("CanvasGroup"), "[UIResolver] Assets.UI.Templates.EconomyItem must be a CanvasGroup")
		row = authored
	else
		row = Instance.new("CanvasGroup")
		row.Name = "EconomyItem"
		row.Parent = templates
	end
	populateEconomyItem(row)
	return row
end

local function populateCrateCard(card: CanvasGroup)
	card.AnchorPoint = Vector2.zero
	card.BackgroundTransparency = 0.02
	card.BorderSizePixel = 0
	card.ClipsDescendants = false
	card.GroupTransparency = 0
	card.Position = UDim2.fromScale(0, 0)
	card.Size = UDim2.fromScale(1, 1)
	card.ZIndex = 13
	card.Visible = false
	styleNativePanel(
		card,
		Color3.fromRGB(255, 231, 164),
		Color3.fromRGB(255, 249, 215),
		Color3.fromRGB(255, 183, 105),
		Color3.fromRGB(75, 37, 38),
		0.13
	)

	local preview = resolveNativePanel(
		card,
		"Preview",
		0.025,
		0.08,
		0.2,
		0.84,
		14,
		Color3.fromRGB(122, 68, 191),
		Color3.fromRGB(206, 115, 255),
		Color3.fromRGB(85, 45, 169),
		Color3.fromRGB(63, 31, 74),
		0.18
	)
	resolveNativePanel(
		preview,
		"CrateBody",
		0.17,
		0.31,
		0.66,
		0.48,
		15,
		Color3.fromRGB(255, 165, 43),
		Color3.fromRGB(255, 221, 89),
		Color3.fromRGB(239, 96, 52),
		Color3.fromRGB(69, 36, 38),
		0.12
	)
	local lid = resolveNativePanel(
		preview,
		"CrateLid",
		0.1,
		0.23,
		0.8,
		0.2,
		16,
		Color3.fromRGB(91, 226, 205),
		Color3.fromRGB(174, 255, 225),
		Color3.fromRGB(42, 177, 175),
		Color3.fromRGB(55, 42, 48),
		0.18
	)
	lid.Rotation = -3
	local glyph = resolveText(preview, "Glyph", "?", 0.3, 0.36, 0.4, 0.38, 18, 38, 17, Enum.TextXAlignment.Center)
	glyph.TextColor3 = Color3.fromRGB(74, 37, 51)
	local previewLabel = resolveText(
		preview,
		"PreviewLabel",
		"MYSTERY DROP",
		0.1,
		0.78,
		0.8,
		0.14,
		8,
		12,
		17,
		Enum.TextXAlignment.Center
	)
	previewLabel.TextColor3 = Color3.fromRGB(255, 250, 226)

	local badge = resolveNativePanel(
		card,
		"BadgeChip",
		0.245,
		0.08,
		0.2,
		0.17,
		14,
		Color3.fromRGB(255, 82, 157),
		Color3.fromRGB(255, 143, 198),
		Color3.fromRGB(225, 55, 135),
		Color3.fromRGB(89, 43, 56),
		0.4
	)
	badge.BackgroundTransparency = 0
	local badgeLabel =
		resolveText(card, "Badge", "CRATE DROP", 0.255, 0.095, 0.18, 0.13, 8, 12, 15, Enum.TextXAlignment.Center)
	badgeLabel.TextColor3 = Color3.fromRGB(255, 247, 224)
	resolveText(card, "ItemName", "Crate", 0.245, 0.25, 0.43, 0.22, 13, 24, 14, nil)
	local highlight = resolveText(card, "Highlight", "Featured cosmetic", 0.245, 0.47, 0.44, 0.17, 9, 15, 14, nil)
	highlight.TextColor3 = Color3.fromRGB(106, 53, 57)
	local odds = resolveText(card, "Odds", "Odds", 0.245, 0.67, 0.49, 0.17, 8, 13, 14, nil)
	odds.TextColor3 = Color3.fromRGB(92, 57, 57)

	local existingMount = card:FindFirstChild("ActionMount")
	local actionMount: Frame
	if existingMount then
		assert(existingMount:IsA("Frame"), "[UIResolver] CrateCard.ActionMount must be a Frame")
		actionMount = existingMount
	else
		actionMount = Instance.new("Frame")
		actionMount.Name = "ActionMount"
		actionMount.Parent = card
	end
	actionMount.BackgroundTransparency = 1
	topLeft(actionMount, 0.72, 0.27, 0.25, 0.48, 14)
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is an
-- Assets.UI.Templates.CrateCard CanvasGroup with Preview/CrateBody/CrateLid,
-- Glyph, PreviewLabel, BadgeChip, Badge, ItemName, Highlight, Odds, and ActionMount.
local function resolveCrateCardTemplate(templates: Instance): CanvasGroup
	local authored = templates:FindFirstChild("CrateCard")
	local card: CanvasGroup
	if authored then
		assert(authored:IsA("CanvasGroup"), "[UIResolver] Assets.UI.Templates.CrateCard must be a CanvasGroup")
		card = authored
	else
		card = Instance.new("CanvasGroup")
		card.Name = "CrateCard"
		card.Parent = templates
	end
	populateCrateCard(card)
	return card
end

local function resolveInventoryTab(parent: Instance, name: string, labelText: string, order: number): TextButton
	local existing = parent:FindFirstChild(name)
	local button: TextButton
	if existing then
		assert(existing:IsA("TextButton"), `[UIResolver] Inventory.Tabs.{name} must be a TextButton`)
		button = existing
	else
		button = Instance.new("TextButton")
		button.Name = name
		button.Parent = parent
	end
	button.AnchorPoint = Vector2.zero
	button.AutoButtonColor = false
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.LayoutOrder = order
	button.Position = UDim2.fromScale(0, 0)
	button.Size = UDim2.fromScale(0.19, 0.78)
	button.Text = ""
	button.Visible = true
	button.ZIndex = 14
	styleNativePanel(
		button,
		Color3.fromRGB(242, 232, 189),
		Color3.fromRGB(255, 249, 218),
		Color3.fromRGB(222, 196, 138),
		Color3.fromRGB(63, 70, 43),
		0.3
	)
	local label = resolveText(button, "Label", labelText, 0.06, 0.08, 0.88, 0.84, 8, 15, 15, Enum.TextXAlignment.Center)
	label.TextColor3 = Color3.fromRGB(54, 46, 34)
	return button
end

local function populateNotificationBadge(badge: ImageLabel)
	styleImage(badge, NOTIFICATION_IMAGE, 1.2581, 0.5, 0.5, 0.24, 0.24, 20, nil)
	centered(badge, 0.5, 0.5, 0.24, 0.24, 20)
	badge.Visible = false
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is an
-- Assets.UI.Templates.NotificationBadge ImageLabel with AspectRatio.
local function resolveNotificationTemplate(templates: Instance): ImageLabel
	local authored = templates:FindFirstChild("NotificationBadge")
	local badge: ImageLabel
	if authored then
		assert(authored:IsA("ImageLabel"), "[UIResolver] Assets.UI.Templates.NotificationBadge must be an ImageLabel")
		badge = authored
	else
		badge = Instance.new("ImageLabel")
		badge.Name = "NotificationBadge"
		badge.Parent = templates
	end
	populateNotificationBadge(badge)
	return badge
end

local function populateLeaderboardRow(row: ImageLabel)
	styleImage(row, LEADERBOARD_ROW_IMAGE, 1.6265, 0, 0, 0.61, 0.46, 13, nil)
	row.Visible = false
	local badge = resolveImage(row, "RankBadge", "", 1, 0.08, 0.49, 0.34, 0.58, 15, nil)
	centered(badge, 0.08, 0.49, 0.34, 0.58, 15)
	resolveText(row, "PlayerName", "Player", 0.26, 0.15, 0.46, 0.31, 13, 23, 14, nil)
	local caption =
		resolveText(row, "ScoreCaption", "SCORE", 0.71, 0.13, 0.16, 0.2, 9, 14, 14, Enum.TextXAlignment.Right)
	caption.TextColor3 = MUTED_TEXT
	resolveText(row, "Score", "0", 0.68, 0.34, 0.2, 0.29, 15, 26, 14, Enum.TextXAlignment.Right)
	local elims = resolveText(row, "Elims", "0 elims", 0.29, 0.55, 0.38, 0.2, 10, 17, 14, nil)
	elims.TextColor3 = MUTED_TEXT
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is an
-- Assets.UI.Templates.LeaderboardRow ImageLabel with RankBadge, PlayerName,
-- ScoreCaption, Score, Elims, and AspectRatio children matching this fallback.
local function resolveLeaderboardRowTemplate(templates: Instance): ImageLabel
	local authored = templates:FindFirstChild("LeaderboardRow")
	local row: ImageLabel
	if authored then
		assert(authored:IsA("ImageLabel"), "[UIResolver] Assets.UI.Templates.LeaderboardRow must be an ImageLabel")
		row = authored
	else
		row = Instance.new("ImageLabel")
		row.Name = "LeaderboardRow"
		row.Parent = templates
	end
	populateLeaderboardRow(row)
	return row
end

local function populateShop(view: CanvasGroup)
	styleMenuRoot(view, SHOP_ASPECT)
	local legacyTitle = view:FindFirstChild("Title")
	if legacyTitle and legacyTitle:IsA("GuiObject") then
		legacyTitle.Visible = false
	end
	resolveImage(view, "Background", SHOP_IMAGE, SHOP_ASPECT, 0, 0, 1, 1, 10, nil)
	hideLegacyGui(view, "StatusPlate")
	hideLegacyGui(view, "CashPlate")
	resolveNativePanel(
		view,
		"StatusCard",
		0.09,
		0.2,
		0.44,
		0.12,
		11,
		Color3.fromRGB(255, 238, 220),
		Color3.fromRGB(255, 249, 235),
		Color3.fromRGB(255, 204, 198),
		Color3.fromRGB(92, 43, 52),
		0.28
	)
	resolveAccent(view, "StatusAccent", Color3.fromRGB(255, 75, 153), 0.112, 0.228, 0.012, 0.06)
	resolveNativePanel(
		view,
		"CashCard",
		0.67,
		0.19,
		0.22,
		0.13,
		11,
		Color3.fromRGB(255, 204, 65),
		Color3.fromRGB(255, 231, 120),
		Color3.fromRGB(244, 168, 49),
		Color3.fromRGB(80, 46, 35),
		0.28
	)
	local contentWell = resolveNativePanel(
		view,
		"ContentWell",
		0.065,
		0.34,
		0.87,
		0.59,
		11,
		Color3.fromRGB(171, 19, 89),
		Color3.fromRGB(255, 100, 178),
		Color3.fromRGB(140, 10, 75),
		Color3.fromRGB(255, 188, 224),
		0.07
	)
	contentWell.BackgroundTransparency = 0.42
	local promo = resolveNativePanel(
		view,
		"PromoStrip",
		0.09,
		0.355,
		0.82,
		0.1,
		12,
		Color3.fromRGB(105, 51, 151),
		Color3.fromRGB(183, 93, 220),
		Color3.fromRGB(75, 38, 132),
		Color3.fromRGB(255, 188, 224),
		0.18
	)
	promo.BackgroundTransparency = 0.05
	local promoTitle = resolveText(view, "PromoTitle", "FRESH DROPS", 0.115, 0.372, 0.25, 0.065, 11, 20, 13, nil)
	promoTitle.TextColor3 = Color3.fromRGB(255, 248, 219)
	local promoDetail = resolveText(
		view,
		"PromoDetail",
		"COSMETICS ONLY  •  NO GAMEPLAY ADVANTAGE",
		0.36,
		0.372,
		0.52,
		0.065,
		8,
		14,
		13,
		Enum.TextXAlignment.Right
	)
	promoDetail.TextColor3 = Color3.fromRGB(255, 226, 242)

	local featuredMount = resolveContainer(view, "FeaturedMount", 0.09, 0.475, 0.82, 0.22, 12)
	featuredMount.ClipsDescendants = false
	local shelfTitle = resolveText(view, "ShelfTitle", "MORE CRATES", 0.1, 0.71, 0.46, 0.05, 9, 14, 13, nil)
	shelfTitle.TextColor3 = Color3.fromRGB(255, 235, 218)
	resolveCrateShelf(view, 0.09, 0.765, 0.5, 0.14)

	local passTeaser = resolveNativePanel(
		view,
		"PassTeaser",
		0.62,
		0.71,
		0.29,
		0.195,
		12,
		Color3.fromRGB(46, 177, 202),
		Color3.fromRGB(96, 227, 231),
		Color3.fromRGB(44, 126, 192),
		Color3.fromRGB(47, 45, 72),
		0.16
	)
	passTeaser.BackgroundTransparency = 0.03
	local passTitle =
		resolveText(view, "PassTitle", "GAME PASSES", 0.65, 0.735, 0.23, 0.065, 10, 17, 13, Enum.TextXAlignment.Center)
	passTitle.TextColor3 = Color3.fromRGB(31, 45, 63)
	local passStatus = resolveText(
		view,
		"PassStatus",
		"NEW COLLECTIONS\nCOMING SOON",
		0.65,
		0.8,
		0.23,
		0.08,
		8,
		13,
		13,
		Enum.TextXAlignment.Center
	)
	passStatus.TextColor3 = Color3.fromRGB(39, 55, 71)
	local cash =
		resolveText(view, "Cash", "Cash: loading", 0.69, 0.212, 0.18, 0.078, 12, 20, 12, Enum.TextXAlignment.Center)
	cash.TextColor3 = Color3.fromRGB(48, 32, 20)
	resolveText(
		view,
		"Status",
		"Economy data is loading.",
		0.145,
		0.215,
		0.34,
		0.078,
		10,
		17,
		12,
		Enum.TextXAlignment.Center
	)
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is a
-- MainGui.BaseClip.Views.Shop CanvasGroup with Background, StatusCard,
-- StatusAccent, CashCard, ContentWell, PromoStrip, PromoTitle, PromoDetail,
-- FeaturedMount, ShelfTitle, Holder/Shelf, PassTeaser, PassTitle, PassStatus,
-- Cash, and Status.
local function resolveShopView(views: Instance): CanvasGroup
	local authored = views:FindFirstChild("Shop")
	local view: CanvasGroup
	if authored then
		assert(authored:IsA("CanvasGroup"), "[UIResolver] Views.Shop must be a CanvasGroup")
		view = authored
	else
		view = buildMenuRoot(views, "Shop")
	end
	populateShop(view)
	return view
end

local function populateInventory(view: CanvasGroup)
	styleMenuRoot(view, SHOP_ASPECT)
	local legacyTitle = view:FindFirstChild("Title")
	if legacyTitle and legacyTitle:IsA("GuiObject") then
		legacyTitle.Visible = false
	end
	for _, legacyName in
		{
			"Background",
			"StatusPlate",
			"StatusCard",
			"StatusAccent",
			"ContentWell",
			"Status",
			"Holder",
			"Tabs",
		}
	do
		hideLegacyGui(view, legacyName)
	end

	local panel = resolveContainer(view, "PanelBounds", 0, 0, INVENTORY_PANEL_WIDTH, 1, 10)
	centered(panel, 0.5, 0.5, INVENTORY_PANEL_WIDTH, 1, 10)
	panel.ClipsDescendants = true
	ensureAspect(panel, INVENTORY_ART_ASPECT)
	resolveImage(
		panel,
		"Background",
		INVENTORY_IMAGE,
		INVENTORY_NATIVE_ASPECT,
		INVENTORY_IMAGE_X,
		INVENTORY_IMAGE_Y,
		INVENTORY_IMAGE_WIDTH,
		INVENTORY_IMAGE_HEIGHT,
		10,
		nil
	)
	local statusCard = resolveNativePanel(
		panel,
		"StatusCard",
		0.16,
		0.18,
		0.68,
		0.115,
		11,
		Color3.fromRGB(241, 255, 221),
		Color3.fromRGB(253, 255, 239),
		Color3.fromRGB(204, 245, 157),
		Color3.fromRGB(52, 75, 38),
		0.28
	)
	local statusAccent = resolveAccent(panel, "StatusAccent", Color3.fromRGB(106, 210, 62), 0.185, 0.205, 0.012, 0.06)
	local status = resolveText(
		panel,
		"Status",
		"Inventory data is loading.",
		0.22,
		0.198,
		0.56,
		0.075,
		10,
		17,
		12,
		Enum.TextXAlignment.Center
	)

	local tabs = resolveNativePanel(
		panel,
		"Tabs",
		0.075,
		0.315,
		0.85,
		0.105,
		12,
		Color3.fromRGB(74, 131, 45),
		Color3.fromRGB(129, 198, 69),
		Color3.fromRGB(56, 103, 42),
		Color3.fromRGB(217, 255, 174),
		0.2
	)
	tabs.BackgroundTransparency = 0.12
	tabs.ClipsDescendants = false
	local oldGrid = tabs:FindFirstChildWhichIsA("UIGridLayout")
	if oldGrid then
		oldGrid:Destroy()
	end
	local existingLayout = tabs:FindFirstChild("Layout") or tabs:FindFirstChildWhichIsA("UIListLayout")
	local tabLayout: UIListLayout
	if existingLayout then
		assert(existingLayout:IsA("UIListLayout"), "[UIResolver] Inventory.Tabs.Layout must be a UIListLayout")
		tabLayout = existingLayout
		tabLayout.Name = "Layout"
	else
		tabLayout = Instance.new("UIListLayout")
		tabLayout.Name = "Layout"
		tabLayout.Parent = tabs
	end
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.Padding = UDim.new(0.012, 0)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	for order, definition in INVENTORY_TABS do
		resolveInventoryTab(tabs, definition.id, definition.label, order)
	end

	local contentWell = resolveNativePanel(
		panel,
		"ContentWell",
		0.065,
		0.44,
		0.87,
		0.475,
		11,
		Color3.fromRGB(109, 180, 42),
		Color3.fromRGB(187, 250, 104),
		Color3.fromRGB(71, 151, 43),
		Color3.fromRGB(225, 255, 177),
		0.07
	)
	contentWell.BackgroundTransparency = 0.46
	local categoryTitle =
		resolveText(contentWell, "CategoryTitle", "DODGEBALLS", 0.04, 0.025, 0.52, 0.12, 11, 19, 13, nil)
	categoryTitle.TextColor3 = Color3.fromRGB(242, 255, 218)
	local itemCount =
		resolveText(contentWell, "ItemCount", "0 ITEMS", 0.66, 0.025, 0.29, 0.12, 9, 14, 13, Enum.TextXAlignment.Right)
	itemCount.TextColor3 = Color3.fromRGB(225, 255, 191)
	resolveEconomyHolder(contentWell, 0.025, 0.155, 0.95, 0.815)
	local empty = resolveText(
		contentWell,
		"Empty",
		"No owned items in this category yet.",
		0.18,
		0.39,
		0.64,
		0.22,
		11,
		18,
		14,
		Enum.TextXAlignment.Center
	)
	empty.TextColor3 = Color3.fromRGB(237, 255, 213)
	empty.Visible = false

	local function refreshLayout()
		local compact = panel.AbsoluteSize.X > 0 and panel.AbsoluteSize.X < 600
		if compact then
			topLeft(statusCard, 0.12, 0.16, 0.76, 0.13, 11)
			topLeft(statusAccent, 0.15, 0.193, 0.014, 0.064, 15)
			topLeft(status, 0.19, 0.18, 0.62, 0.09, 12)
			topLeft(tabs, 0.06, 0.305, 0.88, 0.18, 12)
			topLeft(contentWell, 0.055, 0.505, 0.89, 0.405, 11)
		else
			topLeft(statusCard, 0.16, 0.18, 0.68, 0.115, 11)
			topLeft(statusAccent, 0.185, 0.205, 0.012, 0.06, 15)
			topLeft(status, 0.22, 0.198, 0.56, 0.075, 12)
			topLeft(tabs, 0.075, 0.315, 0.85, 0.105, 12)
			topLeft(contentWell, 0.065, 0.44, 0.87, 0.475, 11)
		end
	end
	refreshLayout()
	local connection = panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshLayout)
	table.insert(cleanups, function()
		connection:Disconnect()
	end)
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is a
-- MainGui.BaseClip.Views.Inventory CanvasGroup with a clipped PanelBounds Frame.
-- PanelBounds contains the full native Background image, StatusCard/StatusAccent/
-- Status, Tabs with the five category TextButtons, and ContentWell containing
-- CategoryTitle, ItemCount, Empty, and Holder/Grid.
local function resolveInventoryView(views: Instance): CanvasGroup
	local authored = views:FindFirstChild("Inventory")
	local view: CanvasGroup
	if authored then
		assert(authored:IsA("CanvasGroup"), "[UIResolver] Views.Inventory must be a CanvasGroup")
		view = authored
	else
		view = buildMenuRoot(views, "Inventory")
	end
	populateInventory(view)
	return view
end

local function populateLeaderboard(view: CanvasGroup)
	styleMenuRoot(view, 0.8149)
	resolveImage(view, "Background", LEADERBOARD_IMAGE, 0.8149, 0, 0, 1, 1, 10, nil)
	hideLegacyGui(view, "StatusPlate")
	resolveNativePanel(
		view,
		"StatusCard",
		0.18,
		0.15,
		0.64,
		0.14,
		11,
		Color3.fromRGB(255, 239, 184),
		Color3.fromRGB(255, 249, 219),
		Color3.fromRGB(255, 210, 104),
		Color3.fromRGB(87, 54, 35),
		0.3
	)
	resolveText(
		view,
		"Status",
		"Results appear after each match",
		0.23,
		0.177,
		0.54,
		0.085,
		10,
		17,
		12,
		Enum.TextXAlignment.Center
	)
	resolveListHolder(view, 0.08, 0.33, 0.84, 0.56, 0.025)
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is a
-- MainGui.BaseClip.Views.Leaderboard CanvasGroup with Background, StatusCard,
-- Status, Holder, and Holder.List matching this fallback.
local function resolveLeaderboardView(views: Instance): CanvasGroup
	local authored = views:FindFirstChild("Leaderboard")
	local view: CanvasGroup
	if authored then
		assert(authored:IsA("CanvasGroup"), "[UIResolver] Views.Leaderboard must be a CanvasGroup")
		view = authored
	else
		view = buildMenuRoot(views, "Leaderboard")
	end
	populateLeaderboard(view)
	return view
end

local function populateSettings(view: CanvasGroup)
	styleMenuRoot(view, 0.8242)
	resolveImage(view, "Background", SETTINGS_IMAGE, 0.8242, 0, 0, 1, 1, 10, nil)
	hideLegacyGui(view, "MessageCard")
	resolveNativePanel(
		view,
		"MessagePanel",
		0.15,
		0.37,
		0.7,
		0.26,
		11,
		Color3.fromRGB(224, 251, 255),
		Color3.fromRGB(246, 255, 255),
		Color3.fromRGB(139, 225, 240),
		Color3.fromRGB(42, 78, 88),
		0.13
	)
	resolveAccent(view, "MessageAccent", Color3.fromRGB(37, 190, 218), 0.2, 0.42, 0.018, 0.16)
	resolveText(
		view,
		"Message",
		"More settings coming soon",
		0.25,
		0.425,
		0.5,
		0.15,
		12,
		22,
		12,
		Enum.TextXAlignment.Center
	)
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is a
-- MainGui.BaseClip.Views.Settings CanvasGroup with Background, MessagePanel,
-- MessageAccent, Message, and AspectRatio.
local function resolveSettingsView(views: Instance): CanvasGroup
	local authored = views:FindFirstChild("Settings")
	local view: CanvasGroup
	if authored then
		assert(authored:IsA("CanvasGroup"), "[UIResolver] Views.Settings must be a CanvasGroup")
		view = authored
	else
		view = buildMenuRoot(views, "Settings")
	end
	populateSettings(view)
	return view
end

local LIVE_RANK_COLORS = {
	Color3.fromRGB(255, 199, 58),
	Color3.fromRGB(82, 211, 210),
	Color3.fromRGB(238, 111, 168),
}

local function resolveLiveScoreRow(
	parent: Instance,
	name: string,
	y: number,
	height: number,
	accentColor: Color3,
	zIndex: number
): Frame
	local row = resolveNativePanel(
		parent,
		name,
		0,
		y,
		1,
		height,
		zIndex,
		Color3.fromRGB(23, 27, 52),
		Color3.fromRGB(42, 47, 82),
		Color3.fromRGB(18, 21, 42),
		Color3.fromRGB(8, 10, 25),
		0.18
	)
	row.BackgroundTransparency = 0.42
	local rowOutline = row:FindFirstChild("Outline")
	assert(rowOutline and rowOutline:IsA("UIStroke"), `[UIResolver] {row.Name}.Outline must be a UIStroke`)
	rowOutline.Transparency = 0.62

	local accent = resolveAccent(row, "Accent", accentColor, 0.012, 0.13, 0.012, 0.74)
	accent.ZIndex = zIndex + 2

	local rankMount = resolveContainer(row, "RankMount", 0.035, 0.11, 0.13, 0.78, zIndex + 1)
	local rankBubble = resolveNativePanel(
		rankMount,
		"Bubble",
		0,
		0,
		1,
		1,
		zIndex + 2,
		accentColor,
		accentColor:Lerp(Color3.new(1, 1, 1), 0.2),
		accentColor:Lerp(Color3.new(0, 0, 0), 0.18),
		Color3.fromRGB(8, 10, 25),
		0.5
	)
	centered(rankBubble, 0.5, 0.5, 1, 1, zIndex + 2)
	ensureAspect(rankBubble, 1)
	local rank = resolveText(rankBubble, "Rank", "1", 0, 0, 1, 1, 11, 19, zIndex + 3, Enum.TextXAlignment.Center)
	rank.TextColor3 = Color3.fromRGB(19, 17, 28)

	local playerName = resolveText(row, "PlayerName", "Player", 0.19, 0.1, 0.48, 0.46, 11, 19, zIndex + 2, nil)
	playerName.TextColor3 = Color3.fromRGB(250, 248, 239)
	playerName.TextTruncate = Enum.TextTruncate.AtEnd
	playerName.TextWrapped = false

	local youPill = resolveNativePanel(
		row,
		"YouPill",
		0.19,
		0.55,
		0.17,
		0.25,
		zIndex + 2,
		Color3.fromRGB(81, 230, 197),
		Color3.fromRGB(116, 250, 216),
		Color3.fromRGB(38, 184, 169),
		Color3.fromRGB(8, 10, 25),
		0.5
	)
	local you = resolveText(youPill, "Label", "YOU", 0, 0, 1, 1, 8, 12, zIndex + 3, Enum.TextXAlignment.Center)
	you.TextColor3 = Color3.fromRGB(15, 29, 38)
	youPill.Visible = false

	local score = resolveText(row, "Score", "0", 0.72, 0.08, 0.23, 0.5, 15, 25, zIndex + 2, Enum.TextXAlignment.Right)
	score.TextColor3 = Color3.fromRGB(255, 247, 205)
	local caption =
		resolveText(row, "ScoreCaption", "ELIMS", 0.72, 0.53, 0.23, 0.25, 8, 11, zIndex + 2, Enum.TextXAlignment.Right)
	caption.TextColor3 = Color3.fromRGB(178, 187, 214)

	local progress = resolveAccent(row, "Progress", Color3.fromRGB(10, 13, 31), 0.39, 0.67, 0.28, 0.09)
	progress.BackgroundTransparency = 0.18
	progress.ClipsDescendants = true
	progress.ZIndex = zIndex + 2
	local fill = resolveAccent(progress, "Fill", accentColor, 0, 0, 0, 1)
	fill.ZIndex = zIndex + 3
	return row
end

local function resolveFfaScoreboard(shell: Frame, zIndex: number): Frame
	local panel = resolveContainer(shell, "FFA", 0.035, 0.25, 0.93, 0.715, zIndex)
	local rowCount = uiConfig().Hud.LiveScoreboard.FfaRows
	local rowHeight = 0.205
	local gap = 0.027
	for rank = 1, rowCount do
		resolveLiveScoreRow(
			panel,
			`Row{rank}`,
			(rank - 1) * (rowHeight + gap),
			rowHeight,
			LIVE_RANK_COLORS[rank] or LIVE_RANK_COLORS[#LIVE_RANK_COLORS],
			zIndex + 1
		)
	end
	resolveLiveScoreRow(panel, "LocalRow", 0.735, rowHeight, Color3.fromRGB(81, 230, 197), zIndex + 1)
	return panel
end

local function resolveTeamPanel(parent: Instance, name: string, x: number, color: Color3, zIndex: number): Frame
	local panel = resolveNativePanel(
		parent,
		name,
		x,
		0,
		0.485,
		1,
		zIndex,
		color:Lerp(Color3.fromRGB(15, 18, 39), 0.72),
		color:Lerp(Color3.fromRGB(54, 60, 94), 0.55),
		Color3.fromRGB(17, 20, 42),
		color:Lerp(Color3.fromRGB(255, 255, 255), 0.2),
		0.1
	)
	panel.BackgroundTransparency = 0.48
	local panelOutline = panel:FindFirstChild("Outline")
	assert(panelOutline and panelOutline:IsA("UIStroke"), `[UIResolver] {panel.Name}.Outline must be a UIStroke`)
	panelOutline.Transparency = 0.6
	local marker = resolveAccent(panel, "Marker", color, 0.04, 0.055, 0.04, 0.25)
	marker.ZIndex = zIndex + 2
	local teamName = resolveText(panel, "TeamName", "RED", 0.11, 0.035, 0.5, 0.16, 10, 17, zIndex + 2, nil)
	teamName.TextColor3 = Color3.fromRGB(250, 248, 239)
	local score =
		resolveText(panel, "Score", "0", 0.63, 0.025, 0.28, 0.22, 18, 30, zIndex + 2, Enum.TextXAlignment.Right)
	score.TextColor3 = color:Lerp(Color3.fromRGB(255, 255, 255), 0.3)
	local target =
		resolveText(panel, "Target", "/ 40", 0.64, 0.215, 0.27, 0.1, 8, 11, zIndex + 2, Enum.TextXAlignment.Right)
	target.TextColor3 = Color3.fromRGB(188, 193, 214)

	local progress = resolveAccent(panel, "Progress", Color3.fromRGB(9, 12, 29), 0.06, 0.31, 0.88, 0.035)
	progress.BackgroundTransparency = 0.15
	progress.ClipsDescendants = true
	progress.ZIndex = zIndex + 2
	local fill = resolveAccent(progress, "Fill", color, 0, 0, 0, 1)
	fill.ZIndex = zIndex + 3

	local rows = resolveContainer(panel, "Rows", 0.055, 0.39, 0.89, 0.56, zIndex + 1)
	local rowCount = uiConfig().Hud.LiveScoreboard.TeamRows
	local rowHeight = 0.45
	for rank = 1, rowCount do
		resolveLiveScoreRow(rows, `Row{rank}`, (rank - 1) * 0.52, rowHeight, color, zIndex + 2)
	end
	return panel
end

local function resolveTeamScoreboard(shell: Frame, zIndex: number): Frame
	local panel = resolveContainer(shell, "Teams", 0.035, 0.25, 0.93, 0.715, zIndex)
	resolveTeamPanel(panel, "TeamA", 0, Color3.fromRGB(255, 83, 110), zIndex + 1)
	resolveTeamPanel(panel, "TeamB", 0.515, Color3.fromRGB(72, 166, 255), zIndex + 1)
	panel.Visible = false
	return panel
end

local function populateLiveScoreboard(view: CanvasGroup, hud: ScreenGui)
	view.AnchorPoint = Vector2.new(1, 0)
	view.BackgroundTransparency = 1
	view.ClipsDescendants = false
	view.GroupTransparency = 0
	view.Position = UDim2.fromScale(0.985, 0.09)
	view.Size = UDim2.fromScale(0.275, 0.36)
	view.Visible = false
	view.ZIndex = 30
	local viewAspect = ensureAspect(view, 1.28)

	local shadow = resolveNativePanel(
		view,
		"Shadow",
		0.018,
		0.025,
		0.982,
		0.975,
		30,
		Color3.fromRGB(3, 5, 17),
		Color3.fromRGB(3, 5, 17),
		Color3.fromRGB(3, 5, 17),
		Color3.fromRGB(3, 5, 17),
		0.065
	)
	shadow.Visible = false

	local shell = resolveNativePanel(
		view,
		"Shell",
		0,
		0,
		0.982,
		0.975,
		31,
		Color3.fromRGB(16, 19, 42),
		Color3.fromRGB(44, 50, 91),
		Color3.fromRGB(12, 15, 34),
		Color3.fromRGB(248, 232, 177),
		0.065
	)
	shell.BackgroundTransparency = 1
	shell.ClipsDescendants = false
	local shellOutline = shell:FindFirstChild("Outline")
	assert(
		shellOutline and shellOutline:IsA("UIStroke"),
		"[UIResolver] LiveScoreboard.Shell.Outline must be a UIStroke"
	)
	shellOutline.Transparency = 1

	local header = resolveNativePanel(
		shell,
		"Header",
		0.035,
		0.035,
		0.93,
		0.18,
		32,
		Color3.fromRGB(21, 121, 139),
		Color3.fromRGB(56, 218, 199),
		Color3.fromRGB(17, 86, 125),
		Color3.fromRGB(8, 10, 25),
		0.24
	)
	header.BackgroundTransparency = 0.38
	local headerOutline = header:FindFirstChild("Outline")
	assert(
		headerOutline and headerOutline:IsA("UIStroke"),
		"[UIResolver] LiveScoreboard.Header.Outline must be a UIStroke"
	)
	headerOutline.Transparency = 0.58
	local live = resolveNativePanel(
		header,
		"LivePill",
		0.035,
		0.18,
		0.18,
		0.64,
		33,
		Color3.fromRGB(255, 94, 126),
		Color3.fromRGB(255, 137, 104),
		Color3.fromRGB(226, 49, 112),
		Color3.fromRGB(8, 10, 25),
		0.5
	)
	live.BackgroundTransparency = 0.18
	local liveText = resolveText(live, "Label", "LIVE", 0, 0, 1, 1, 9, 13, 34, Enum.TextXAlignment.Center)
	liveText.TextColor3 = Color3.fromRGB(255, 251, 230)
	local title = resolveText(header, "Title", "STANDINGS", 0.245, 0.12, 0.45, 0.44, 11, 20, 34, nil)
	title.TextColor3 = Color3.fromRGB(255, 252, 230)
	local goal =
		resolveText(header, "Goal", "FIRST TO 15", 0.57, 0.54, 0.38, 0.28, 8, 12, 34, Enum.TextXAlignment.Right)
	goal.TextColor3 = Color3.fromRGB(215, 255, 241)

	resolveFfaScoreboard(shell, 32)
	resolveTeamScoreboard(shell, 32)

	local function refreshLayout()
		local viewport = hud.AbsoluteSize
		local portrait = viewport.Y > viewport.X
		local compactLandscape = not portrait and (viewport.X < 1100 or viewport.Y < 720)
		if portrait then
			viewAspect.AspectRatio = 1.55
			view.Position = UDim2.fromScale(0.985, 0.09)
			view.Size = UDim2.fromScale(0.92, 0.3)
		elseif compactLandscape then
			viewAspect.AspectRatio = 1.45
			view.Position = UDim2.fromScale(0.985, 0.11)
			view.Size = UDim2.fromScale(0.38, 0.55)
		else
			viewAspect.AspectRatio = 1.35
			view.Position = UDim2.fromScale(0.985, 0.085)
			view.Size = UDim2.fromScale(0.225, 0.3)
		end
	end
	refreshLayout()
	local connection = hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshLayout)
	table.insert(cleanups, function()
		connection:Disconnect()
	end)
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is a
-- Hud.LiveScoreboard CanvasGroup with Shadow and Shell. Shell contains Header,
-- FFA rows, and mirrored Teams.TeamA/TeamB score panels with fixed row slots.
local function resolveLiveScoreboard(hud: ScreenGui): CanvasGroup
	local authored = hud:FindFirstChild("LiveScoreboard")
	local view: CanvasGroup
	if authored then
		assert(authored:IsA("CanvasGroup"), "[UIResolver] Hud.LiveScoreboard must be a CanvasGroup")
		view = authored
	else
		view = Instance.new("CanvasGroup")
		view.Name = "LiveScoreboard"
		view.Parent = hud
	end
	populateLiveScoreboard(view, hud)
	return view
end

function UIResolver.mount()
	if mounted then
		return
	end
	mounted = true
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local views = playerGui:WaitForChild("MainGui"):WaitForChild("BaseClip"):WaitForChild("Views")
	local hud = playerGui:WaitForChild("Hud")
	assert(hud:IsA("ScreenGui"), "[UIResolver] PlayerGui.Hud must be a ScreenGui")
	local templates = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI"):WaitForChild("Templates")

	resolveButtonTemplate(templates)
	resolveEconomyItemTemplate(templates)
	resolveCrateCardTemplate(templates)
	resolveNotificationTemplate(templates)
	resolveLeaderboardRowTemplate(templates)
	resolveShopView(views)
	resolveInventoryView(views)
	resolveLeaderboardView(views)
	resolveSettingsView(views)
	resolveLiveScoreboard(hud)
end

return UIResolver
