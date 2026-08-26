-- Name: ExternalStoreSubscription.spec.luau
-- Author: Jack C.
-- Description: Spec that the external store subscription helper catches a mutation between render and subscribe and forwards updates without a duplicate unchanged read.
-- Created: 2026-08-24

--!strict

local T = require(script.Parent.TestKit)
local connect = require(script.Parent.Parent.UI.Hooks.ExternalStoreSubscription)

T.describe("ExternalStoreSubscription", function()
	T.it("observes a mutation between render and subscription", function()
		local value = 1
		local updates = 0
		local disconnected = false
		local rendered = value
		value = 2
		local disconnect = connect(
			function()
				return value
			end,
			function(_listener)
				return function()
					disconnected = true
				end
			end,
			rendered,
			function()
				updates += 1
			end
		)
		T.expect(updates):toEqual(1)
		disconnect()
		T.expect(disconnected):toBeTruthy()
	end)

	T.it("forwards subscribed updates without a duplicate unchanged read", function()
		local value = 3
		local updates = 0
		local emit = nil
		connect(
			function()
				return value
			end,
			function(listener)
				emit = listener
				return function() end
			end,
			value,
			function()
				updates += 1
			end
		)
		T.expect(updates):toEqual(0)
		value = 4
		assert(emit)(value)
		T.expect(updates):toEqual(1)
	end)
end)

return true
