-- Name: CourseSequence.spec.luau
-- Author: Jack C.
-- Description: Spec for the course draw: distinct courses while enough exist, deterministic under an injected chooser, and no immediate repeat when the roster must be reused.
-- Created: 2026-09-14

--!strict

local T = require(script.Parent.TestKit)
local CourseSequence = require(script.Parent.Parent.Game.Splashdown.CourseSequence)

local COURSES = { "A", "B", "C", "D", "E" }

T.describe("CourseSequence", function()
	T.it("draws distinct courses while the roster allows", function()
		local sequence = CourseSequence.draw(COURSES, 3, function()
			return 1
		end)
		T.expect(table.concat(sequence, ",")):toEqual("A,B,C")
		local seen = {}
		local seed = 7
		local function next(count: number): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed % count + 1
		end
		for _ = 1, 50 do
			local drawn = CourseSequence.draw(COURSES, 3, next)
			T.expect(#drawn):toEqual(3)
			table.clear(seen)
			for _, courseId in drawn do
				T.expect(seen[courseId]):toBeNil()
				seen[courseId] = true
			end
		end
	end)

	T.it("reuses the roster without an immediate repeat when it runs out", function()
		local sequence = CourseSequence.draw({ "A", "B" }, 3, function()
			return 1
		end)
		T.expect(table.concat(sequence, ",")):toEqual("A,B,A")
		local single = CourseSequence.draw({ "Only" }, 3, function()
			return 1
		end)
		T.expect(table.concat(single, ",")):toEqual("Only,Only,Only")
	end)
end)

return true
