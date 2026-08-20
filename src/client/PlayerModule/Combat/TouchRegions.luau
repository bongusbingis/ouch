--!strict

local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

-- Screen geometry for touch classification: where the open gameplay area is,
-- where the bottom swipe strip is, and which rectangles belong to HUD controls
-- that must never produce a combat action.
--
-- Everything is derived from the current viewport rather than authored in
-- pixels, so a phone and a tablet get proportionally the same layout. Thresholds
-- resolve against the *smaller* viewport dimension: on a landscape phone that is
-- the height, and it is the dimension a thumb actually has to travel across.
--
-- Geometry is cached and only rebuilt when the viewport or the topbar inset
-- actually changes. Recomputing this per touch event would be pure waste -- it
-- is identical for every touch in a frame.

local TouchRegions = {}

export type Rect = { minX: number, minY: number, maxX: number, maxY: number }

local viewport = Vector2.new(1280, 720)
local topInset = 0
local exclusions: { [string]: Rect } = {}

local function refreshViewport()
	local camera = Workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		-- A zero viewport happens for a frame during startup and on some device
		-- rotations; keeping the last good value avoids dividing by nothing.
		if size.X > 0 and size.Y > 0 then
			viewport = size
		end
	end
	topInset = GuiService:GetGuiInset().Y
end

-- Resolves a fraction-with-clamps threshold into pixels for this screen.
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

-- HUD controls register the screen space they occupy. This is how the hammer
-- button, and anything else the game draws, stay out of the classifier without
-- the classifier needing to know they exist.
--
-- Registering by rectangle rather than by walking the GUI tree is deliberate:
-- a hierarchy scan per touch is expensive, and most of the tree is decorative
-- and should not block input anyway.
function TouchRegions.setExclusion(name: string, rect: Rect?)
	exclusions[name] = rect
end

function TouchRegions.isExcluded(x: number, y: number): boolean
	-- Above the inset is Roblox's topbar, which is never gameplay.
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

-- The open gameplay area: everything that is not topbar and not a registered
-- HUD control. Movement is not carved out by position here -- ControlModule
-- tells us which touch it actually owns, which is far more reliable than
-- guessing where a dynamic thumbstick happened to appear.
function TouchRegions.isGameplayArea(x: number, y: number): boolean
	if x < 0 or y < 0 or x > viewport.X or y > viewport.Y then
		return false
	end
	return not TouchRegions.isExcluded(x, y)
end

-- The bottom strip an upward flick may start from. Deliberately not the whole
-- bottom edge: the ends are where the movement stick and combat buttons live,
-- and a swipe starting under a thumb that is steering would be a disaster.
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
	-- Covers rotation, safe-area changes, and the topbar resizing.
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(refreshViewport)
end

return TouchRegions
