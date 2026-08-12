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
local STORE_OFFER_CARD_ASPECT = 2.05
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

local function resolveOfferShelf(parent: Instance, x: number, y: number, width: number, height: number): ScrollingFrame
	local existing = parent:FindFirstChild("OffersHolder")
	local holder: ScrollingFrame
	if existing then
		assert(existing:IsA("ScrollingFrame"), `[UIResolver] {parent.Name}.OffersHolder must be a ScrollingFrame`)
		holder = existing
	else
		holder = Instance.new("ScrollingFrame")
		holder.Name = "OffersHolder"
		holder.Parent = parent
	end
	styleScroll(holder, x, y, width, height)
	holder.AutomaticCanvasSize = Enum.AutomaticSize.X
	holder.ScrollingDirection = Enum.ScrollingDirection.X
	holder.ScrollBarThickness = 3

	local existingLayout = holder:FindFirstChild("OfferShelf") or holder:FindFirstChildWhichIsA("UIListLayout")
	local layout: UIListLayout
	if existingLayout then
		assert(
			existingLayout:IsA("UIListLayout"),
			`[UIResolver] {parent.Name}.OffersHolder.OfferShelf must be a UIListLayout`
		)
		layout = existingLayout
		layout.Name = "OfferShelf"
	else
		layout = Instance.new("UIListLayout")
		layout.Name = "OfferShelf"
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
	local odds = resolveText(card, "Odds", "Odds", 0.245, 0.67, 0.45, 0.17, 8, 13, 14, nil)
	odds.TextColor3 = Color3.fromRGB(92, 57, 57)

	for _, definition in
		{
			{ name = "CashActionMount", y = 0.12, height = 0.25 },
			{ name = "RobuxActionMount", y = 0.39, height = 0.25 },
			{ name = "DetailsActionMount", y = 0.69, height = 0.2 },
		}
	do
		local mount = resolveContainer(card, definition.name, 0.72, definition.y, 0.255, definition.height, 14)
		mount.BackgroundTransparency = 1
	end
	hideLegacyGui(card, "ActionMount")
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is an
-- Assets.UI.Templates.CrateCard CanvasGroup with its preview, copy, and three action mounts.
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

local function populateStoreOfferCard(card: CanvasGroup)
	card.AnchorPoint = Vector2.zero
	card.BackgroundTransparency = 0.02
	card.BorderSizePixel = 0
	card.ClipsDescendants = false
	card.GroupTransparency = 0
	card.Position = UDim2.fromScale(0, 0)
	card.Size = UDim2.fromScale(0.62, 0.92)
	card.ZIndex = 13
	card.Visible = false
	ensureAspect(card, STORE_OFFER_CARD_ASPECT)
	styleNativePanel(
		card,
		Color3.fromRGB(107, 60, 176),
		Color3.fromRGB(206, 111, 242),
		Color3.fromRGB(82, 45, 158),
		Color3.fromRGB(60, 35, 68),
		0.13
	)

	resolveAccent(card, "Accent", Color3.fromRGB(255, 112, 188), 0.025, 0.1, 0.018, 0.8)
	local iconWell = resolveNativePanel(
		card,
		"IconWell",
		0.07,
		0.15,
		0.24,
		0.7,
		14,
		Color3.fromRGB(69, 40, 126),
		Color3.fromRGB(110, 63, 172),
		Color3.fromRGB(50, 31, 104),
		Color3.fromRGB(48, 29, 55),
		0.2
	)
	ensureAspect(iconWell, 1)
	local icon = resolveImage(iconWell, "Icon", "", 1, 0.08, 0.08, 0.84, 0.84, 16, nil)
	icon.ScaleType = Enum.ScaleType.Fit
	local glyph = resolveText(card, "Glyph", "★", 0.08, 0.24, 0.22, 0.45, 18, 34, 16, Enum.TextXAlignment.Center)
	glyph.TextColor3 = Color3.fromRGB(255, 242, 182)

	local badgeChip = resolveNativePanel(
		card,
		"BadgeChip",
		0.35,
		0.1,
		0.34,
		0.17,
		14,
		Color3.fromRGB(255, 112, 188),
		Color3.fromRGB(255, 154, 207),
		Color3.fromRGB(225, 65, 153),
		Color3.fromRGB(67, 39, 65),
		0.45
	)
	badgeChip.BackgroundTransparency = 0.02
	local badge = resolveText(card, "Badge", "GAMEPASS", 0.36, 0.11, 0.32, 0.15, 8, 12, 15, Enum.TextXAlignment.Center)
	badge.TextColor3 = Color3.fromRGB(255, 249, 221)
	local title = resolveText(card, "ItemName", "Offer", 0.35, 0.27, 0.6, 0.22, 11, 21, 14, nil)
	title.TextColor3 = Color3.fromRGB(255, 249, 226)
	local details = resolveText(card, "Details", "Offer details", 0.35, 0.47, 0.59, 0.2, 8, 14, 14, nil)
	details.TextColor3 = Color3.fromRGB(255, 228, 238)

	local actionMount = resolveContainer(card, "ActionMount", 0.59, 0.64, 0.37, 0.3, 14)
	actionMount.BackgroundTransparency = 1
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is an
-- Assets.UI.Templates.StoreOfferCard CanvasGroup with Accent, IconWell/Icon,
-- Glyph, BadgeChip, Badge, ItemName, Details, ActionMount, and style children.
local function resolveStoreOfferCardTemplate(templates: Instance): CanvasGroup
	local authored = templates:FindFirstChild("StoreOfferCard")
	local card: CanvasGroup
	if authored then
		assert(authored:IsA("CanvasGroup"), "[UIResolver] Assets.UI.Templates.StoreOfferCard must be a CanvasGroup")
		card = authored
	else
		card = Instance.new("CanvasGroup")
		card.Name = "StoreOfferCard"
		card.Parent = templates
	end
	populateStoreOfferCard(card)
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
	local aspect = view:FindFirstChild("AspectRatio")
	if aspect then
		aspect:Destroy()
	end
	local shopSize = view:FindFirstChild("ShopSize")
	if shopSize == nil then
		shopSize = Instance.new("UISizeConstraint")
		shopSize.Name = "ShopSize"
		shopSize.Parent = view
	end
	assert(shopSize:IsA("UISizeConstraint"), "[UIResolver] Shop.ShopSize must be a UISizeConstraint")
	shopSize.MaxSize = Vector2.new(1360, 820)
	view.ClipsDescendants = true

	for _, name in
		{
			"Title",
			"StatusPlate",
			"CashPlate",
			"PassTeaser",
			"PassTitle",
			"PassStatus",
			"StatusCard",
			"StatusAccent",
			"CashCard",
			"ContentWell",
			"PromoStrip",
			"PromoTitle",
			"PromoDetail",
			"FeaturedMount",
			"ShelfTitle",
			"Holder",
			"OfferTitle",
			"OffersHolder",
			"CashActionMount",
			"Cash",
			"Status",
		}
	do
		hideLegacyGui(view, name)
	end

	local background = resolveImage(view, "Background", SHOP_IMAGE, SHOP_ASPECT, 0, 0, 1, 1, 10, nil)
	local backgroundAspect = background:FindFirstChild("AspectRatio")
	if backgroundAspect then
		backgroundAspect:Destroy()
	end
	background.ScaleType = Enum.ScaleType.Stretch

	local header = resolveNativePanel(
		view,
		"ShopHeader",
		0.035,
		0.035,
		0.93,
		0.215,
		11,
		Color3.fromRGB(255, 238, 220),
		Color3.fromRGB(255, 250, 235),
		Color3.fromRGB(255, 191, 204),
		Color3.fromRGB(92, 43, 52),
		0.08
	)
	local title = resolveText(header, "ShopTitle", "SPLAT SHOP", 0.025, 0.08, 0.25, 0.34, 16, 30, 13, nil)
	title.TextColor3 = Color3.fromRGB(91, 31, 65)
	local status = resolveText(header, "Status", "Economy data is loading.", 0.025, 0.4, 0.53, 0.18, 9, 15, 13, nil)
	status.TextColor3 = MUTED_TEXT
	local cashCard = resolveNativePanel(
		header,
		"CashCard",
		0.6,
		0.07,
		0.28,
		0.42,
		12,
		Color3.fromRGB(255, 204, 65),
		Color3.fromRGB(255, 235, 128),
		Color3.fromRGB(244, 168, 49),
		Color3.fromRGB(80, 46, 35),
		0.28
	)
	local cash =
		resolveText(cashCard, "Cash", "Cash: loading", 0.06, 0.08, 0.88, 0.84, 12, 21, 14, Enum.TextXAlignment.Center)
	cash.TextColor3 = Color3.fromRGB(48, 32, 20)

	local close = header:FindFirstChild("Close")
	if close == nil then
		close = Instance.new("TextButton")
		close.Name = "Close"
		close.Parent = header
	end
	assert(close:IsA("TextButton"), "[UIResolver] ShopHeader.Close must be a TextButton")
	close.AutoButtonColor = true
	close.BackgroundColor3 = Color3.fromRGB(220, 67, 112)
	close.BorderSizePixel = 0
	close.FontFace = uiConfig().Text.DefaultFont
	close.Text = "X"
	close.TextColor3 = Color3.fromRGB(255, 249, 226)
	close.TextScaled = true
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 12)
	close.Size = UDim2.fromOffset(48, 48)
	close.ZIndex = 14
	styleNativePanel(
		close,
		Color3.fromRGB(220, 67, 112),
		Color3.fromRGB(255, 114, 158),
		Color3.fromRGB(190, 44, 94),
		Color3.fromRGB(88, 38, 53),
		0.3
	)
	local closeSize = close:FindFirstChild("TouchSize")
	if closeSize == nil then
		closeSize = Instance.new("UISizeConstraint")
		closeSize.Name = "TouchSize"
		closeSize.Parent = close
	end
	assert(closeSize:IsA("UISizeConstraint"), "[UIResolver] ShopHeader.Close.TouchSize must be a UISizeConstraint")
	closeSize.MinSize = Vector2.new(44, 44)

	local tabs = resolveContainer(header, "JumpTabs", 0.025, 0.6, 0.95, 0.35, 13)
	local tabLayout = tabs:FindFirstChild("Layout")
	if tabLayout == nil then
		tabLayout = Instance.new("UIListLayout")
		tabLayout.Name = "Layout"
		tabLayout.Parent = tabs
	end
	assert(tabLayout:IsA("UIListLayout"), "[UIResolver] ShopHeader.JumpTabs.Layout must be a UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.Padding = UDim.new(0.012, 0)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local tabDefinitions = {
		{ name = "FeaturedTab", text = "FEATURED" },
		{ name = "CratesTab", text = "CRATES" },
		{ name = "DirectTab", text = "DIRECT" },
		{ name = "CashTab", text = "CASH" },
		{ name = "PassesTab", text = "GAMEPASSES" },
	}
	local tabWidth = (1 - 0.012 * (#tabDefinitions - 1)) / #tabDefinitions
	for order, definition in tabDefinitions do
		local button = tabs:FindFirstChild(definition.name)
		if button == nil then
			button = Instance.new("TextButton")
			button.Name = definition.name
			button.Parent = tabs
		end
		assert(button:IsA("TextButton"), `[UIResolver] ShopHeader.JumpTabs.{definition.name} must be a TextButton`)
		button.AutoButtonColor = true
		button.BackgroundColor3 = Color3.fromRGB(120, 65, 174)
		button.BorderSizePixel = 0
		button.FontFace = uiConfig().Text.DefaultFont
		button.LayoutOrder = order
		button.Size = UDim2.fromScale(tabWidth, 1)
		button.Text = definition.text
		button.TextColor3 = Color3.fromRGB(255, 246, 224)
		button.TextScaled = true
		button.Visible = true
		button.ZIndex = 14
		styleNativePanel(
			button,
			Color3.fromRGB(120, 65, 174),
			Color3.fromRGB(190, 104, 222),
			Color3.fromRGB(86, 48, 148),
			Color3.fromRGB(74, 38, 77),
			0.28
		)
		local textSize = button:FindFirstChild("TextSize")
		if textSize == nil then
			textSize = Instance.new("UITextSizeConstraint")
			textSize.Name = "TextSize"
			textSize.Parent = button
		end
		assert(
			textSize:IsA("UITextSizeConstraint"),
			`[UIResolver] ShopHeader.JumpTabs.{definition.name}.TextSize must be a UITextSizeConstraint`
		)
		textSize.MinTextSize = 12
		textSize.MaxTextSize = 19
		local touchSize = button:FindFirstChild("TouchSize")
		if touchSize == nil then
			touchSize = Instance.new("UISizeConstraint")
			touchSize.Name = "TouchSize"
			touchSize.Parent = button
		end
		assert(
			touchSize:IsA("UISizeConstraint"),
			`[UIResolver] ShopHeader.JumpTabs.{definition.name}.TouchSize must be a UISizeConstraint`
		)
		touchSize.MinSize = Vector2.new(88, 44)
	end

	local storefrontInstance = view:FindFirstChild("Storefront")
	local storefront: ScrollingFrame
	if storefrontInstance then
		assert(storefrontInstance:IsA("ScrollingFrame"), "[UIResolver] Shop.Storefront must be a ScrollingFrame")
		storefront = storefrontInstance
	else
		storefront = Instance.new("ScrollingFrame")
		storefront.Name = "Storefront"
		storefront.Parent = view
	end
	styleScroll(storefront, 0.035, 0.265, 0.93, 0.69)
	storefront.AutomaticCanvasSize = Enum.AutomaticSize.Y
	storefront.CanvasSize = UDim2.fromOffset(0, 0)
	storefront.ScrollBarThickness = 7
	local storefrontLayout = storefront:FindFirstChild("Layout")
	if storefrontLayout == nil then
		storefrontLayout = Instance.new("UIListLayout")
		storefrontLayout.Name = "Layout"
		storefrontLayout.Parent = storefront
	end
	assert(storefrontLayout:IsA("UIListLayout"), "[UIResolver] Shop.Storefront.Layout must be a UIListLayout")
	storefrontLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	storefrontLayout.Padding = UDim.new(0, 12)
	storefrontLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local function section(name: string, labelText: string, order: number, topColor: Color3, bottomColor: Color3): Frame
		local frame = resolveNativePanel(
			storefront,
			name,
			0,
			0,
			0.98,
			0,
			12,
			bottomColor,
			topColor,
			bottomColor,
			Color3.fromRGB(255, 205, 226),
			0.04
		)
		frame.LayoutOrder = order
		frame.Size = UDim2.new(0.98, 0, 0, 240)
		local label = resolveText(frame, "SectionTitle", labelText, 0.025, 0.025, 0.7, 0, 13, 23, 14, nil)
		label.Size = UDim2.new(0.7, 0, 0, 38)
		label.TextColor3 = Color3.fromRGB(255, 247, 224)
		return frame
	end

	local function gridHolder(parent: Frame, name: string): (Frame, UIGridLayout)
		local holder = resolveContainer(parent, name, 0.025, 0, 0.95, 0, 13)
		holder.Position = UDim2.new(0.025, 0, 0, 54)
		holder.Size = UDim2.new(0.95, 0, 1, -68)
		local grid = holder:FindFirstChild("Grid")
		if grid == nil then
			grid = Instance.new("UIGridLayout")
			grid.Name = "Grid"
			grid.Parent = holder
		end
		assert(grid:IsA("UIGridLayout"), `[UIResolver] {parent.Name}.{name}.Grid must be a UIGridLayout`)
		grid.FillDirection = Enum.FillDirection.Horizontal
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.StartCorner = Enum.StartCorner.TopLeft
		grid.VerticalAlignment = Enum.VerticalAlignment.Top
		return holder, grid
	end

	-- Order 5 pins the starter offer above everything else. ShopController hides
	-- the whole section when the offer is not live, so an expired window leaves
	-- no trace in the storefront.
	local starterSection =
		section("StarterSection", "STARTER OFFER", 5, Color3.fromRGB(255, 196, 84), Color3.fromRGB(196, 92, 24))
	starterSection.Visible = false
	local starterHeadline = resolveText(starterSection, "Headline", "", 0.025, 0, 0.7, 0, 12, 22, 14, nil)
	starterHeadline.Position = UDim2.new(0.025, 0, 0, 54)
	starterHeadline.Size = UDim2.new(0.7, 0, 0, 34)
	starterHeadline.TextColor3 = Color3.fromRGB(255, 250, 232)
	local starterDetail = resolveText(starterSection, "Detail", "", 0.025, 0, 0.7, 0, 9, 15, 14, nil)
	starterDetail.Position = UDim2.new(0.025, 0, 0, 90)
	starterDetail.Size = UDim2.new(0.7, 0, 0, 26)
	starterDetail.TextColor3 = Color3.fromRGB(255, 236, 205)
	local starterTimer = resolveText(starterSection, "Timer", "", 0.025, 0, 0.7, 0, 9, 15, 14, nil)
	starterTimer.Position = UDim2.new(0.025, 0, 0, 116)
	starterTimer.Size = UDim2.new(0.7, 0, 0, 24)
	starterTimer.TextColor3 = Color3.fromRGB(255, 224, 168)
	local starterActionMount = resolveContainer(starterSection, "ActionMount", 0.74, 0, 0.22, 0, 14)
	starterActionMount.Position = UDim2.new(0.74, 0, 0, 62)
	starterActionMount.Size = UDim2.new(0.22, 0, 0, 62)

	local featuredSection =
		section("FeaturedSection", "FEATURED", 10, Color3.fromRGB(249, 103, 173), Color3.fromRGB(145, 28, 103))
	local featuredMount = resolveContainer(featuredSection, "FeaturedMount", 0.025, 0, 0.95, 0, 13)
	featuredMount.Position = UDim2.new(0.025, 0, 0, 54)
	featuredMount.Size = UDim2.new(0.95, 0, 1, -68)

	local cratesSection =
		section("CratesSection", "CRATES", 20, Color3.fromRGB(245, 116, 173), Color3.fromRGB(153, 40, 103))
	local cratesHolder, cratesGrid = gridHolder(cratesSection, "CratesHolder")

	local cashSection =
		section("CashSection", "CASH BUNDLES", 30, Color3.fromRGB(245, 181, 62), Color3.fromRGB(183, 88, 47))
	local cashOffersHolder, cashGrid = gridHolder(cashSection, "CashOffersHolder")

	local directSection =
		section("DirectSection", "BUY DIRECT", 25, Color3.fromRGB(96, 190, 160), Color3.fromRGB(24, 104, 88))
	local directHolder, directGrid = gridHolder(directSection, "DirectHolder")

	local passesSection =
		section("PassesSection", "GAMEPASSES", 40, Color3.fromRGB(166, 85, 217), Color3.fromRGB(75, 43, 145))
	local passesHolder, passesGrid = gridHolder(passesSection, "PassesHolder")

	-- Row counts come from what is actually mounted; a fixed count silently
	-- clips the grid the moment a section gains or loses a card.
	local function cardCount(holder: Frame): number
		local count = 0
		for _, child in holder:GetChildren() do
			if child:IsA("GuiObject") then
				count += 1
			end
		end
		return count
	end

	local function refreshSections()
		local width = storefront.AbsoluteSize.X * 0.93
		if width <= 0 then
			width = 800
		end
		local columns = if width >= 1050 then 4 else if width >= 620 then 2 else 1
		local gap = 12
		local offerWidth = math.max(180, math.floor((width - gap * (columns - 1)) / columns))
		local offerHeight = math.max(150, math.floor(offerWidth / STORE_OFFER_CARD_ASPECT))

		local function sizeGrid(target: Frame, holder: Frame, grid: UIGridLayout, cellHeight: number)
			grid.CellPadding = UDim2.fromOffset(gap, gap)
			grid.CellSize = UDim2.fromOffset(offerWidth, cellHeight)
			local rows = math.max(1, math.ceil(cardCount(holder) / columns))
			target.Size = UDim2.new(0.98, 0, 0, 68 + rows * cellHeight + (rows - 1) * gap)
		end

		sizeGrid(cashSection, cashOffersHolder, cashGrid, offerHeight)
		sizeGrid(passesSection, passesHolder, passesGrid, offerHeight)
		sizeGrid(directSection, directHolder, directGrid, math.max(120, math.floor(offerWidth / ECONOMY_CARD_ASPECT)))

		starterSection.Size = UDim2.new(0.98, 0, 0, 152)

		local crateColumns = 2
		local crateWidth = math.max(250, math.floor((width - gap) / crateColumns))
		local crateHeight = math.clamp(math.floor(crateWidth / 2.45), 190, 230)
		local crateRows = math.max(1, math.ceil(cardCount(cratesHolder) / crateColumns))
		cratesSection.Size = UDim2.new(0.98, 0, 0, 68 + crateRows * crateHeight + (crateRows - 1) * gap)
		cratesGrid.CellPadding = UDim2.fromOffset(gap, gap)
		cratesGrid.CellSize = UDim2.fromOffset(crateWidth, crateHeight)
		featuredSection.Size = UDim2.new(0.98, 0, 0, math.clamp(crateHeight + 68, 250, 310))
	end

	-- Controllers mount many cards in one render pass; coalesce so the resize
	-- runs once per batch rather than once per card.
	local refreshQueued = false
	local function queueRefresh()
		if refreshQueued then
			return
		end
		refreshQueued = true
		task.defer(function()
			refreshQueued = false
			refreshSections()
		end)
	end

	refreshSections()
	local sectionConnection = storefront:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshSections)
	table.insert(cleanups, function()
		sectionConnection:Disconnect()
	end)
	for _, holder in { cratesHolder, cashOffersHolder, passesHolder, directHolder } do
		local added = holder.ChildAdded:Connect(queueRefresh)
		local removed = holder.ChildRemoved:Connect(queueRefresh)
		table.insert(cleanups, function()
			added:Disconnect()
			removed:Disconnect()
		end)
	end

	local function overlay(name: string): CanvasGroup
		local existing = view:FindFirstChild(name)
		local group: CanvasGroup
		if existing then
			assert(existing:IsA("CanvasGroup"), `[UIResolver] Shop.{name} must be a CanvasGroup`)
			group = existing
		else
			group = Instance.new("CanvasGroup")
			group.Name = name
			group.Parent = view
		end
		group.AnchorPoint = Vector2.zero
		group.Active = true
		group.BackgroundColor3 = Color3.fromRGB(42, 20, 45)
		group.BackgroundTransparency = 0.18
		group.BorderSizePixel = 0
		group.ClipsDescendants = true
		group.GroupTransparency = 0
		group.Position = UDim2.fromScale(0, 0)
		group.Size = UDim2.fromScale(1, 1)
		group.Visible = false
		group.ZIndex = 50
		return group
	end

	local details = overlay("DetailsOverlay")
	local detailsPanel = resolveNativePanel(
		details,
		"Panel",
		0.5,
		0.5,
		0.72,
		0.82,
		52,
		Color3.fromRGB(255, 238, 211),
		Color3.fromRGB(255, 250, 230),
		Color3.fromRGB(255, 195, 172),
		Color3.fromRGB(82, 42, 54),
		0.06
	)
	centered(detailsPanel, 0.5, 0.5, 0.72, 0.82, 52)
	local detailsTitle = resolveText(detailsPanel, "Title", "CRATE DETAILS", 0.045, 0.04, 0.72, 0.1, 15, 27, 53, nil)
	detailsTitle.TextColor3 = Color3.fromRGB(87, 34, 59)
	local detailsSummary = resolveText(detailsPanel, "Summary", "", 0.045, 0.14, 0.91, 0.1, 10, 16, 53, nil)
	detailsSummary.TextColor3 = MUTED_TEXT

	local oddsListInstance = detailsPanel:FindFirstChild("OddsList")
	local oddsList: ScrollingFrame
	if oddsListInstance then
		assert(
			oddsListInstance:IsA("ScrollingFrame"),
			"[UIResolver] DetailsOverlay.Panel.OddsList must be a ScrollingFrame"
		)
		oddsList = oddsListInstance
	else
		oddsList = Instance.new("ScrollingFrame")
		oddsList.Name = "OddsList"
		oddsList.Parent = detailsPanel
	end
	styleScroll(oddsList, 0.045, 0.27, 0.91, 0.48)
	oddsList.ZIndex = 53
	oddsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	oddsList.ScrollBarThickness = 6
	local outcomeText = resolveText(oddsList, "OutcomeText", "", 0, 0, 0.96, 0, 10, 16, 54, nil)
	outcomeText.AutomaticSize = Enum.AutomaticSize.Y
	outcomeText.Position = UDim2.fromOffset(0, 0)
	outcomeText.Size = UDim2.fromScale(0.96, 0)
	outcomeText.TextYAlignment = Enum.TextYAlignment.Top

	resolveContainer(detailsPanel, "ConfirmMount", 0.51, 0.8, 0.43, 0.13, 53)
	resolveContainer(detailsPanel, "CancelMount", 0.06, 0.8, 0.32, 0.13, 53)

	local reveal = overlay("RevealOverlay")
	local revealPanel = resolveNativePanel(
		reveal,
		"Panel",
		0.5,
		0.5,
		0.58,
		0.68,
		52,
		Color3.fromRGB(111, 55, 178),
		Color3.fromRGB(225, 119, 246),
		Color3.fromRGB(77, 43, 151),
		Color3.fromRGB(255, 205, 228),
		0.07
	)
	centered(revealPanel, 0.5, 0.5, 0.58, 0.68, 52)
	local revealGlyph =
		resolveText(revealPanel, "Glyph", "?", 0.35, 0.08, 0.3, 0.32, 28, 64, 54, Enum.TextXAlignment.Center)
	revealGlyph.TextColor3 = Color3.fromRGB(255, 225, 96)
	local revealTitle =
		resolveText(revealPanel, "Title", "OPENING...", 0.08, 0.42, 0.84, 0.14, 16, 30, 54, Enum.TextXAlignment.Center)
	revealTitle.TextColor3 = Color3.fromRGB(255, 249, 221)
	local revealDetails =
		resolveText(revealPanel, "Details", "", 0.1, 0.56, 0.8, 0.12, 10, 18, 54, Enum.TextXAlignment.Center)
	revealDetails.TextColor3 = Color3.fromRGB(255, 222, 240)
	resolveContainer(revealPanel, "ActionMount", 0.29, 0.76, 0.42, 0.14, 54)

	local boundsParent = view.Parent
	while boundsParent and not boundsParent:IsA("GuiObject") do
		boundsParent = boundsParent.Parent
	end
	local function refreshRoot()
		if boundsParent then
			local size = (boundsParent :: GuiObject).AbsoluteSize
			local compact = size.X < 900 or size.Y < 520
			view.Size = if compact then UDim2.fromScale(0.96, 0.9) else UDim2.fromScale(0.78, 0.82)
			header.Size = if compact then UDim2.fromScale(0.93, 0.29) else UDim2.fromScale(0.93, 0.215)
			storefront.Position = if compact then UDim2.fromScale(0.035, 0.34) else UDim2.fromScale(0.035, 0.265)
			storefront.Size = if compact then UDim2.fromScale(0.93, 0.625) else UDim2.fromScale(0.93, 0.69)
		end
	end
	refreshRoot()
	if boundsParent then
		local rootConnection = (boundsParent :: GuiObject):GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshRoot)
		table.insert(cleanups, function()
			rootConnection:Disconnect()
		end)
	end
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is a
-- MainGui.BaseClip.Views.Shop CanvasGroup with its sticky header, vertical storefront sections,
-- responsive card grids, details disclosure, and reveal overlays.
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

local function populateBattlePass(view: CanvasGroup)
	styleMenuRoot(view, SHOP_ASPECT)
	local aspect = view:FindFirstChild("AspectRatio")
	if aspect then
		aspect:Destroy()
	end
	view.ClipsDescendants = true
	resolveImage(view, "Background", SHOP_IMAGE, SHOP_ASPECT, 0, 0, 1, 1, 10, nil).ScaleType = Enum.ScaleType.Stretch

	local header = resolveNativePanel(
		view,
		"PassHeader",
		0.035,
		0.035,
		0.93,
		0.22,
		11,
		Color3.fromRGB(72, 38, 128),
		Color3.fromRGB(148, 86, 214),
		Color3.fromRGB(54, 28, 100),
		Color3.fromRGB(255, 226, 250),
		0.08
	)
	local title = resolveText(header, "SeasonTitle", "SEASON", 0.03, 0.08, 0.6, 0.34, 15, 28, 13, nil)
	title.TextColor3 = Color3.fromRGB(255, 246, 224)
	local status = resolveText(header, "Status", "Loading season...", 0.03, 0.44, 0.6, 0.2, 9, 15, 13, nil)
	status.TextColor3 = Color3.fromRGB(238, 214, 255)
	local tierLabel = resolveText(header, "TierLabel", "TIER 0", 0.03, 0.66, 0.3, 0.24, 12, 22, 13, nil)
	tierLabel.TextColor3 = Color3.fromRGB(255, 224, 130)

	-- Progress bar lifted from the QuestCard pattern: a track with a fill whose
	-- width is set from derived tier progress.
	local track = resolveNativePanel(
		header,
		"ProgressTrack",
		0.34,
		0.72,
		0.62,
		0.12,
		13,
		Color3.fromRGB(40, 20, 72),
		Color3.fromRGB(60, 32, 104),
		Color3.fromRGB(30, 14, 56),
		Color3.fromRGB(255, 226, 250),
		0.5
	)
	local fill = resolveNativePanel(
		track,
		"ProgressFill",
		0,
		0,
		0,
		1,
		14,
		Color3.fromRGB(255, 196, 84),
		Color3.fromRGB(255, 230, 150),
		Color3.fromRGB(226, 148, 40),
		Color3.fromRGB(120, 70, 20),
		0.5
	)
	fill.Size = UDim2.fromScale(0, 1)

	local claimAll = resolveContainer(header, "ClaimAllMount", 0.66, 0.06, 0.15, 0.36, 14)
	claimAll.BackgroundTransparency = 1
	local premiumMount = resolveContainer(header, "PremiumMount", 0.82, 0.06, 0.15, 0.36, 14)
	premiumMount.BackgroundTransparency = 1

	local close = header:FindFirstChild("Close")
	if close == nil then
		close = Instance.new("TextButton")
		close.Name = "Close"
		close.Parent = header
	end
	assert(close:IsA("TextButton"), "[UIResolver] PassHeader.Close must be a TextButton")
	close.AutoButtonColor = true
	close.BorderSizePixel = 0
	close.FontFace = uiConfig().Text.DefaultFont
	close.Text = "X"
	close.TextColor3 = Color3.fromRGB(255, 249, 226)
	close.TextScaled = true
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 12)
	close.Size = UDim2.fromOffset(44, 44)
	close.ZIndex = 15
	styleNativePanel(
		close,
		Color3.fromRGB(220, 67, 112),
		Color3.fromRGB(255, 114, 158),
		Color3.fromRGB(190, 44, 94),
		Color3.fromRGB(88, 38, 53),
		0.3
	)

	local holder = view:FindFirstChild("TierHolder")
	local scroll: ScrollingFrame
	if holder then
		assert(holder:IsA("ScrollingFrame"), "[UIResolver] BattlePass.TierHolder must be a ScrollingFrame")
		scroll = holder
	else
		scroll = Instance.new("ScrollingFrame")
		scroll.Name = "TierHolder"
		scroll.Parent = view
	end
	styleScroll(scroll, 0.035, 0.28, 0.93, 0.67)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.ScrollBarThickness = 7
	local layout = scroll:FindFirstChild("List")
	if layout == nil then
		layout = Instance.new("UIListLayout")
		layout.Name = "List"
		layout.Parent = scroll
	end
	assert(layout:IsA("UIListLayout"), "[UIResolver] BattlePass.TierHolder.List must be a UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is a
-- MainGui.BaseClip.Views.BattlePass CanvasGroup with Background, PassHeader
-- (SeasonTitle, Status, TierLabel, ProgressTrack/ProgressFill, ClaimAllMount,
-- PremiumMount, Close) and a TierHolder ScrollingFrame with a List layout.
local function resolveBattlePassView(views: Instance): CanvasGroup
	local authored = views:FindFirstChild("BattlePass")
	local view: CanvasGroup
	if authored then
		assert(authored:IsA("CanvasGroup"), "[UIResolver] Views.BattlePass must be a CanvasGroup")
		view = authored
	else
		view = buildMenuRoot(views, "BattlePass")
	end
	populateBattlePass(view)
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
	local colors = uiConfig().Hud.LiveScoreboard.TeamColors
	resolveTeamPanel(panel, "TeamA", 0, colors.Red, zIndex + 1)
	resolveTeamPanel(panel, "TeamB", 0.515, colors.Blue, zIndex + 1)
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

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is a
-- Hud.CatchButton ImageButton with Label, Corner, Outline, and Gradient.
local function resolveCatchButton(hud: ScreenGui): ImageButton
	local authored = hud:FindFirstChild("CatchButton")
	if authored then
		assert(authored:IsA("ImageButton"), "[UIResolver] Hud.CatchButton must be an ImageButton")
		return authored
	end

	local button = Instance.new("ImageButton")
	button.Name = "CatchButton"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.88, 0.78)
	button.Size = UDim2.fromScale(0.13, 0.075)
	button.BackgroundColor3 = Color3.fromRGB(26, 205, 167)
	button.BackgroundTransparency = 0.08
	button.AutoButtonColor = false
	button.Visible = false
	button.ZIndex = 80
	button.Parent = hud

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Name = "AspectRatio"
	aspect.AspectRatio = 1.85
	aspect.AspectType = Enum.AspectType.FitWithinMaxSize
	aspect.Parent = button

	local corner = Instance.new("UICorner")
	corner.Name = "Corner"
	corner.CornerRadius = UDim.new(0.28, 0)
	corner.Parent = button

	local outline = Instance.new("UIStroke")
	outline.Name = "Outline"
	outline.Color = Color3.fromRGB(18, 24, 34)
	outline.Thickness = 3
	outline.Transparency = 0.08
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Parent = button

	local gradient = Instance.new("UIGradient")
	gradient.Name = "Gradient"
	gradient.Color = ColorSequence.new(Color3.fromRGB(80, 244, 194), Color3.fromRGB(11, 159, 161))
	gradient.Rotation = 90
	gradient.Parent = button

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.88, 0.72)
	label.BackgroundTransparency = 1
	label.FontFace = uiConfig().Text.DefaultFont
	label.Text = "CATCH"
	label.TextColor3 = Color3.fromRGB(255, 255, 239)
	label.TextStrokeColor3 = Color3.fromRGB(20, 35, 40)
	label.TextStrokeTransparency = 0.35
	label.ZIndex = 81
	label.Parent = button
	table.insert(cleanups, TextSizer.bind(label, label, { minSize = 13, maxSize = 30 }))
	return button
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is a
-- Hud.MatchFlow Frame with the hierarchy documented in dodgeball-studio-setup.md.
local function resolveMatchFlow(hud: ScreenGui): Frame
	local authored = hud:FindFirstChild("MatchFlow")
	local root: Frame
	if authored then
		assert(authored:IsA("Frame"), "[UIResolver] Hud.MatchFlow must be a Frame")
		root = authored
	else
		root = Instance.new("Frame")
		root.Name = "MatchFlow"
		root.Parent = hud
	end
	root.AnchorPoint = Vector2.zero
	root.Position = UDim2.fromScale(0, 0)
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Visible = true
	root.ZIndex = 90

	local respawn = resolveText(root, "Respawn", "", 0.36, 0.78, 0.28, 0.055, 14, 28, 92, Enum.TextXAlignment.Center)
	respawn.TextColor3 = Color3.fromRGB(255, 248, 210)
	respawn.TextStrokeColor3 = Color3.fromRGB(20, 24, 42)
	respawn.TextStrokeTransparency = 0.15
	respawn.Visible = false

	local tutorial = resolveText(root, "Tutorial", "", 0.25, 0.86, 0.5, 0.055, 12, 23, 92, Enum.TextXAlignment.Center)
	tutorial.TextColor3 = Color3.fromRGB(255, 248, 210)
	tutorial.TextStrokeColor3 = Color3.fromRGB(20, 24, 42)
	tutorial.TextStrokeTransparency = 0.15
	tutorial.Visible = false

	local actionFeedback =
		resolveText(root, "ActionFeedback", "", 0.39, 0.43, 0.22, 0.07, 16, 34, 93, Enum.TextXAlignment.Center)
	actionFeedback.TextStrokeColor3 = Color3.fromRGB(12, 16, 32)
	actionFeedback.TextStrokeTransparency = 0.18
	actionFeedback.Visible = false

	local feed = resolveContainer(root, "CombatFeed", 0.32, 0.115, 0.36, 0.11, 91)
	for index = 1, 3 do
		local label =
			resolveText(feed, `Line{index}`, "", 0, (index - 1) * 0.33, 1, 0.3, 10, 18, 92, Enum.TextXAlignment.Center)
		label.TextColor3 = Color3.fromRGB(255, 248, 218)
		label.TextStrokeColor3 = Color3.fromRGB(9, 12, 28)
		label.TextStrokeTransparency = 0.22
		label.Visible = false
	end

	local voteTheme = uiConfig().Hud.MatchVote
	local vote = resolveNativePanel(
		root,
		"Vote",
		0,
		0,
		0.92,
		0.62,
		94,
		Color3.fromRGB(20, 25, 55),
		Color3.fromRGB(49, 65, 124),
		Color3.fromRGB(18, 21, 48),
		Color3.fromRGB(255, 237, 176),
		0.055
	)
	centered(vote, 0.5, 0.52, 0.92, 0.62, 94)
	vote.BackgroundTransparency = 0.06
	vote.Visible = false
	local voteAspect = ensureAspect(vote, voteTheme.LandscapeAspect)
	local sizeConstraintInstance = vote:FindFirstChild("SizeConstraint")
		or vote:FindFirstChildWhichIsA("UISizeConstraint")
	local sizeConstraint: UISizeConstraint
	if sizeConstraintInstance then
		assert(
			sizeConstraintInstance:IsA("UISizeConstraint"),
			"[UIResolver] MatchFlow.Vote.SizeConstraint must be a UISizeConstraint"
		)
		sizeConstraint = sizeConstraintInstance
		sizeConstraint.Name = "SizeConstraint"
	else
		sizeConstraint = Instance.new("UISizeConstraint")
		sizeConstraint.Name = "SizeConstraint"
		sizeConstraint.Parent = vote
	end
	sizeConstraint.MinSize = Vector2.new(280, 220)
	sizeConstraint.MaxSize = Vector2.new(1600, 900)

	local voteTitle = resolveText(vote, "Title", "PICK THE NEXT MATCH", 0.05, 0.05, 0.66, 0.11, 16, 30, 95, nil)
	voteTitle.TextColor3 = Color3.fromRGB(255, 249, 220)
	voteTitle.TextStrokeColor3 = Color3.fromRGB(8, 12, 30)
	voteTitle.TextStrokeTransparency = 0.25
	local voteSubtitle = resolveText(
		vote,
		"Subtitle",
		"CHOOSE AN ARENA — ITS GAME MODE IS LOCKED IN",
		0.05,
		0.15,
		0.7,
		0.065,
		10,
		17,
		95,
		nil
	)
	voteSubtitle.TextColor3 = Color3.fromRGB(177, 233, 229)
	local voteTimer =
		resolveText(vote, "Timer", "10 SEC", 0.82, 0.055, 0.13, 0.13, 14, 25, 95, Enum.TextXAlignment.Center)
	styleNativePanel(
		voteTimer,
		Color3.fromRGB(255, 153, 52),
		Color3.fromRGB(255, 204, 79),
		Color3.fromRGB(244, 98, 49),
		Color3.fromRGB(16, 20, 39),
		0.32
	)
	voteTimer.TextColor3 = Color3.fromRGB(255, 250, 224)
	voteTimer.TextStrokeColor3 = Color3.fromRGB(75, 29, 25)
	voteTimer.TextStrokeTransparency = 0.35

	local options = resolveContainer(vote, "Options", 0.04, 0.27, 0.92, 0.56, 95)
	local optionLayouts: {
		{
			button: TextButton,
			previewFallback: Frame,
			thumbnail: ImageLabel,
			previewShade: Frame,
			previewHint: TextLabel,
			map: TextLabel,
			modeBacking: Frame,
			mode: TextLabel,
			count: TextLabel,
			selected: TextLabel,
		}
	} =
		{}
	for index = 1, 3 do
		local palette = voteTheme.Options[index]
		local existing = options:FindFirstChild(`Option{index}`)
		local button: TextButton
		if existing then
			assert(existing:IsA("TextButton"), `[UIResolver] MatchFlow.Vote.Options.Option{index} must be a TextButton`)
			button = existing
		else
			button = Instance.new("TextButton")
			button.Name = `Option{index}`
			button.Parent = options
		end
		centered(button, (index - 1) * 0.34 + 0.16, 0.5, 0.32, 1, 96)
		button.AutoButtonColor = false
		button.ClipsDescendants = true
		button.Text = ""
		styleNativePanel(
			button,
			Color3.fromRGB(253, 226, 174),
			Color3.fromRGB(255, 245, 209),
			Color3.fromRGB(237, 177, 105),
			Color3.fromRGB(29, 25, 38),
			0.065
		)
		local buttonOutline = button:WaitForChild("Outline") :: UIStroke
		buttonOutline.Thickness = 3.5

		local scaleInstance = button:FindFirstChild("Scale")
		local scale: UIScale
		if scaleInstance then
			assert(scaleInstance:IsA("UIScale"), `[UIResolver] Option{index}.Scale must be a UIScale`)
			scale = scaleInstance
		else
			scale = Instance.new("UIScale")
			scale.Name = "Scale"
			scale.Parent = button
		end
		scale.Scale = 1

		local previewFallback = resolveNativePanel(
			button,
			"PreviewFallback",
			0,
			0,
			1,
			0.7,
			97,
			palette.Bottom,
			palette.Top,
			palette.Bottom,
			Color3.fromRGB(29, 25, 38),
			0
		)
		local fallbackOutline = previewFallback:WaitForChild("Outline") :: UIStroke
		fallbackOutline.Transparency = 1

		local thumbnailInstance = button:FindFirstChild("Thumbnail")
		local thumbnail: ImageLabel
		if thumbnailInstance then
			assert(thumbnailInstance:IsA("ImageLabel"), `[UIResolver] Option{index}.Thumbnail must be an ImageLabel`)
			thumbnail = thumbnailInstance
		else
			thumbnail = Instance.new("ImageLabel")
			thumbnail.Name = "Thumbnail"
			thumbnail.Parent = button
		end
		topLeft(thumbnail, 0, 0, 1, 0.7, 98)
		thumbnail.BackgroundTransparency = 1
		thumbnail.Image = ""
		thumbnail.ScaleType = Enum.ScaleType.Crop

		local previewShade = resolveContainer(button, "PreviewShade", 0, 0, 1, 0.7, 99)
		previewShade.BackgroundColor3 = Color3.fromRGB(7, 10, 25)
		previewShade.BackgroundTransparency = 0.05
		local shadeInstance = previewShade:FindFirstChild("Fade")
		local shade: UIGradient
		if shadeInstance then
			assert(shadeInstance:IsA("UIGradient"), `[UIResolver] Option{index}.PreviewShade.Fade must be a UIGradient`)
			shade = shadeInstance
		else
			shade = Instance.new("UIGradient")
			shade.Name = "Fade"
			shade.Parent = previewShade
		end
		shade.Rotation = 90
		shade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.88),
			NumberSequenceKeypoint.new(0.55, 0.66),
			NumberSequenceKeypoint.new(1, 0.05),
		})

		local previewHint = resolveText(
			button,
			"PreviewHint",
			"MAP PREVIEW",
			0.08,
			0.25,
			0.84,
			0.16,
			9,
			15,
			100,
			Enum.TextXAlignment.Center
		)
		previewHint.TextColor3 = Color3.fromRGB(255, 245, 211)
		previewHint.TextStrokeColor3 = Color3.fromRGB(17, 21, 39)
		previewHint.TextStrokeTransparency = 0.3

		local mapLabel =
			resolveText(button, "Map", "MAP", 0.06, 0.47, 0.88, 0.18, 13, 24, 100, Enum.TextXAlignment.Left)
		mapLabel.TextColor3 = Color3.fromRGB(255, 249, 220)
		mapLabel.TextStrokeColor3 = Color3.fromRGB(12, 15, 29)
		mapLabel.TextStrokeTransparency = 0.12

		local modeBacking = resolveNativePanel(
			button,
			"ModeBacking",
			0.05,
			0.75,
			0.4,
			0.17,
			99,
			Color3.fromRGB(25, 165, 157),
			Color3.fromRGB(73, 218, 207),
			Color3.fromRGB(17, 139, 156),
			Color3.fromRGB(45, 32, 38),
			0.28
		)
		local modeLabel =
			resolveText(button, "Mode", "MODE", 0.06, 0.76, 0.38, 0.15, 10, 18, 100, Enum.TextXAlignment.Center)
		modeLabel.TextColor3 = Color3.fromRGB(255, 252, 226)
		modeLabel.TextStrokeColor3 = Color3.fromRGB(20, 38, 44)
		modeLabel.TextStrokeTransparency = 0.45

		local countLabel =
			resolveText(button, "Count", "BE FIRST", 0.5, 0.74, 0.45, 0.19, 9, 16, 100, Enum.TextXAlignment.Right)
		countLabel.TextColor3 = MUTED_TEXT

		local selectedLabel =
			resolveText(button, "Selected", "YOUR PICK", 0.57, 0.04, 0.38, 0.15, 8, 14, 101, Enum.TextXAlignment.Center)
		styleNativePanel(
			selectedLabel,
			voteTheme.Selected,
			Color3.fromRGB(255, 239, 123),
			Color3.fromRGB(255, 183, 55),
			Color3.fromRGB(31, 26, 39),
			0.3
		)
		selectedLabel.TextColor3 = Color3.fromRGB(52, 35, 29)
		selectedLabel.Visible = false

		table.insert(optionLayouts, {
			button = button,
			previewFallback = previewFallback,
			thumbnail = thumbnail,
			previewShade = previewShade,
			previewHint = previewHint,
			map = mapLabel,
			modeBacking = modeBacking,
			mode = modeLabel,
			count = countLabel,
			selected = selectedLabel,
		})
	end

	local progressTrack = resolveNativePanel(
		vote,
		"ProgressTrack",
		0.05,
		0.89,
		0.9,
		0.035,
		95,
		Color3.fromRGB(8, 12, 30),
		Color3.fromRGB(14, 19, 43),
		Color3.fromRGB(5, 8, 22),
		Color3.fromRGB(255, 235, 174),
		0.45
	)
	local progressFill = resolveNativePanel(
		progressTrack,
		"ProgressFill",
		0,
		0,
		1,
		1,
		96,
		Color3.fromRGB(55, 223, 166),
		Color3.fromRGB(136, 255, 168),
		Color3.fromRGB(32, 199, 190),
		Color3.fromRGB(14, 25, 37),
		0.45
	)
	local progressOutline = progressFill:WaitForChild("Outline") :: UIStroke
	progressOutline.Transparency = 1

	local function applyVoteLayout()
		local screenSize = hud.AbsoluteSize
		local portrait = screenSize.Y > 0 and screenSize.X / screenSize.Y < voteTheme.PortraitThreshold
		if portrait then
			centered(vote, 0.5, 0.51, 0.92, 0.82, 94)
			voteAspect.AspectRatio = voteTheme.PortraitAspect
			topLeft(voteTitle, 0.08, 0.04, 0.62, 0.08, 95)
			topLeft(voteSubtitle, 0.08, 0.115, 0.74, 0.055, 95)
			topLeft(voteTimer, 0.75, 0.045, 0.17, 0.09, 95)
			topLeft(options, 0.07, 0.21, 0.86, 0.68, 95)
			topLeft(progressTrack, 0.08, 0.925, 0.84, 0.025, 95)
			for index, option in optionLayouts do
				centered(option.button, 0.5, (index - 1) * 0.34 + 0.15, 1, 0.3, 96)
				topLeft(option.previewFallback, 0, 0, 0.42, 1, 97)
				topLeft(option.thumbnail, 0, 0, 0.42, 1, 98)
				topLeft(option.previewShade, 0, 0, 0.42, 1, 99)
				topLeft(option.previewHint, 0.04, 0.35, 0.34, 0.22, 100)
				topLeft(option.map, 0.47, 0.08, 0.47, 0.24, 100)
				option.map.TextColor3 = PAPER_TEXT
				option.map.TextStrokeTransparency = 1
				topLeft(option.modeBacking, 0.47, 0.43, 0.27, 0.25, 99)
				topLeft(option.mode, 0.48, 0.45, 0.25, 0.21, 100)
				topLeft(option.count, 0.76, 0.44, 0.19, 0.22, 100)
				topLeft(option.selected, 0.04, 0.72, 0.34, 0.19, 101)
			end
		else
			centered(vote, 0.5, 0.52, 0.92, 0.62, 94)
			voteAspect.AspectRatio = voteTheme.LandscapeAspect
			topLeft(voteTitle, 0.05, 0.05, 0.66, 0.11, 95)
			topLeft(voteSubtitle, 0.05, 0.15, 0.7, 0.065, 95)
			topLeft(voteTimer, 0.82, 0.055, 0.13, 0.13, 95)
			topLeft(options, 0.04, 0.27, 0.92, 0.56, 95)
			topLeft(progressTrack, 0.05, 0.89, 0.9, 0.035, 95)
			for index, option in optionLayouts do
				centered(option.button, (index - 1) * 0.34 + 0.16, 0.5, 0.32, 1, 96)
				topLeft(option.previewFallback, 0, 0, 1, 0.7, 97)
				topLeft(option.thumbnail, 0, 0, 1, 0.7, 98)
				topLeft(option.previewShade, 0, 0, 1, 0.7, 99)
				topLeft(option.previewHint, 0.08, 0.25, 0.84, 0.16, 100)
				topLeft(option.map, 0.06, 0.47, 0.88, 0.18, 100)
				option.map.TextColor3 = Color3.fromRGB(255, 249, 220)
				option.map.TextStrokeTransparency = 0.12
				topLeft(option.modeBacking, 0.05, 0.75, 0.4, 0.17, 99)
				topLeft(option.mode, 0.06, 0.76, 0.38, 0.15, 100)
				topLeft(option.count, 0.5, 0.74, 0.45, 0.19, 100)
				topLeft(option.selected, 0.57, 0.04, 0.38, 0.15, 101)
			end
		end
	end
	applyVoteLayout()
	local layoutConnection = hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyVoteLayout)
	table.insert(cleanups, function()
		layoutConnection:Disconnect()
	end)

	local summary = resolveNativePanel(
		root,
		"Summary",
		0.34,
		0.34,
		0.32,
		0.22,
		94,
		Color3.fromRGB(248, 219, 158),
		Color3.fromRGB(255, 244, 204),
		Color3.fromRGB(229, 164, 95),
		Color3.fromRGB(52, 34, 31),
		0.08
	)
	summary.BackgroundTransparency = 0.04
	summary.Visible = false
	local summaryTitle =
		resolveText(summary, "Title", "MATCH COMPLETE", 0.08, 0.08, 0.84, 0.23, 15, 28, 95, Enum.TextXAlignment.Center)
	summaryTitle.TextColor3 = PAPER_TEXT
	resolveText(summary, "Stats", "", 0.08, 0.37, 0.84, 0.2, 11, 20, 95, Enum.TextXAlignment.Center)
	local rewards = resolveText(summary, "Rewards", "", 0.08, 0.64, 0.84, 0.2, 12, 22, 95, Enum.TextXAlignment.Center)
	rewards.TextColor3 = Color3.fromRGB(27, 126, 105)

	return root
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
	resolveStoreOfferCardTemplate(templates)
	resolveNotificationTemplate(templates)
	resolveLeaderboardRowTemplate(templates)
	resolveShopView(views)
	resolveInventoryView(views)
	resolveLeaderboardView(views)
	resolveBattlePassView(views)
	resolveSettingsView(views)
	resolveLiveScoreboard(hud)
	resolveCatchButton(hud)
	resolveMatchFlow(hud)
end

return UIResolver
