-- Pins synchronous listener ordering, mutation behavior, isolation, and argument forwarding.
--!strict

local T = require(script.Parent.TestKit)
local Listeners = require(script.Parent.Parent.Game.Util.Listeners)

T.describe("Listeners", function()
	T.it("preserves duplicate callbacks and idempotent unsubscribe", function()
		local listeners = Listeners.new("test")
		local count = 0
		local callback = function()
			count += 1
		end
		local first = listeners.add(callback)
		local second = listeners.add(callback)
		listeners.emit()
		T.expect(count):toEqual(2)
		first()
		first()
		listeners.emit()
		T.expect(count):toEqual(3)
		second()
		listeners.emit()
		T.expect(count):toEqual(3)
	end)

	T.it("continues after a callback fails and forwards nil arguments", function()
		local listeners: Listeners.Collection<string, string?, number, string?> = Listeners.new("test")
		local received: { [any]: any } = {}
		listeners.add(function()
			error("expected listener failure")
		end)
		listeners.add(function(...)
			received = table.pack(...)
		end)
		listeners.emit("first", nil, 3, nil)
		T.expect(received.n):toEqual(4)
		T.expect(received[1]):toEqual("first")
		T.expect(received[2]):toBeNil()
		T.expect(received[3]):toEqual(3)
	end)

	for _, snapshotDispatch in { false, true } do
		local label = if snapshotDispatch then "snapshot" else "live"
		T.it(`preserves {label} removal and insertion during dispatch`, function()
			local listeners = Listeners.new("test", snapshotDispatch)
			local calls = {}
			local removeNext: () -> () = function() end
			listeners.add(function()
				table.insert(calls, "first")
				removeNext()
				listeners.add(function()
					table.insert(calls, "added")
				end)
			end)
			removeNext = listeners.add(function()
				table.insert(calls, "removed")
			end)
			listeners.emit()
			T.expect(table.concat(calls, ",")):toEqual(if snapshotDispatch then "first,removed" else "first,added")
		end)

		T.it(`preserves {label} clear during dispatch`, function()
			local listeners = Listeners.new("test", snapshotDispatch)
			local count = 0
			listeners.add(function()
				listeners.clear()
			end)
			listeners.add(function()
				count += 1
			end)
			listeners.emit()
			listeners.emit()
			T.expect(count):toEqual(if snapshotDispatch then 1 else 0)
		end)
	end

	T.it("supports nested synchronous dispatch", function()
		local listeners: Listeners.Collection<number> = Listeners.new("test", true)
		local calls = {}
		listeners.add(function(value)
			table.insert(calls, value)
			if value == 1 then
				listeners.emit(2)
			end
		end)
		listeners.add(function(value)
			table.insert(calls, value * 10)
		end)
		listeners.emit(1)
		T.expect(table.concat(calls, ",")):toEqual("1,2,20,10")
	end)

	T.it("allows publishers to read their latest state for each listener", function()
		local listeners: Listeners.Collection<number> = Listeners.new("test", true)
		local state = 1
		local received = 0
		listeners.add(function()
			state = 2
		end)
		listeners.add(function(value)
			received = value
		end)
		listeners.emitWith(function(callback)
			callback(state)
		end)
		T.expect(received):toEqual(2)
	end)
end)

return true
