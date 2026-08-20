--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CombatCamera = require(script.Parent:WaitForChild("CombatCamera"))
local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))
local TouchIntent = require(script.Parent:WaitForChild("TouchIntent"))
local TouchRegions = require(script.Parent:WaitForChild("TouchRegions"))

-- On-screen view of what the classifier is thinking. Off by default and gated
-- behind CombatConfig.Debug.Enabled.
--
-- Exists because gesture bugs are almost impossible to reason about after the
-- fact: "it threw when I didn't mean it to" contains no information about which
-- threshold was crossed. Watching the live state, drift and velocity while
-- reproducing the problem turns that into a specific number to change.
--
-- Every element is created once and then only updated. A debug view that
-- allocates instances per frame changes the timing of the thing it is measuring.

local CombatDebug = {}

local MAX_ROWS = 5

local started = false
local gui: ScreenGui? = nil
local swipeRegion: Frame? = nil
local rows: { TextLabel } = {}
local summary: TextLabel? = nil

local function label(parent: Instance, order: number): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 0.35
	text.BackgroundColor3 = Color3.new(0, 0, 0)
	text.BorderSizePixel = 0
	text.Font = Enum.Font.Code
	text.TextSize = 14
	text.TextColor3 = Color3.fromRGB(210, 255, 210)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Size = UDim2.fromOffset(460, 18)
	text.Position = UDim2.fromOffset(8, 8 + order * 19)
	text.Text = ""
	text.Visible = false
	text.Parent = parent
	return text
end

local function build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "CombatInputDebug"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	-- Must never eat the input it is reporting on.
	screen.DisplayOrder = 1000
	screen.Parent = playerGui
	gui = screen

	local region = Instance.new("Frame")
	region.Name = "BottomSwipeRegion"
	region.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
	region.BackgroundTransparency = 0.85
	region.BorderSizePixel = 0
	region.Parent = screen
	swipeRegion = region

	summary = label(screen, 0)
	for index = 1, MAX_ROWS do
		rows[index] = label(screen, index)
	end
end

local function update()
	local screen = gui
	if screen == nil then
		return
	end
	local enabled = CombatConfig.Debug.Enabled
	screen.Enabled = enabled
	if not enabled then
		return
	end

	local rect = TouchRegions.bottomSwipeRect()
	if swipeRegion then
		swipeRegion.Position = UDim2.fromOffset(rect.minX, rect.minY)
		swipeRegion.Size = UDim2.fromOffset(rect.maxX - rect.minX, rect.maxY - rect.minY)
		swipeRegion.Visible = CombatConfig.BottomSwipe.Enabled
	end

	local touches, counters = TouchIntent.debugSnapshot()
	if summary then
		summary.Visible = true
		summary.Text = string.format(
			"combat=%s cam=%s charging=%s | tap %d  cam %d  chg %d  swipe %d  amb %d  cancel %d",
			tostring(CombatCamera.isActive()),
			tostring(CombatCamera.isEnabled()),
			tostring(TouchIntent.isCharging()),
			counters.taps,
			counters.cameras,
			counters.charges,
			counters.swipes,
			counters.ambiguous,
			counters.cancelled
		)
	end

	local index = 0
	local now = os.clock()
	for _, touch in touches do
		index += 1
		if index > MAX_ROWS then
			break
		end
		rows[index].Visible = true
		rows[index].Text = string.format(
			"#%d %-9s %.2fs drift=%3dpx vel=%5dpx/s %s",
			index,
			touch.state,
			now - touch.startedAt,
			math.floor(touch.maxDrift),
			math.floor(touch.velocity),
			if touch.fromBottom then (if touch.swipeAlive then "swipe?" else "swipe-dead") else ""
		)
	end
	for hidden = index + 1, MAX_ROWS do
		rows[hidden].Visible = false
	end
end

function CombatDebug.start()
	if started then
		return
	end
	started = true

	-- Built regardless so the flag can be flipped live in Studio without a
	-- rejoin; the ScreenGui simply stays disabled until it is.
	build()
	RunService.RenderStepped:Connect(update)
end

return CombatDebug
