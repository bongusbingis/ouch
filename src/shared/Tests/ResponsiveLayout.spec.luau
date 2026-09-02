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
end)

return true
