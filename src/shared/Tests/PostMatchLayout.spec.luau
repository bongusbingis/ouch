-- Name: PostMatchLayout.spec.luau
-- Author: Jack C.
-- Description: Spec for the post-match results geometry: two columns on desktop and landscape phones, stacked regions on portrait, a two-row action dock when the buttons cannot share a row, and 44-pixel targets with no overlapping regions at every size.
-- Created: 2026-09-15

--!strict

local T = require(script.Parent.TestKit)
local Layout = require(script.Parent.Parent.UI.Models.PostMatchLayout)

local function overlaps(a, b): boolean
	if a.size.X == 0 or a.size.Y == 0 or b.size.X == 0 or b.size.Y == 0 then
		return false
	end
	return a.position.X < b.position.X + b.size.X
		and b.position.X < a.position.X + a.size.X
		and a.position.Y < b.position.Y + b.size.Y
		and b.position.Y < a.position.Y + a.size.Y
end

local function inside(inner, outer): boolean
	return inner.position.X >= outer.position.X
		and inner.position.Y >= outer.position.Y
		and inner.position.X + inner.size.X <= outer.position.X + outer.size.X
		and inner.position.Y + inner.size.Y <= outer.position.Y + outer.size.Y
end

local function checkComposition(layout)
	local canvas = { position = Vector2.zero, size = layout.canvas.size }
	local regions = { layout.stage, layout.personal, layout.footer }
	for _, region in regions do
		T.expect(inside(region, canvas)):toBeTruthy()
	end
	for i = 1, #regions do
		for j = i + 1, #regions do
			T.expect(overlaps(regions[i], regions[j])):toBeFalsy()
		end
	end
	T.expect(layout.stage.position.Y >= layout.headerHeight):toBeTruthy()
	for _, control in { layout.scores, layout.primary, layout.secondary } do
		T.expect(control.size.X >= 44 and control.size.Y >= 44):toBeTruthy()
	end
	T.expect(overlaps(layout.primary, layout.secondary)):toBeFalsy()
	T.expect(overlaps(layout.countdown, layout.secondary)):toBeFalsy()
	local footerInner = { position = Vector2.zero, size = layout.footer.size }
	for _, part in { layout.countdown, layout.primary, layout.secondary } do
		T.expect(inside(part, footerInner)):toBeTruthy()
	end
	T.expect(
		inside(
			layout.scores,
			{ position = Vector2.zero, size = Vector2.new(layout.canvas.size.X, layout.headerHeight) }
		)
	)
		:toBeTruthy()
end

T.describe("PostMatchLayout", function()
	local roundResult = {
		rewards = { matchXp = 65, bonks = 95 },
		personalStats = {
			{ id = "Eliminations" },
			{ id = "Catches" },
			{ id = "Deaths" },
		},
		seasonProgress = { afterTier = 1 },
	}

	T.it("pairs the stage with a bounded personal panel on desktop and keeps the shop shortcut", function()
		local layout = Layout.resolve(Vector2.new(1920, 1080), true)
		T.expect(layout.compact):toBeFalsy()
		T.expect(layout.stacked):toBeFalsy()
		T.expect(layout.twoRowFooter):toBeFalsy()
		T.expect(layout.showStatus):toBeTruthy()
		T.expect(layout.showStage):toBeTruthy()
		T.expect(layout.showShop):toBeTruthy()
		T.expect(layout.shop ~= nil):toBeTruthy()
		T.expect(layout.canvas.size.X):toEqual(1440)
		T.expect(layout.personal.size.X):toEqual(420)
		T.expect(layout.stage.position.X + layout.stage.size.X < layout.personal.position.X):toBeTruthy()
		T.expect(layout.personal.position.Y):toEqual(layout.stage.position.Y)
		checkComposition(layout)
	end)

	T.it("fits the desktop reward card to its content without leaving an empty body", function()
		local layout = Layout.resolve(Vector2.new(1920, 1080), true, roundResult)
		T.expect(layout.personal.size.Y):toEqual(366)
		T.expect(layout.personal.size.Y < layout.stage.size.Y):toBeTruthy()
		checkComposition(layout)
	end)

	T.it("caps crowded rewards at the available body height so their scroll viewport remains bounded", function()
		local unlocks = {}
		for index = 1, 16 do
			unlocks[index] = { id = tostring(index) }
		end
		local crowded = {
			rewards = roundResult.rewards,
			personalStats = roundResult.personalStats,
			seasonProgress = roundResult.seasonProgress,
			unlocks = unlocks,
		}
		for _, viewport in { Vector2.new(1920, 1080), Vector2.new(956, 440) } do
			local layout = Layout.resolve(viewport, true, crowded)
			T.expect(layout.personal.size.Y):toEqual(layout.stage.size.Y)
			checkComposition(layout)
		end
	end)

	T.it("keeps two columns with compact metrics on a landscape phone", function()
		local layout = Layout.resolve(Vector2.new(956, 440), true)
		T.expect(layout.compact):toBeTruthy()
		T.expect(layout.stacked):toBeFalsy()
		T.expect(layout.showShop):toBeFalsy()
		T.expect(layout.shop):toBeNil()
		T.expect(layout.stage.size.Y >= 150):toBeTruthy()
		T.expect(layout.stage.size.X >= 320):toBeTruthy()
		T.expect(layout.actionHeight):toEqual(48)
		checkComposition(layout)
	end)

	T.it("stacks the stage above the rewards on portrait screens", function()
		local layout = Layout.resolve(Vector2.new(768, 1024), true)
		T.expect(layout.stacked):toBeTruthy()
		T.expect(layout.showStage):toBeTruthy()
		T.expect(layout.stage.size.X):toEqual(layout.personal.size.X)
		T.expect(layout.personal.position.Y > layout.stage.position.Y + layout.stage.size.Y):toBeTruthy()
		checkComposition(layout)
	end)

	T.it("drops the dock to two rows on a narrow portrait phone", function()
		local layout = Layout.resolve(Vector2.new(390, 780), false)
		T.expect(layout.twoRowFooter):toBeTruthy()
		T.expect(layout.showStatus):toBeTruthy()
		T.expect(layout.primary.position.Y > layout.countdown.position.Y):toBeTruthy()
		T.expect(layout.primary.size.X + layout.secondary.size.X + layout.gap <= layout.canvas.size.X):toBeTruthy()
		checkComposition(layout)
	end)

	T.it("yields the stage to the rewards when a short screen cannot fit both", function()
		local layout = Layout.resolve(Vector2.new(640, 360), false)
		T.expect(layout.stacked):toBeTruthy()
		T.expect(layout.showStage):toBeFalsy()
		T.expect(layout.stage.size.Y):toEqual(0)
		T.expect(layout.personal.size.Y >= 120):toBeTruthy()
		checkComposition(layout)
	end)

	T.it("hides the status line before it would squeeze the actions", function()
		local layout = Layout.resolve(Vector2.new(700, 375), false)
		T.expect(layout.twoRowFooter):toBeFalsy()
		T.expect(layout.showStatus):toBeFalsy()
		checkComposition(layout)
	end)

	T.it("sizes nameplates from the stage width and caps them", function()
		local wide = Layout.resolve(Vector2.new(1920, 1080), true)
		T.expect(wide.nameplateWidth):toEqual(260)
		local phone = Layout.resolve(Vector2.new(956, 440), true)
		T.expect(phone.nameplateWidth < 260):toBeTruthy()
		T.expect(phone.nameplateWidth * 3 <= phone.stage.size.X):toBeTruthy()
	end)
end)

return true
