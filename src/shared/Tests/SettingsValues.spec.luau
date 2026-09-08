-- Description: Spec for the centralized slider value-resolution path: clamping, step snapping without float drift, explicit allowed-value stops, and the alpha/value mapping every input method (click, drag, controller) shares.

--!strict

local T = require(script.Parent.TestKit)
local SettingsValues = require(script.Parent.Parent.Game.Settings.SettingsValues)

local CONTINUOUS = { Id = "Continuous", Type = "Slider", Min = 0, Max = 1, Default = 0.5 }
local INTEGER = { Id = "Integer", Type = "Slider", Min = 1, Max = 10, Step = 1, Default = 5 }
local STEPPED_DECIMAL = { Id = "Stepped", Type = "Slider", Min = 0.5, Max = 2, Step = 0.1, Default = 1 }
local ALLOWED = { Id = "Allowed", Type = "Slider", AllowedValues = { 30, 60, 90, 120, 144 }, Default = 60 }
local TOGGLE = { Id = "Toggle", Type = "Toggle", Values = { true, false }, Default = true }

T.describe("SettingsValues", function()
	T.describe("continuous sliders", function()
		T.it("clamps to the declared range", function()
			T.expect(SettingsValues.snapSlider(CONTINUOUS, -5)):toEqual(0)
			T.expect(SettingsValues.snapSlider(CONTINUOUS, 5)):toEqual(1)
			T.expect(SettingsValues.snapSlider(CONTINUOUS, 0.42)):toEqual(0.42)
		end)

		T.it("falls back to the default on non-finite input", function()
			T.expect(SettingsValues.snapSlider(CONTINUOUS, 0 / 0)):toEqual(CONTINUOUS.Default)
			T.expect(SettingsValues.snapSlider(CONTINUOUS, math.huge)):toEqual(CONTINUOUS.Default)
		end)

		T.it("maps alpha 0 and 1 to Min and Max", function()
			T.expect(SettingsValues.alphaToValue(CONTINUOUS, 0)):toEqual(0)
			T.expect(SettingsValues.alphaToValue(CONTINUOUS, 1)):toEqual(1)
			T.expect(SettingsValues.alphaToValue(CONTINUOUS, 0.5)):toEqual(0.5)
		end)

		T.it("round-trips value through alpha", function()
			local alpha = SettingsValues.valueToAlpha(CONTINUOUS, 0.3)
			T.expect(SettingsValues.alphaToValue(CONTINUOUS, alpha)):toBeNear(0.3, 1e-6)
		end)
	end)

	T.describe("integer step snapping", function()
		T.it("snaps to whole numbers only", function()
			T.expect(SettingsValues.snapSlider(INTEGER, 5.4)):toEqual(5)
			T.expect(SettingsValues.snapSlider(INTEGER, 5.6)):toEqual(6)
			T.expect(SettingsValues.snapSlider(INTEGER, 1)):toEqual(1)
			T.expect(SettingsValues.snapSlider(INTEGER, 10)):toEqual(10)
		end)

		T.it("clamps before snapping", function()
			T.expect(SettingsValues.snapSlider(INTEGER, 0)):toEqual(1)
			T.expect(SettingsValues.snapSlider(INTEGER, 99)):toEqual(10)
		end)
	end)

	T.describe("decimal step snapping", function()
		T.it("snaps cleanly without floating-point drift", function()
			for i = 0, 15 do
				local raw = 0.5 + i * 0.1 + 0.0000001
				local snapped = SettingsValues.snapSlider(STEPPED_DECIMAL, raw)
				local text = tostring(snapped)
				T.expect(#text <= 4):toBeTruthy()
			end
		end)

		T.it("produces the exact documented value set", function()
			T.expect(SettingsValues.snapSlider(STEPPED_DECIMAL, 0.75)):toEqual(0.8)
			T.expect(SettingsValues.snapSlider(STEPPED_DECIMAL, 0.74)):toEqual(0.7)
			T.expect(SettingsValues.snapSlider(STEPPED_DECIMAL, 2)):toEqual(2)
			T.expect(SettingsValues.snapSlider(STEPPED_DECIMAL, 0.5)):toEqual(0.5)
		end)
	end)

	T.describe("explicit allowed values", function()
		T.it("snaps to the nearest stop rather than a uniform step", function()
			T.expect(SettingsValues.snapSlider(ALLOWED, 45)):toEqual(30)
			T.expect(SettingsValues.snapSlider(ALLOWED, 46)):toEqual(60)
			T.expect(SettingsValues.snapSlider(ALLOWED, 1000)):toEqual(144)
			T.expect(SettingsValues.snapSlider(ALLOWED, -1000)):toEqual(30)
		end)

		T.it("spaces stops evenly along alpha by rank, not by value", function()
			T.expect(SettingsValues.alphaToValue(ALLOWED, 0)):toEqual(30)
			T.expect(SettingsValues.alphaToValue(ALLOWED, 1)):toEqual(144)
			T.expect(SettingsValues.alphaToValue(ALLOWED, 0.5)):toEqual(90)
		end)

		T.it("reports every stop as its own alpha rank", function()
			local stops = SettingsValues.stops(ALLOWED)
			for index, stop in stops do
				local expectedAlpha = (index - 1) / (#stops - 1)
				T.expect(SettingsValues.valueToAlpha(ALLOWED, stop)):toBeNear(expectedAlpha, 1e-9)
			end
		end)
	end)

	T.describe("stepIncrement", function()
		T.it("uses the declared step for stepped sliders", function()
			T.expect(SettingsValues.stepIncrement(INTEGER)):toEqual(1)
			T.expect(SettingsValues.stepIncrement(STEPPED_DECIMAL)):toEqual(0.1)
		end)

		T.it("derives a sensible increment for pure continuous sliders", function()
			T.expect(SettingsValues.stepIncrement(CONTINUOUS)):toEqual(0.05)
		end)
	end)

	T.describe("stepValue", function()
		T.it("moves one step at a time for stepped sliders", function()
			T.expect(SettingsValues.stepValue(INTEGER, 5, 1)):toEqual(6)
			T.expect(SettingsValues.stepValue(INTEGER, 5, -1)):toEqual(4)
			T.expect(SettingsValues.stepValue(INTEGER, 10, 1)):toEqual(10)
			T.expect(SettingsValues.stepValue(INTEGER, 1, -1)):toEqual(1)
		end)

		T.it("moves to the adjacent stop for explicit allowed values", function()
			T.expect(SettingsValues.stepValue(ALLOWED, 60, 1)):toEqual(90)
			T.expect(SettingsValues.stepValue(ALLOWED, 60, -1)):toEqual(30)
			T.expect(SettingsValues.stepValue(ALLOWED, 144, 1)):toEqual(144)
			T.expect(SettingsValues.stepValue(ALLOWED, 30, -1)):toEqual(30)
		end)

		T.it("uses the derived increment for continuous sliders", function()
			T.expect(SettingsValues.stepValue(CONTINUOUS, 0.5, 1)):toBeNear(0.55, 1e-9)
			T.expect(SettingsValues.stepValue(CONTINUOUS, 0.5, -1)):toBeNear(0.45, 1e-9)
		end)
	end)

	T.describe("toggle validation", function()
		T.it("accepts either declared value", function()
			T.expect(SettingsValues.isValidToggleValue(TOGGLE, true)):toEqual(true)
			T.expect(SettingsValues.isValidToggleValue(TOGGLE, false)):toEqual(true)
		end)

		T.it("rejects anything outside the declared pair", function()
			T.expect(SettingsValues.isValidToggleValue(TOGGLE, "true")):toEqual(false)
			T.expect(SettingsValues.isValidToggleValue(TOGGLE, nil)):toEqual(false)
		end)
	end)

	T.describe("normalize", function()
		T.it("routes toggles through value validation and falls back to default", function()
			T.expect(SettingsValues.normalize(TOGGLE, false)):toEqual(false)
			T.expect(SettingsValues.normalize(TOGGLE, "nonsense")):toEqual(true)
		end)

		T.it("routes sliders through snapping and rejects non-numbers", function()
			T.expect(SettingsValues.normalize(INTEGER, 5.9)):toEqual(6)
			T.expect(SettingsValues.normalize(INTEGER, "5")):toEqual(INTEGER.Default)
			T.expect(SettingsValues.normalize(INTEGER, true)):toEqual(INTEGER.Default)
		end)
	end)
end)

return true
