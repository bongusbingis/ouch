-- Name: Gestures.spec.luau
-- Author: Jack C.
-- Description: Spec for the touch gesture classifier: taps, holds, charge ramping, drag promotion with buffered movement, swipe direction and tolerance, and double-tap pairing.
-- Created: 2026-08-19

--!strict

local T = require(script.Parent.TestKit)
local Gestures = require(script.Parent.Parent.Game.Input.Gestures)

local settings = {
	DragThresholdPixels = 12,
	TapMaxSeconds = 0.25,
	HoldMinSeconds = 0.25,
	ChargeFullSeconds = 0.7,
	SwipeMinPixels = 90,
	SwipeMaxSeconds = 0.35,
	SwipeAngleToleranceDeg = 35,
	DoubleTapMaxSeconds = 0.3,
}

T.describe("Gestures", function()
	T.it("classifies a quick still press as a tap", function()
		local touch = Gestures.begin(100, 100, 0)
		Gestures.step(touch, settings, 0.05)
		T.expect(Gestures.release(touch, settings, 0.1).kind):toEqual("Tap")
	end)

	T.it("promotes to a drag once travel passes the threshold", function()
		local touch = Gestures.begin(100, 100, 0)
		T.expect(Gestures.move(touch, 105, 100, 5, 0, settings)):toEqual("Undetermined")
		T.expect(Gestures.move(touch, 120, 100, 15, 0, settings)):toEqual("Drag")
	end)

	T.it("promotes a still touch to a hold on time alone", function()
		local touch = Gestures.begin(100, 100, 0)
		T.expect(Gestures.step(touch, settings, 0.1)):toEqual("Undetermined")
		T.expect(Gestures.step(touch, settings, 0.3)):toEqual("Hold")
	end)

	T.it("ramps charge only after the hold threshold", function()
		local touch = Gestures.begin(100, 100, 0)
		Gestures.step(touch, settings, 0.3)
		T.expect(Gestures.charge(touch, settings, 0.25)):toBeNear(0, 1e-6)
		T.expect(Gestures.charge(touch, settings, 0.25 + 0.35)):toBeNear(0.5, 1e-6)
		T.expect(Gestures.charge(touch, settings, 10)):toBeNear(1, 1e-6)
	end)

	T.it("releases a hold as a charged release", function()
		local touch = Gestures.begin(100, 100, 0)
		Gestures.step(touch, settings, 0.3)
		local release = Gestures.release(touch, settings, 0.25 + 0.7)
		T.expect(release.kind):toEqual("ChargedRelease")
		T.expect(release.charge):toBeNear(1, 1e-6)
	end)

	T.it("buffers pre-threshold movement so a promoted drag loses nothing", function()
		local touch = Gestures.begin(100, 100, 0)
		Gestures.move(touch, 104, 100, 4, 0, settings)
		Gestures.move(touch, 108, 100, 4, 0, settings)
		Gestures.move(touch, 125, 100, 17, 0, settings)
		local dx, dy = Gestures.takePendingDelta(touch)
		T.expect(dx):toBeNear(25, 1e-6)
		T.expect(dy):toBeNear(0, 1e-6)
		local againX = Gestures.takePendingDelta(touch)
		T.expect(againX):toBeNear(0, 1e-6)
	end)

	T.it("classifies a fast far drag as a swipe in the right direction", function()
		local touch = Gestures.begin(100, 300, 0)
		Gestures.move(touch, 100, 180, 0, -120, settings)
		local release = Gestures.release(touch, settings, 0.2)
		T.expect(release.kind):toEqual("Swipe")
		T.expect(release.direction):toEqual("Up")
	end)

	T.it("accepts a sloppy diagonal within the tolerance cone", function()
		local touch = Gestures.begin(100, 300, 0)
		Gestures.move(touch, 140, 180, 40, -120, settings)
		T.expect(Gestures.release(touch, settings, 0.2).direction):toEqual("Up")
	end)

	T.it("rejects a swipe that is too slow or too short", function()
		local slow = Gestures.begin(100, 300, 0)
		Gestures.move(slow, 100, 180, 0, -120, settings)
		T.expect(Gestures.release(slow, settings, 1).kind):toEqual("None")

		local short = Gestures.begin(100, 300, 0)
		Gestures.move(short, 100, 280, 0, -20, settings)
		T.expect(Gestures.release(short, settings, 0.1).kind):toEqual("None")
	end)

	T.it("ramps a button hold on the same curve a touch hold uses", function()
		local touch = Gestures.begin(0, 0, 0)
		Gestures.step(touch, settings, settings.HoldMinSeconds)
		local held = settings.HoldMinSeconds + settings.ChargeFullSeconds * 0.5
		T.expect(Gestures.chargeFor(held, settings)):toBeNear(Gestures.charge(touch, settings, held), 1e-9)
	end)

	T.it("gives no charge for a hold shorter than the threshold", function()
		T.expect(Gestures.chargeFor(settings.HoldMinSeconds * 0.5, settings)):toEqual(0)
		T.expect(Gestures.chargeFor(0, settings)):toEqual(0)
	end)

	T.it("caps charge at one however long the input is held", function()
		local forever = settings.HoldMinSeconds + settings.ChargeFullSeconds * 100
		T.expect(Gestures.chargeFor(forever, settings)):toEqual(1)
	end)

	T.it("pairs taps inside the double tap window only", function()
		T.expect(Gestures.isDoubleTap(0, 0.2, settings)):toBeTruthy()
		T.expect(not Gestures.isDoubleTap(0, 0.4, settings)):toBeTruthy()
		T.expect(not Gestures.isDoubleTap(nil, 0.1, settings)):toBeTruthy()
	end)
end)

return true
