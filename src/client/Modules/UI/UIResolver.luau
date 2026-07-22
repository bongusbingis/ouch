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
local INVENTORY_ART_OFFSET = Vector2.new(298, 204)
local INVENTORY_ART_SIZE = Vector2.new(1612, 1142)
local INVENTORY_ART_ASPECT = 1612 / 1142

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
	styleMenuRoot(view, 1.4415)
	local legacyTitle = view:FindFirstChild("Title")
	if legacyTitle and legacyTitle:IsA("GuiObject") then
		legacyTitle.Visible = false
	end
	resolveImage(view, "Background", SHOP_IMAGE, 1.4415, 0, 0, 1, 1, 10, nil)
	hideLegacyGui(view, "StatusPlate")
	hideLegacyGui(view, "CashPlate")
	resolveNativePanel(
		view,
		"StatusCard",
		0.1,
		0.2,
		0.45,
		0.13,
		11,
		Color3.fromRGB(255, 238, 220),
		Color3.fromRGB(255, 249, 235),
		Color3.fromRGB(255, 204, 198),
		Color3.fromRGB(92, 43, 52),
		0.28
	)
	resolveAccent(view, "StatusAccent", Color3.fromRGB(255, 75, 153), 0.122, 0.233, 0.012, 0.064)
	resolveNativePanel(
		view,
		"CashCard",
		0.66,
		0.19,
		0.23,
		0.14,
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
	local cash =
		resolveText(view, "Cash", "Cash: loading", 0.68, 0.218, 0.19, 0.085, 12, 20, 12, Enum.TextXAlignment.Center)
	cash.TextColor3 = Color3.fromRGB(48, 32, 20)
	resolveText(
		view,
		"Status",
		"Economy data is loading.",
		0.15,
		0.222,
		0.37,
		0.085,
		10,
		17,
		12,
		Enum.TextXAlignment.Center
	)
	resolveEconomyHolder(view, 0.09, 0.365, 0.82, 0.525)
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is a
-- MainGui.BaseClip.Views.Shop CanvasGroup with Background, StatusCard,
-- StatusAccent, CashCard, ContentWell, Cash, Status, Holder, and Holder.Grid.
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
	styleMenuRoot(view, 1.4415)
	local legacyTitle = view:FindFirstChild("Title")
	if legacyTitle and legacyTitle:IsA("GuiObject") then
		legacyTitle.Visible = false
	end
	local background = resolveImage(view, "Background", INVENTORY_IMAGE, INVENTORY_ART_ASPECT, 0, 0, 1, 1, 10, nil)
	background.ImageRectOffset = INVENTORY_ART_OFFSET
	background.ImageRectSize = INVENTORY_ART_SIZE
	centered(background, 0.5, 0.5, 1, 1, 10)
	hideLegacyGui(view, "StatusPlate")
	resolveNativePanel(
		view,
		"StatusCard",
		0.2,
		0.17,
		0.6,
		0.13,
		11,
		Color3.fromRGB(241, 255, 221),
		Color3.fromRGB(253, 255, 239),
		Color3.fromRGB(204, 245, 157),
		Color3.fromRGB(52, 75, 38),
		0.28
	)
	resolveAccent(view, "StatusAccent", Color3.fromRGB(106, 210, 62), 0.225, 0.203, 0.012, 0.064)
	local contentWell = resolveNativePanel(
		view,
		"ContentWell",
		0.065,
		0.315,
		0.87,
		0.6,
		11,
		Color3.fromRGB(109, 180, 42),
		Color3.fromRGB(187, 250, 104),
		Color3.fromRGB(71, 151, 43),
		Color3.fromRGB(225, 255, 177),
		0.07
	)
	contentWell.BackgroundTransparency = 0.46
	resolveText(
		view,
		"Status",
		"Inventory data is loading.",
		0.25,
		0.192,
		0.5,
		0.085,
		10,
		17,
		12,
		Enum.TextXAlignment.Center
	)
	resolveEconomyHolder(view, 0.09, 0.34, 0.82, 0.55)
end

-- FindFirstChild is deliberate: this temporary Instance.new exception was
-- directed by the user while Studio is unavailable. The replacement is a
-- MainGui.BaseClip.Views.Inventory CanvasGroup with Background, StatusCard,
-- StatusAccent, ContentWell, Status, Holder, and Holder.Grid.
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

function UIResolver.mount()
	if mounted then
		return
	end
	mounted = true
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local views = playerGui:WaitForChild("MainGui"):WaitForChild("BaseClip"):WaitForChild("Views")
	local templates = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI"):WaitForChild("Templates")

	resolveButtonTemplate(templates)
	resolveEconomyItemTemplate(templates)
	resolveNotificationTemplate(templates)
	resolveLeaderboardRowTemplate(templates)
	resolveShopView(views)
	resolveInventoryView(views)
	resolveLeaderboardView(views)
	resolveSettingsView(views)
end

return UIResolver
