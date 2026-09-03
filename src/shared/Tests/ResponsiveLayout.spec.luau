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
local SPLASH_PANELS = {
	EdgePaddingPx = 24,
	GapPx = 10,
	Landscape = {
		DailyBottomScale = 0.9,
		SeasonTopScale = 0.145,
		QuestsTopScale = 0.31,
	},
	Portrait = {
		WidthScale = 0.94,
		TopScale = 0.315,
		BottomScale = 0.64,
		GapPx = 6,
		SeasonWeight = 0.19,
		DailyWeight = 0.29,
		QuestsWeight = 0.52,
	},
	Daily = {
		WidthScale = 0.29,
		HeightScale = 0.2,
		MaxSize = Vector2.new(600, 220),
		AspectRatio = 2.72,
	},
	Season = {
		WidthScale = 0.23,
		HeightScale = 0.16,
		MaxSize = Vector2.new(470, 180),
		AspectRatio = 2.6,
	},
	Quests = {
		WidthScale = 0.3,
		HeightScale = 0.28,
		MaxSize = Vector2.new(600, 300),
		AspectRatio = 2,
	},
}

local function overlaps(positionA: Vector2, sizeA: Vector2, positionB: Vector2, sizeB: Vector2): boolean
	return positionA.X < positionB.X + sizeB.X
		and positionA.X + sizeA.X > positionB.X
		and positionA.Y < positionB.Y + sizeB.Y
		and positionA.Y + sizeA.Y > positionB.Y
end

T.describe("Responsive UI layout", function()
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
				Vector2.new(375, 667),
				Vector2.new(390, 844),
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
			for _, panel in { layout.daily, layout.season, layout.quests } do
				T.expect(panel.position.X >= 0 and panel.position.Y >= 0):toBeTruthy()
				T.expect(panel.position.X + panel.size.X <= size.X):toBeTruthy()
				T.expect(panel.position.Y + panel.size.Y <= size.Y):toBeTruthy()
			end
		end
	end)
end)

return true
