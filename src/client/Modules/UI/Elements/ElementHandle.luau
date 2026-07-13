--!strict

local ElementTypes = require(script.Parent.ElementTypes)

type Cleanup = ElementTypes.Cleanup
type ElementHandle = ElementTypes.ElementHandle

local ElementHandle = {}

local function runCleanup(cleanup: Cleanup)
	if typeof(cleanup) == "function" then
		cleanup()
		return
	end

	if typeof(cleanup) == "RBXScriptConnection" then
		cleanup:Disconnect()
		return
	end

	if typeof(cleanup) == "Instance" then
		cleanup:Destroy()
		return
	end

	if type(cleanup) == "table" then
		if type(cleanup.Disconnect) == "function" then
			cleanup:Disconnect()
		elseif type(cleanup.Destroy) == "function" then
			cleanup:Destroy()
		elseif type(cleanup.destroy) == "function" then
			cleanup:destroy()
		end
	end
end

function ElementHandle.new(instance: GuiObject?): ElementHandle
	local cleanups: { Cleanup } = {}
	local destroyed = false
	local handle = {
		instance = instance,
	} :: any

	function handle:add(cleanup: Cleanup): Cleanup
		if destroyed then
			runCleanup(cleanup)
			return cleanup
		end

		table.insert(cleanups, cleanup)
		return cleanup
	end

	function handle:destroy()
		if destroyed then
			return
		end

		destroyed = true
		for index = #cleanups, 1, -1 do
			runCleanup(cleanups[index])
		end
		table.clear(cleanups)

		local mounted = handle.instance
		handle.instance = nil
		if mounted then
			mounted:Destroy()
		end
	end

	function handle:isDestroyed(): boolean
		return destroyed
	end

	return handle :: ElementHandle
end

return ElementHandle
