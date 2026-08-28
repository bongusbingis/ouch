-- Name: TouchRegions.luau
-- Author: Jack C.
-- Description: Defines and tests the on-screen touch regions used by combat input, including HUD exclusion rectangles registered by UI and the bottom swipe region.
-- Created: 2026-08-20

--!strict

local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local TouchRegions = {}

export type Rect = { minX: number, minY: number, maxX: number, maxY: number }

local viewport = Vector2.new(1280, 720)
local topInset = 0
local exclusions: { [string]: Rect } = {}

local function refreshViewport()
	local camera = Workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		if size.X > 0 and size.Y > 0 then
			viewport = size
		end
	end
	topInset = GuiService:GetGuiInset().Y
end

function TouchRegions.scale(scaled: CombatConfig.Scaled): number
	local reference = math.min(viewport.X, viewport.Y)
	return math.clamp(reference * scaled.Fraction, scaled.MinPixels, scaled.MaxPixels)
end

function TouchRegions.viewportSize(): Vector2
	return viewport
end

local function contains(rect: Rect, x: number, y: number): boolean
	return x >= rect.minX and x <= rect.maxX and y >= rect.minY and y <= rect.maxY
end

function TouchRegions.setExclusion(name: string, rect: Rect?)
	exclusions[name] = rect
end

function TouchRegions.isExcluded(x: number, y: number): boolean
	if y <= topInset then
		return true
	end
	for _, rect in exclusions do
		if contains(rect, x, y) then
			return true
		end
	end
	return false
end

function TouchRegions.isGameplayArea(x: number, y: number): boolean
	if x < 0 or y < 0 or x > viewport.X or y > viewport.Y then
		return false
	end
	return not TouchRegions.isExcluded(x, y)
end

function TouchRegions.bottomSwipeRect(): Rect
	local config = CombatConfig.BottomSwipe
	local height = viewport.Y * config.RegionHeightFraction
	return {
		minX = viewport.X * config.RegionMinXFraction,
		maxX = viewport.X * config.RegionMaxXFraction,
		minY = viewport.Y - height,
		maxY = viewport.Y,
	}
end

function TouchRegions.topInset(): number
	return topInset
end

-- The middle of the area a tap or a hold is actually read in: the whole
-- viewport minus the platform's top inset. UI that points at "where you press"
-- asks for this rather than assuming screen centre.
function TouchRegions.gameplayCenter(): Vector2
	return Vector2.new(viewport.X / 2, (topInset + viewport.Y) / 2)
end

function TouchRegions.isInBottomSwipeRegion(x: number, y: number): boolean
	if not CombatConfig.BottomSwipe.Enabled then
		return false
	end
	return contains(TouchRegions.bottomSwipeRect(), x, y) and not TouchRegions.isExcluded(x, y)
end

function TouchRegions.start()
	refreshViewport()

	local function watch(camera: Camera?)
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshViewport)
		end
	end
	watch(Workspace.CurrentCamera)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watch(Workspace.CurrentCamera)
		refreshViewport()
	end)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(refreshViewport)
end

return TouchRegions
