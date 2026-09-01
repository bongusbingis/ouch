-- Name: InputBuffer.spec.luau
-- Author: Jack C.
-- Description: Spec for the one-slot input buffer: firing inside the window, dropping after it, consuming exactly once, and keeping only the newest input.
-- Created: 2026-08-19

--!strict

local T = require(script.Parent.TestKit)
local InputBuffer = require(script.Parent.Parent.Game.Input.InputBuffer)

T.describe("InputBuffer", function()
	T.it("returns an action taken inside the window", function()
		local buffer = InputBuffer.new()
		InputBuffer.push(buffer, "Throw", 0)
		T.expect(InputBuffer.take(buffer, 0.1, 0.15)):toEqual("Throw")
	end)

	T.it("drops an action silently once the window passes", function()
		local buffer = InputBuffer.new()
		InputBuffer.push(buffer, "Throw", 0)
		T.expect(InputBuffer.take(buffer, 0.2, 0.15)):toBeNil()
	end)

	T.it("consumes the action so it can never fire twice", function()
		local buffer = InputBuffer.new()
		InputBuffer.push(buffer, "Throw", 0)
		InputBuffer.take(buffer, 0.05, 0.15)
		T.expect(InputBuffer.take(buffer, 0.06, 0.15)):toBeNil()
	end)

	T.it("keeps only the newest input", function()
		local buffer = InputBuffer.new()
		InputBuffer.push(buffer, "Throw", 0)
		InputBuffer.push(buffer, "Catch", 0.05)
		T.expect(InputBuffer.take(buffer, 0.1, 0.15)):toEqual("Catch")
	end)

	T.it("re-arms the window when replaced, so a newer input is not aged out early", function()
		local buffer = InputBuffer.new()
		InputBuffer.push(buffer, "Throw", 0)
		InputBuffer.push(buffer, "Catch", 0.14)
		T.expect(InputBuffer.take(buffer, 0.2, 0.15)):toEqual("Catch")
	end)

	T.it("peeks without consuming", function()
		local buffer = InputBuffer.new()
		InputBuffer.push(buffer, "Throw", 0)
		T.expect(InputBuffer.peek(buffer, 0.05, 0.15)):toEqual("Throw")
		T.expect(InputBuffer.take(buffer, 0.05, 0.15)):toEqual("Throw")
	end)

	T.it("is empty to start", function()
		T.expect(InputBuffer.take(InputBuffer.new(), 0, 0.15)):toBeNil()
	end)
end)

return true
