--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TextSizer = require(script.Parent.TextSizer)

local LiveScoreboardResolver = {}

local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI"))
local TEXT_COLOR = Color3.fromRGB(42, 28, 22)
local RANK_COLORS = {
	Color3.fromRGB(255, 199, 58),
	Color3.fromRGB(82, 211, 210),
	Color3.fromRGB(238, 111, 168),
}
local mounted = false

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
			`[LiveScoreboardResolver] {parent.Name}.AspectRatio must be a UIAspectRatioConstraint`
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
		assert(existing:IsA("TextLabel"), `[LiveScoreboardResolver] {parent.Name}.{name} must be a TextLabel`)
		label = existing
	else
		label = Instance.new("TextLabel")
		label.Name = name
		label.Parent = parent
	end
	label.BackgroundTransparency = 1
	label.FontFace = UIConfig.Text.DefaultFont
	label.Text = text
	label.TextColor3 = TEXT_COLOR
	label.TextScaled = false
	label.TextWrapped = true
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Visible = true
	topLeft(label, x, y, width, height, zIndex)
	TextSizer.bind(label, label, {
		minSize = minSize,
		maxSize = maxSize,
		padding = { x = 6, y = 2 },
	})
	return label
end

local function stylePanel(
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
		assert(cornerInstance:IsA("UICorner"), `[LiveScoreboardResolver] {panel.Name}.Corner must be a UICorner`)
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
		assert(strokeInstance:IsA("UIStroke"), `[LiveScoreboardResolver] {panel.Name}.Outline must be a UIStroke`)
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
		assert(
			gradientInstance:IsA("UIGradient"),
			`[LiveScoreboardResolver] {panel.Name}.ColorWash must be a UIGradient`
		)
		gradient = gradientInstance
	else
		gradient = Instance.new("UIGradient")
		gradient.Name = "ColorWash"
		gradient.Parent = panel
	end
	gradient.Color = ColorSequence.new(gradientTop, gradientBottom)
	gradient.Rotation = 105
end

local function resolvePanel(
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
		assert(existing:IsA("Frame"), `[LiveScoreboardResolver] {parent.Name}.{name} must be a Frame`)
		panel = existing
	else
		panel = Instance.new("Frame")
		panel.Name = name
		panel.Parent = parent
	end
	topLeft(panel, x, y, width, height, zIndex)
	stylePanel(panel, background, gradientTop, gradientBottom, strokeColor, radius)
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
		assert(existing:IsA("Frame"), `[LiveScoreboardResolver] {parent.Name}.{name} must be a Frame`)
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

local function resolveAccent(
	parent: Instance,
	name: string,
	color: Color3,
	x: number,
	y: number,
	width: number,
	height: number
): Frame
	local existing = parent:FindFirstChild(name)
	local accent: Frame
	if existing then
		assert(existing:IsA("Frame"), `[LiveScoreboardResolver] {parent.Name}.{name} must be a Frame`)
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

	local cornerInstance = accent:FindFirstChild("Corner")
	local corner: UICorner
	if cornerInstance then
		assert(
			cornerInstance:IsA("UICorner"),
			`[LiveScoreboardResolver] {parent.Name}.{name}.Corner must be a UICorner`
		)
		corner = cornerInstance
	else
		corner = Instance.new("UICorner")
		corner.Name = "Corner"
		corner.Parent = accent
	end
	corner.CornerRadius = UDim.new(0.5, 0)
	return accent
end

local function resolveRow(
	parent: Instance,
	name: string,
	y: number,
	height: number,
	accentColor: Color3,
	zIndex: number
): Frame
	local row = resolvePanel(
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
	local outline = row:WaitForChild("Outline")
	assert(outline:IsA("UIStroke"), `[LiveScoreboardResolver] {row.Name}.Outline must be a UIStroke`)
	outline.Transparency = 0.62

	local accent = resolveAccent(row, "Accent", accentColor, 0.012, 0.13, 0.012, 0.74)
	accent.ZIndex = zIndex + 2
	local rankMount = resolveContainer(row, "RankMount", 0.035, 0.11, 0.13, 0.78, zIndex + 1)
	local bubble = resolvePanel(
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
	centered(bubble, 0.5, 0.5, 1, 1, zIndex + 2)
	ensureAspect(bubble, 1)
	local rank = resolveText(bubble, "Rank", "1", 0, 0, 1, 1, 11, 19, zIndex + 3, Enum.TextXAlignment.Center)
	rank.TextColor3 = Color3.fromRGB(19, 17, 28)

	local playerName = resolveText(row, "PlayerName", "Player", 0.19, 0.1, 0.48, 0.46, 11, 19, zIndex + 2, nil)
	playerName.TextColor3 = Color3.fromRGB(250, 248, 239)
	playerName.TextTruncate = Enum.TextTruncate.AtEnd
	playerName.TextWrapped = false

	local youPill = resolvePanel(
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

local function resolveFfa(shell: Frame, zIndex: number): Frame
	local panel = resolveContainer(shell, "FFA", 0.035, 0.25, 0.93, 0.715, zIndex)
	local rowHeight = 0.205
	local gap = 0.027
	for rank = 1, UIConfig.Hud.LiveScoreboard.FfaRows do
		resolveRow(
			panel,
			`Row{rank}`,
			(rank - 1) * (rowHeight + gap),
			rowHeight,
			RANK_COLORS[rank] or RANK_COLORS[#RANK_COLORS],
			zIndex + 1
		)
	end
	resolveRow(panel, "LocalRow", 0.735, rowHeight, Color3.fromRGB(81, 230, 197), zIndex + 1)
	return panel
end

local function resolveTeam(parent: Instance, name: string, x: number, color: Color3, zIndex: number): Frame
	local panel = resolvePanel(
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
	local outline = panel:WaitForChild("Outline")
	assert(outline:IsA("UIStroke"), `[LiveScoreboardResolver] {panel.Name}.Outline must be a UIStroke`)
	outline.Transparency = 0.6
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
	for rank = 1, UIConfig.Hud.LiveScoreboard.TeamRows do
		resolveRow(rows, `Row{rank}`, (rank - 1) * 0.52, 0.45, color, zIndex + 2)
	end
	return panel
end

local function resolveTeams(shell: Frame, zIndex: number): Frame
	local panel = resolveContainer(shell, "Teams", 0.035, 0.25, 0.93, 0.715, zIndex)
	local colors = UIConfig.Hud.LiveScoreboard.TeamColors
	resolveTeam(panel, "TeamA", 0, colors.Red, zIndex + 1)
	resolveTeam(panel, "TeamB", 0.515, colors.Blue, zIndex + 1)
	panel.Visible = false
	return panel
end

local function populate(view: CanvasGroup, hud: ScreenGui)
	view.AnchorPoint = Vector2.new(1, 0)
	view.BackgroundTransparency = 1
	view.ClipsDescendants = false
	view.GroupTransparency = 0
	view.Position = UDim2.fromScale(0.985, 0.09)
	view.Size = UDim2.fromScale(0.275, 0.36)
	view.Visible = false
	view.ZIndex = 30
	local aspect = ensureAspect(view, 1.28)

	local shadow = resolvePanel(
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

	local shell = resolvePanel(
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
	local shellOutline = shell:WaitForChild("Outline")
	assert(shellOutline:IsA("UIStroke"), "[LiveScoreboardResolver] LiveScoreboard.Shell.Outline must be a UIStroke")
	shellOutline.Transparency = 1

	local header = resolvePanel(
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
	local headerOutline = header:WaitForChild("Outline")
	assert(headerOutline:IsA("UIStroke"), "[LiveScoreboardResolver] LiveScoreboard.Header.Outline must be a UIStroke")
	headerOutline.Transparency = 0.58

	local live = resolvePanel(
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

	resolveFfa(shell, 32)
	resolveTeams(shell, 32)

	local function refreshLayout()
		local viewport = hud.AbsoluteSize
		local portrait = viewport.Y > viewport.X
		local compactLandscape = not portrait and (viewport.X < 1100 or viewport.Y < 720)
		if portrait then
			aspect.AspectRatio = 1.55
			view.Position = UDim2.fromScale(0.985, 0.09)
			view.Size = UDim2.fromScale(0.92, 0.3)
		elseif compactLandscape then
			aspect.AspectRatio = 1.45
			view.Position = UDim2.fromScale(0.985, 0.11)
			view.Size = UDim2.fromScale(0.38, 0.55)
		else
			aspect.AspectRatio = 1.35
			view.Position = UDim2.fromScale(0.985, 0.085)
			view.Size = UDim2.fromScale(0.225, 0.3)
		end
	end
	refreshLayout()
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshLayout)
end

function LiveScoreboardResolver.mount()
	if mounted then
		return
	end
	mounted = true
	local hud = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Hud")
	assert(hud:IsA("ScreenGui"), "[LiveScoreboardResolver] PlayerGui.Hud must be a ScreenGui")
	local authored = hud:FindFirstChild("LiveScoreboard")
	local view: CanvasGroup
	if authored then
		assert(authored:IsA("CanvasGroup"), "[LiveScoreboardResolver] Hud.LiveScoreboard must be a CanvasGroup")
		view = authored
	else
		view = Instance.new("CanvasGroup")
		view.Name = "LiveScoreboard"
		view.Parent = hud
	end
	populate(view, hud)
end

return LiveScoreboardResolver
