-- Name: EmoteWheelModel.spec.luau
-- Author: Jack C.
-- Description: Verifies the radial emote selector's layout clamps, sector generation and hit-testing across capacities so selection never flickers or resolves inside the dead zone.
-- Created: 2026-09-09
--!strict

local T = require(script.Parent.TestKit)
local Model = require(script.Parent.Parent.UI.Models.EmoteWheelModel)
local Config = script.Parent.Parent.Parent.Config
local Emotes = require(Config.Cosmetics.Emotes)
local Wheel = require(Config.Interface.EmoteWheel)

local desktop = Vector2.new(1246, 841)
local phone = Vector2.new(874, 402)

T.describe("EmoteWheelModel layout", function()
	T.it("clamps the diameter to the configured range", function()
		local big = Model.layout(Vector2.new(3000, 2000), 4)
		T.expect(big.diameter):toEqual(Wheel.MaxDiameterPx)
		local small = Model.layout(Vector2.new(600, 300), 4)
		T.expect(small.diameter <= 300 - 2 * Wheel.EdgeMarginPx - Wheel.CaptionReservePx):toBeTruthy()
	end)

	T.it("never exceeds the phone viewport's short side", function()
		local layout = Model.layout(phone, 8)
		T.expect(layout.diameter <= phone.Y - 2 * Wheel.EdgeMarginPx - Wheel.CaptionReservePx):toBeTruthy()
		T.expect(layout.ringRadius > layout.deadZoneRadius):toBeTruthy()
	end)

	T.it("divides the circle by capacity", function()
		T.expect(Model.layout(desktop, 4).sectorArcDegrees):toEqual(90)
		T.expect(Model.layout(desktop, 8).sectorArcDegrees):toEqual(45)
	end)

	T.it("clamps capacity between one and the configured maximum", function()
		T.expect(Model.capacity(nil)):toEqual(Emotes.BaseSlots)
		T.expect(Model.capacity(99)):toEqual(Emotes.MaxSlots)
		T.expect(Model.capacity(0)):toEqual(1)
	end)
end)

T.describe("EmoteWheelModel sectors", function()
	T.it("produces one sector per slot including empties", function()
		local sectors = Model.sectors({ "EmoteWave" }, 4)
		T.expect(#sectors):toEqual(4)
		T.expect(sectors[1].filled):toBeTruthy()
		T.expect(sectors[1].displayName):toEqual(string.upper(Emotes.Clips.EmoteWave.DisplayName))
		T.expect(sectors[2].filled == false):toBeTruthy()
		T.expect(sectors[2].displayName):toEqual("EMPTY")
		T.expect(sectors[2].emoteId == nil):toBeTruthy()
	end)

	T.it("treats an unknown emote id as empty", function()
		local sectors = Model.sectors({ "NotARealEmote" }, 4)
		T.expect(sectors[1].filled == false):toBeTruthy()
	end)

	T.it("puts slot one at twelve o'clock", function()
		local sectors = Model.sectors({}, 8)
		T.expect(sectors[1].centerAngleDeg):toEqual(0)
		T.expect(sectors[2].centerAngleDeg):toEqual(180)
		T.expect(sectors[3].centerAngleDeg):toEqual(90)
		T.expect(sectors[5].centerAngleDeg):toEqual(45)
	end)

	T.it("keeps the first four slots in place when the wheel grows to eight", function()
		for index = 1, 4 do
			T.expect(Model.centerAngle(index, 8)):toEqual(Model.centerAngle(index, 4))
		end
	end)
end)

T.describe("EmoteWheelModel caption", function()
	T.it("reports an empty wheel as having nothing equipped", function()
		local sectors = Model.sectors({}, 4)
		T.expect(Model.anyFilled(sectors)):toEqual(false)
		T.expect(Model.caption(sectors, 2).kind):toEqual("none")
		T.expect(Model.caption(sectors, nil).name):toEqual("NO EMOTES YET")
	end)

	T.it("names the lit emote, an empty slot, or the idle title", function()
		local sectors = Model.sectors({ "EmoteWave" }, 4)
		T.expect(Model.anyFilled(sectors)):toEqual(true)
		T.expect(Model.caption(sectors, 1).kind):toEqual("filled")
		T.expect(Model.caption(sectors, 1).name):toEqual(string.upper(Emotes.Clips.EmoteWave.DisplayName))
		T.expect(Model.caption(sectors, 3).kind):toEqual("empty")
		T.expect(Model.caption(sectors, 3).name):toEqual("EMPTY SLOT")
		T.expect(Model.caption(sectors, nil).kind):toEqual("idle")
	end)
end)

T.describe("EmoteWheelModel hitTest", function()
	T.it("returns nil inside the dead zone", function()
		local layout = Model.layout(desktop, 4)
		T.expect(Model.hitTest(Vector2.new(0, 0), layout, 4) == nil):toBeTruthy()
		T.expect(Model.hitTest(Vector2.new(layout.deadZoneRadius * 0.9, 0), layout, 4) == nil):toBeTruthy()
	end)

	T.it("maps the compass directions to the right slot at capacity 4", function()
		local layout = Model.layout(desktop, 4)
		local r = layout.radius
		T.expect(Model.hitTest(Vector2.new(0, -r), layout, 4)):toEqual(1)
		T.expect(Model.hitTest(Vector2.new(r, 0), layout, 4)):toEqual(3)
		T.expect(Model.hitTest(Vector2.new(0, r), layout, 4)):toEqual(2)
		T.expect(Model.hitTest(Vector2.new(-r, 0), layout, 4)):toEqual(4)
	end)

	T.it("maps all eight directions at capacity 8", function()
		local layout = Model.layout(desktop, 8)
		for index = 1, 8 do
			local offset = Model.slotOffset(index, 8, layout)
			T.expect(Model.hitTest(offset, layout, 8)):toEqual(index)
		end
	end)

	T.it("still resolves past the outer rim", function()
		local layout = Model.layout(desktop, 4)
		T.expect(Model.hitTest(Vector2.new(layout.radius * 3, 0), layout, 4)):toEqual(3)
	end)

	T.it("resolves to a neighbour rather than nil on a boundary", function()
		local layout = Model.layout(desktop, 4)
		local hit = Model.hitTest(Vector2.new(layout.radius, -layout.radius), layout, 4)
		T.expect(hit == 1 or hit == 3):toBeTruthy()
	end)
end)

T.describe("EmoteWheelModel stickOffset", function()
	T.it("ignores a resting stick", function()
		local layout = Model.layout(desktop, 4)
		T.expect(Model.stickOffset(Vector2.new(0.1, 0.1), layout).Magnitude):toEqual(0)
	end)

	T.it("maps stick-up to slot one and stick-right to slot two", function()
		local layout = Model.layout(desktop, 4)
		T.expect(Model.hitTest(Model.stickOffset(Vector2.new(0, 1), layout), layout, 4)):toEqual(1)
		T.expect(Model.hitTest(Model.stickOffset(Vector2.new(1, 0), layout), layout, 4)):toEqual(3)
	end)
end)

return true
