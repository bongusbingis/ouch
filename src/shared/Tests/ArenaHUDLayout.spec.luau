--!strict
local T = require(script.Parent.TestKit)
local Layout = require(script.Parent.Parent.UI.Models.ArenaHUDLayout)

local function rect(x1, y1, x2, y2): any
	return { Min = Vector2.new(x1, y1), Max = Vector2.new(x2, y2) }
end

local function overlaps(a, b)
	return a.position.X < b.position.X + b.size.X
		and b.position.X < a.position.X + a.size.X
		and a.position.Y < b.position.Y + b.size.Y
		and b.position.Y < a.position.Y + a.size.Y
end

local function checkControls(layout, device)
	for _, control in { layout.menu, layout.scores, layout.toolbar, layout.emote } do
		T.expect(control.size.X >= 44 and control.size.Y >= 44):toBeTruthy()
		T.expect(control.position.X >= device.Min.X):toBeTruthy()
		T.expect(control.position.Y >= device.Min.Y):toBeTruthy()
		T.expect(control.position.X + control.size.X <= device.Max.X):toBeTruthy()
		T.expect(control.position.Y + control.size.Y <= device.Max.Y):toBeTruthy()
	end
	local regions = { layout.hud, layout.menu, layout.scores, layout.toolbar, layout.emote }
	for i = 1, #regions do
		for j = i + 1, #regions do
			T.expect(overlaps(regions[i], regions[j])):toBeFalsy()
		end
	end
end

T.describe("Arena mobile HUD composition", function()
	T.it("fits an iPhone Pro Max landscape HUD beside CoreGui and leaves the centre clear", function()
		local device = rect(62, 0, 894, 420)
		local layout = Layout.resolve(Vector2.new(956, 440), device, rect(208, 0, 832, 58), true)
		T.expect(layout.docked):toBeTruthy()
		T.expect(layout.hud.position.X >= 62 + 208):toBeTruthy()
		T.expect(layout.hud.position.Y + layout.hud.size.Y < 90):toBeTruthy()
		T.expect(layout.toolbar.size.Y < 80):toBeTruthy()
		T.expect(layout.toolbar.position.Y > 330):toBeTruthy()
		checkControls(layout, device)
	end)

	T.it("fits smaller landscape phones, both notch orientations, portrait and tablets", function()
		for _, sample in
			{
				{ 844, 390, rect(59, 0, 785, 369) },
				{ 667, 375, rect(0, 0, 667, 354) },
				{ 956, 440, rect(0, 0, 894, 420) },
				{ 956, 440, rect(62, 0, 956, 420) },
				{ 390, 844, rect(0, 47, 390, 810) },
				{ 320, 568, rect(0, 20, 320, 548) },
				{ 1180, 820, rect(0, 24, 1180, 800) },
			}
		do
			local device = sample[3]
			local layout = Layout.resolve(
				Vector2.new(sample[1], sample[2]),
				device,
				rect(208, 0, device.Max.X - device.Min.X, 58),
				true
			)
			checkControls(layout, device)
		end
	end)

	T.it("moves below an expanded platform toolbar without overlapping it", function()
		local device = rect(59, 0, 785, 369)
		local layout = Layout.resolve(Vector2.new(844, 390), device, rect(630, 0, 726, 58), true)
		T.expect(layout.docked):toBeFalsy()
		T.expect(layout.menu.position.Y >= 58):toBeTruthy()
		T.expect(layout.hud.position.Y >= layout.menu.position.Y + 44 + 10):toBeTruthy()
		checkControls(layout, device)
	end)

	T.it("keeps the weapon dock above the home gesture area", function()
		local device = rect(0, 47, 430, 898)
		local layout = Layout.resolve(Vector2.new(430, 932), device, rect(208, 0, 430, 58), true)
		T.expect(layout.toolbar.position.Y + layout.toolbar.size.Y <= 888):toBeTruthy()
		T.expect(layout.emote.position.Y + layout.emote.size.Y <= 888):toBeTruthy()
	end)

	T.it("does not create invalid sizes before the camera is ready", function()
		local layout = Layout.resolve(Vector2.zero, rect(0, 0, 0, 0), rect(0, 0, 0, 0), true)
		T.expect(layout.hud.size.X > 0 and layout.toolbar.size.X > 0):toBeTruthy()
	end)
end)

return true
