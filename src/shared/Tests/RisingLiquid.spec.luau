--!strict
local T = require(script.Parent.TestKit)
local L = require(script.Parent.Parent.Game.MapFeatures.RisingLiquid)
T.describe("RisingLiquid", function()
	T.it("ignores the removed legacy liquid schema", function()
		T.expect(L.resolve({ RiseStuds = 60, RiseDelaySeconds = 20, RiseSeconds = 140 }) == nil):toEqual(true)
	end)
	T.it("requires the explicit liquid marker and fields", function()
		T.expect(L.resolve({ MaxHeight = 60, RiseStudsPerSecond = 2 }) == nil):toEqual(true)
		T.expect(pcall(L.resolve, { RisingLiquid = true, MaxHeight = 60 })):toEqual(false)
	end)
	T.it("waits at optional waypoints without a frame accumulator", function()
		local c = L.resolve({
			RisingLiquid = true,
			MaxHeight = 60,
			RiseStudsPerSecond = 2,
			StartDelaySeconds = 3,
			PauseWaypoints = "20:3,40:2",
		})
		T.expect(L.heightAt(11, c)):toEqual(20)
		T.expect(L.heightAt(14, c)):toEqual(22)
		T.expect(L.heightAt(24, c)):toEqual(40)
		T.expect(L.heightAt(26, c)):toEqual(42)
		T.expect(L.heightAt(35, c)):toEqual(60)
	end)
	T.it("rejects reversed pauses and zero speeds", function()
		T.expect(pcall(L.parsePauses, "40:2,20:3", 60)):toEqual(false)
		T.expect(pcall(L.resolve, { RisingLiquid = true, MaxHeight = 60, RiseStudsPerSecond = 0 })):toEqual(false)
	end)
end)
return true
