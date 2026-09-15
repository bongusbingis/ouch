--!strict
local T = require(script.Parent.TestKit)
local Shove = require(script.Parent.Parent.Game.MapFeatures.ShoveTuning)
local Config = script.Parent.Parent.Parent.Config.Gameplay
local Features = require(Config.MapFeatures)
local Splashdown = require(Config.Splashdown)

T.describe("ShoveTuning", function()
	T.it("preserves unmarked arena responses", function()
		for _, defaults in { Features.Bumper, Features.RotorBump } do
			local response = Shove.resolve(defaults, nil, nil, nil)
			for _, key in { "KnockbackSpeed", "UpwardSpeed", "ShoveSeconds", "GuardSeconds" } do
				T.expect(response[key]):toEqual(defaults[key])
			end
		end
	end)
	T.it("gives course contacts a stronger bounded response covered by the movement allowance", function()
		for _, name in { "Rotor", "Bumper" } do
			local target = Splashdown.HazardResponse[name]
			local defaults = if name == "Rotor" then Features.RotorBump else Features.Bumper
			local result = Shove.resolve(defaults, target.Speed, target.UpwardSpeed, target.HoldSeconds)
			T.expect(result.KnockbackSpeed > defaults.KnockbackSpeed):toEqual(true)
			T.expect(result.ShoveSeconds > defaults.ShoveSeconds):toEqual(true)
			T.expect(result.ShoveSeconds <= 0.4):toEqual(true)
			T.expect(result.GuardSeconds > result.ShoveSeconds):toEqual(true)
		end
	end)
	T.it("bounds accidental extremes and ignores nonfinite or malformed attributes", function()
		local capped = Shove.resolve(Features.Bumper, 10000, -10, 60)
		T.expect(capped.KnockbackSpeed):toEqual(80)
		T.expect(capped.UpwardSpeed):toEqual(0)
		T.expect(capped.ShoveSeconds):toEqual(0.4)
		local invalid = Shove.resolve(Features.Bumper, math.huge, 0 / 0, "forever")
		T.expect(invalid.KnockbackSpeed):toEqual(Features.Bumper.KnockbackSpeed)
		T.expect(invalid.UpwardSpeed):toEqual(Features.Bumper.UpwardSpeed)
		T.expect(invalid.ShoveSeconds):toEqual(Features.Bumper.ShoveSeconds)
	end)
end)

return true
