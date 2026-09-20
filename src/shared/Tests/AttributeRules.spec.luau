--!strict

local T = require(script.Parent.TestKit)
local Rules = require(script.Parent.Parent.Game.MapFeatures.AttributeRules)

local bounds = {
	CapDegrees = { 10, 80 },
	RetriggerCooldown = { 0.1, 10 },
	BounceSpeed = { 1, 160 },
	FloatFactor = { 0, 0.9 },
	RollOffSpeed = { 8, 80 },
	ShoveSeconds = { 0.08, 0.4 },
	GuardSeconds = { 0.3, 10 },
	ConveyorSpeed = { -80, 80 },
	RespawnSeconds = { 0, 120 },
	DropDelaySeconds = { 0.1, 10 },
	FanDirection = { -1, 1 },
	FanColumnHeight = { 1, 100 },
	FanBallSpeed = { 0, 80 },
	LaunchSpeed = { 1, 160 },
	MaxTiltDegrees = { 1, 85 },
	SeesawResponse = { 0.1, 10 },
}

local function contains(value: string?, fragment: string): boolean
	return value ~= nil and string.find(value, fragment, 1, true) ~= nil
end

T.describe("AttributeRules authored feature values", function()
	T.it("accepts both valid limits for all 16 numeric overrides", function()
		local count = 0
		for key, range in bounds do
			T.expect(Rules.isFeatureValueKey(key)):toBeTruthy()
			T.expect(Rules.checkPresentValue("Workspace.Test", key, range[1])):toEqual(nil)
			T.expect(Rules.checkPresentValue("Workspace.Test", key, range[2])):toEqual(nil)
			count += 1
		end
		T.expect(count):toEqual(16)
	end)

	T.it("keeps absent optional overrides valid in the attribute map", function()
		local registered = { CapDegrees = "CapDegrees", FanAxis = "FanAxis" }
		local errors, warnings = Rules.validate({}, registered, nil, "Workspace.Test")
		T.expect(#errors):toEqual(0)
		T.expect(#warnings):toEqual(0)
	end)

	T.it("reports exact paths, values, ranges, and corrections", function()
		local wrongType = Rules.checkPresentValue("Workspace.Scriptables.Pad", "LaunchSpeed", "fast")
		T.expect(contains(wrongType, "Workspace.Scriptables.Pad.LaunchSpeed")):toBeTruthy()
		T.expect(contains(wrongType, "fast (string)")):toBeTruthy()
		T.expect(contains(wrongType, "1..160")):toBeTruthy()
		T.expect(contains(wrongType, "set LaunchSpeed")):toBeTruthy()
		for _, bad in { 0 / 0, math.huge, -math.huge, 0, 161 } do
			T.expect(contains(Rules.checkPresentValue("Workspace.Scriptables.Pad", "LaunchSpeed", bad), "LaunchSpeed"))
				:toBeTruthy()
		end
	end)

	T.it("rejects the fan sign gap and axis values outside each domain", function()
		T.expect(contains(Rules.checkPresentValue("Workspace.Fan", "FanDirection", 0), "-1 or 1")):toBeTruthy()
		for _, key in { "RotorAxis", "FanAxis", "ConveyorAxis" } do
			for _, axis in { "X", "Y", "Z" } do
				T.expect(Rules.checkPresentValue("Workspace.Part", key, axis)):toEqual(nil)
			end
			T.expect(contains(Rules.checkPresentValue("Workspace.Part", key, "W"), "X, Y, or Z")):toBeTruthy()
		end
		T.expect(Rules.checkPresentValue("Workspace.Part", "SeesawAxis", "X")):toEqual(nil)
		T.expect(Rules.checkPresentValue("Workspace.Part", "SeesawAxis", "Z")):toEqual(nil)
		T.expect(contains(Rules.checkPresentValue("Workspace.Part", "SeesawAxis", "Y"), "X or Z")):toBeTruthy()
		T.expect(contains(Rules.checkPresentValue("Workspace.Part", "SeesawAxis", 1), "1 (number)")):toBeTruthy()
	end)

	T.it("uses the same rule from validate without generic duplicate messages", function()
		local errors = Rules.validate(
			{ ConveyorSpeed = 999, SeesawAxis = "Y" },
			{ ConveyorSpeed = "ConveyorSpeed", SeesawAxis = "SeesawAxis" },
			nil,
			"Workspace.Root.Part"
		)
		T.expect(#errors):toEqual(2)
		T.expect(contains(errors[1] .. errors[2], "Workspace.Root.Part.ConveyorSpeed")):toBeTruthy()
		T.expect(contains(errors[1] .. errors[2], "Workspace.Root.Part.SeesawAxis")):toBeTruthy()
	end)

	T.it("fails a developer read of an unregistered feature key", function()
		local ok, reason = pcall(Rules.checkPresentValue, "Workspace.Part", "UnknownSpeed", 3)
		T.expect(not ok):toBeTruthy()
		T.expect(contains(tostring(reason), "unregistered feature override key")):toBeTruthy()
	end)
end)

return true
