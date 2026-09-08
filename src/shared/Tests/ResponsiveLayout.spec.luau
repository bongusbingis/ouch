--!strict

local T = require(script.Parent.TestKit)
local ResponsiveLayout = require(script.Parent.Parent.UI.Models.ResponsiveLayout)

local INVENTORY_PANEL = {
	Portrait = { WidthScale = 0.956, HeightScale = 0.75, MaxSize = Vector2.new(480, 720) },
	Landscape = {
		WidthScale = 0.602436,
		HeightScale = 0.74763,
		MaxSize = Vector2.new(1000, 820),
		AspectRatio = 1.08,
	},
}
local PORTRAIT_MAX_ASPECT = 1
-- Mirrors SplashPage's portrait action dock: the BottomRight frame is bottom
-- anchored at 0.98 and PortraitActionsHeightPx tall, so the progress panels have
-- to end above it.
local SPLASH_ACTIONS_BOTTOM_SCALE = 0.98
local SPLASH_ACTIONS_HEIGHT_PX = 146
-- Seven day cells stay legible only while the card keeps this much height.
local DAILY_MIN_HEIGHT_PX = 88
local SPLASH_PANELS = {
	DailyMinHeightPx = 98,
	EdgePaddingPx = 24,
	GapPx = 10,
	Landscape = {
		DailyBottomScale = 0.9,
		SeasonTopScale = 0.145,
		QuestsTopScale = 0.31,
	},
	Portrait = {
		WidthScale = 0.94,
		TopScale = 0.24,
		BottomScale = 0.67,
		GapPx = 6,
		SeasonWeight = 0.22,
		DailyWeight = 0.37,
		QuestsWeight = 0.41,
	},
	Daily = {
		WidthScale = 0.34,
		HeightScale = 0.27,
		MaxSize = Vector2.new(600, 220),
		AspectRatio = 2.5,
	},
	Season = {
		WidthScale = 0.3,
		HeightScale = 0.16,
		MaxSize = Vector2.new(600, 180),
		AspectRatio = 3.5,
	},
	Quests = {
		WidthScale = 0.3,
		HeightScale = 0.32,
		MaxSize = Vector2.new(600, 340),
		AspectRatio = 1.65,
	},
}

local function overlaps(positionA: Vector2, sizeA: Vector2, positionB: Vector2, sizeB: Vector2): boolean
	return positionA.X < positionB.X + sizeB.X
		and positionA.X + sizeA.X > positionB.X
		and positionA.Y < positionB.Y + sizeB.Y
		and positionA.Y + sizeA.Y > positionB.Y
end

local function landscapePanels()
	local config = table.clone(SPLASH_PANELS)
	config.DailyMinHeightPx = 116
	config.Landscape = table.clone(config.Landscape)
	config.Landscape.ActionsReservePx = 252
	config.Landscape.ShortTopPx = 80
	config.Landscape.ShortBottomPx = 70
	config.Season = table.clone(config.Season)
	config.Season.ShortHeightScale = 0.19
	config.Season.ShortAspectRatio = 4
	config.Quests = table.clone(config.Quests)
	config.Quests.ShortHeightScale = 0.4
	return config
end

T.describe("Inset coordinate conversion", function()
	T.it("restores full-screen height when engine rectangles start above the Core UI origin", function()
		local rect = ResponsiveLayout.insetRect(
			Vector2.new(666, 374),
			Vector2.new(0, -58),
			Vector2.new(666, 316),
			Vector2.new(0, -58),
			Vector2.new(666, 316)
		)
		T.expect(rect.position.Y):toEqual(0)
		T.expect(rect.size.Y):toEqual(374)
	end)
	T.it("preserves hardware cutouts and an already inset Core UI parent", function()
		local deviceMin, deviceMax = Vector2.new(0, -58), Vector2.new(733, 313)
		local full = ResponsiveLayout.insetRect(
			Vector2.new(851, 392),
			deviceMin,
			deviceMax,
			Vector2.new(-59, -58),
			Vector2.new(792, 334)
		)
		T.expect(full.position.X):toEqual(59)
		T.expect(full.size.X):toEqual(733)
		T.expect(full.size.Y):toEqual(371)
		local core =
			ResponsiveLayout.insetRect(Vector2.new(851, 392), deviceMin, deviceMax, Vector2.zero, Vector2.new(733, 313))
		T.expect(core.position.X):toEqual(0)
		T.expect(core.size.Y):toEqual(313)
	end)
end)

T.describe("Responsive UI layout", function()
	T.it("keeps desktop quests clear of the full action stack across the short-layout boundary", function()
		local config = landscapePanels()
		for _, size in
			{
				Vector2.new(820, 501),
				Vector2.new(1158, 520),
				Vector2.new(1158, 600),
				Vector2.new(1158, 725),
				Vector2.new(1920, 1080),
			}
		do
			local layout = ResponsiveLayout.splashPanels(size, config, 1, 500)
			local actionsTop = size.Y - 252
			T.expect(layout.quests.position.Y + layout.quests.size.Y <= actionsTop):toBeTruthy()
			T.expect(layout.quests.position.Y >= layout.season.position.Y + layout.season.size.Y + config.GapPx)
				:toBeTruthy()
			T.expect(layout.quests.size.Y >= 44):toBeTruthy()
		end
	end)

	T.it("applies the desktop action reserve only after the short-landscape breakpoint", function()
		local config = landscapePanels()
		local unreserved = landscapePanels()
		unreserved.Landscape.ActionsReservePx = 0
		for _, size in { Vector2.new(666, 258), Vector2.new(750, 303), Vector2.new(820, 499), Vector2.new(820, 500) } do
			local layout = ResponsiveLayout.splashPanels(size, config, 1, 500)
			local original = ResponsiveLayout.splashPanels(size, unreserved, 1, 500)
			for _, name in { "daily", "season", "quests" } do
				T.expect(layout[name].position.Y):toEqual(original[name].position.Y)
				T.expect(layout[name].size.Y):toEqual(original[name].size.Y)
			end
			T.expect(layout.quests.position.Y + layout.quests.size.Y <= size.Y - 70):toBeTruthy()
		end
		local size = Vector2.new(820, 501)
		local layout = ResponsiveLayout.splashPanels(size, config, 1, 500)
		local original = ResponsiveLayout.splashPanels(size, unreserved, 1, 500)
		T.expect(original.quests.position.Y + original.quests.size.Y > size.Y - 252):toBeTruthy()
		T.expect(layout.quests.position.Y + layout.quests.size.Y <= size.Y - 252):toBeTruthy()
	end)

	T.it("preserves full quest panel height when the desktop action stack already has room", function()
		local config = landscapePanels()
		local spec = { Portrait = config.Quests, Landscape = config.Quests }
		local size = Vector2.new(1920, 1080)
		local preferred = ResponsiveLayout.panelSize(size, spec, 1, 500)
		local layout = ResponsiveLayout.splashPanels(size, config, 1, 500)
		T.expect(layout.quests.size.Y):toEqual(preferred.Y)
		T.expect(layout.quests.size.X):toEqual(preferred.X)
	end)

	T.it("uses short landscape dimensions without changing the portrait branch", function()
		local spec = {
			Portrait = INVENTORY_PANEL.Portrait,
			Landscape = table.clone(INVENTORY_PANEL.Landscape),
		}
		spec.Landscape.ShortWidthScale = 0.9
		spec.Landscape.ShortHeightScale = 0.7
		spec.Landscape.ShortAspectRatio = 2.4
		local landscape = ResponsiveLayout.panelSize(Vector2.new(666, 316), spec, 1, 500)
		T.expect(landscape.X > 500):toBeTruthy()
		T.expect(landscape.Y):toEqual(221)
		local portrait = ResponsiveLayout.panelSize(Vector2.new(390, 844), spec, 1, 500)
		T.expect(portrait.X):toEqual(372)
		T.expect(portrait.Y):toEqual(633)
	end)

	T.it("reserves a whole short quest row between season progress and lobby actions", function()
		local config = table.clone(SPLASH_PANELS)
		config.Landscape = table.clone(config.Landscape)
		config.Landscape.ShortTopPx = 80
		config.Landscape.ShortBottomPx = 62
		config.Season = table.clone(config.Season)
		config.Season.ShortHeightScale = 0.14
		config.Quests = table.clone(config.Quests)
		config.Quests.ShortHeightScale = 0.4
		local layout = ResponsiveLayout.splashPanels(Vector2.new(666, 316), config, 1, 500)
		T.expect(layout.quests.size.Y >= 120):toBeTruthy()
		T.expect(layout.quests.position.Y + layout.quests.size.Y <= 254):toBeTruthy()
		T.expect(overlaps(layout.season.position, layout.season.size, layout.quests.position, layout.quests.size))
			:toEqual(false)
	end)

	T.it("expands the inventory panel instead of preserving its landscape aspect in portrait", function()
		local size = ResponsiveLayout.panelSize(Vector2.new(390, 844), INVENTORY_PANEL, PORTRAIT_MAX_ASPECT)
		T.expect(size.X):toEqual(372)
		T.expect(size.Y):toEqual(633)
	end)

	T.it("preserves the bounded desktop inventory aspect", function()
		local size = ResponsiveLayout.panelSize(Vector2.new(1920, 1080), INVENTORY_PANEL, PORTRAIT_MAX_ASPECT)
		T.expect(size.X):toEqual(872)
		T.expect(size.Y):toEqual(807)
	end)

	T.it("derives usable inventory card columns from available width", function()
		local phoneColumns, phoneCell = ResponsiveLayout.gridCellSize(311, 132, 150, 7, 6)
		T.expect(phoneColumns):toEqual(2)
		T.expect(phoneCell):toEqual(150)

		local narrowColumns, narrowCell = ResponsiveLayout.gridCellSize(126, 132, 150, 7, 6)
		T.expect(narrowColumns):toEqual(1)
		T.expect(narrowCell):toEqual(126)
	end)

	T.it("translates device-safe bounds only for full-screen roots", function()
		local fullScreen =
			ResponsiveLayout.safeRect(Vector2.new(390, 844), Vector2.new(0, 47), Vector2.new(390, 810), true)
		T.expect(fullScreen.position.X):toEqual(0)
		T.expect(fullScreen.position.Y):toEqual(47)
		T.expect(fullScreen.size.X):toEqual(390)
		T.expect(fullScreen.size.Y):toEqual(763)

		local insetRoot =
			ResponsiveLayout.safeRect(Vector2.new(390, 844), Vector2.new(0, 47), Vector2.new(390, 810), false)
		T.expect(insetRoot.position.X):toEqual(0)
		T.expect(insetRoot.position.Y):toEqual(0)
		T.expect(insetRoot.size.X):toEqual(390)
		T.expect(insetRoot.size.Y):toEqual(763)

		-- The camera reports (1, 1) until the first frame, so a real device inset can
		-- exceed the viewport; that has to yield a degenerate rect, not an error.
		local unrendered = ResponsiveLayout.safeRect(Vector2.new(1, 1), Vector2.new(0, 47), Vector2.new(1, 1), true)
		T.expect(unrendered.size.X >= 0 and unrendered.size.Y >= 0):toBeTruthy()
		T.expect(unrendered.position.X >= 0 and unrendered.position.Y >= 0):toBeTruthy()

		local noCamera = ResponsiveLayout.safeRect(Vector2.zero, Vector2.new(12, 47), Vector2.zero, true)
		T.expect(noCamera.size.X):toEqual(0)
		T.expect(noCamera.size.Y):toEqual(0)
	end)

	T.it("reserves a non-intersecting keycap band at every supported menu size", function()
		local config = {
			HorizontalPaddingPx = 12,
			LabelKeycapGapPx = 10,
			KeycapWidthScale = 0.27,
		}
		for _, size in { Vector2.new(126, 54), Vector2.new(210, 88) } do
			local layout = ResponsiveLayout.menuToggle(
				size,
				config.HorizontalPaddingPx,
				config.LabelKeycapGapPx,
				config.KeycapWidthScale
			)
			T.expect(overlaps(layout.labelPosition, layout.labelSize, layout.keycapPosition, layout.keycapSize))
				:toEqual(false)
			T.expect(layout.keycapPosition.X - (layout.labelPosition.X + layout.labelSize.X))
				:toEqual(config.LabelKeycapGapPx)
		end
	end)

	T.it("keeps splash progress panels bounded and non-overlapping", function()
		for _, size in
			{
				Vector2.new(375, 586),
				Vector2.new(375, 667),
				Vector2.new(390, 844),
				Vector2.new(844, 390),
				Vector2.new(820, 500),
				Vector2.new(1920, 1080),
				Vector2.new(2560, 1440),
			}
		do
			local layout = ResponsiveLayout.splashPanels(size, SPLASH_PANELS, PORTRAIT_MAX_ASPECT, 500)
			T.expect(overlaps(layout.daily.position, layout.daily.size, layout.season.position, layout.season.size))
				:toEqual(false)
			T.expect(overlaps(layout.daily.position, layout.daily.size, layout.quests.position, layout.quests.size))
				:toEqual(false)
			T.expect(overlaps(layout.season.position, layout.season.size, layout.quests.position, layout.quests.size))
				:toEqual(false)
			if layout.portrait then
				local actionsTop = size.Y * SPLASH_ACTIONS_BOTTOM_SCALE - SPLASH_ACTIONS_HEIGHT_PX
				T.expect(layout.quests.position.Y + layout.quests.size.Y < actionsTop):toBeTruthy()
			end
			T.expect(layout.daily.size.Y >= DAILY_MIN_HEIGHT_PX):toBeTruthy()
			for _, panel in { layout.daily, layout.season, layout.quests } do
				T.expect(panel.position.X >= 0 and panel.position.Y >= 0):toBeTruthy()
				T.expect(panel.position.X + panel.size.X <= size.X):toBeTruthy()
				T.expect(panel.position.Y + panel.size.Y <= size.Y):toBeTruthy()
			end
		end
	end)
end)

T.describe("Phone progression readability", function()
	T.it("gives the short progression stack the action-safe column with room to discover quests", function()
		local config = landscapePanels()
		for _, size in { Vector2.new(666, 258), Vector2.new(666, 316), Vector2.new(750, 303), Vector2.new(820, 500) } do
			local layout = ResponsiveLayout.splashPanels(size, config, 1, 500)
			local stack = assert(layout.progressStack)
			T.expect(stack.position.Y):toEqual(layout.season.position.Y)
			T.expect(stack.position.Y + stack.size.Y):toEqual(size.Y - config.Landscape.ShortBottomPx)
			T.expect(stack.position.X >= 0 and stack.position.X + stack.size.X <= size.X):toEqual(true)
			T.expect(stack.size.X - config.GapPx * 2 >= layout.season.size.X):toEqual(true)
			T.expect(stack.size.Y >= layout.season.size.Y + config.GapPx * 1.5 + 36):toEqual(true)
		end
	end)
	T.it("leaves desktop and portrait progression unstacked", function()
		for _, size in { Vector2.new(820, 501), Vector2.new(1158, 725), Vector2.new(390, 844) } do
			T.expect(ResponsiveLayout.splashPanels(size, landscapePanels(), 1, 500).progressStack):toBeNil()
		end
	end)
	T.it("reserves a full quest title and readable daily amounts in portrait", function()
		local layout = ResponsiveLayout.splashPanels(Vector2.new(374, 618), SPLASH_PANELS, PORTRAIT_MAX_ASPECT, 500)
		T.expect(layout.quests.size.Y - 56 >= 42):toEqual(true)
		T.expect(layout.daily.size.Y >= 98):toEqual(true)
		T.expect(overlaps(layout.daily.position, layout.daily.size, layout.quests.position, layout.quests.size))
			:toEqual(false)
	end)
end)

return true
