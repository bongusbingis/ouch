-- Description: React hook exposing whether the player has asked for reduced motion, so components can skip animations.

--!strict

local GuiService = game:GetService("GuiService")

local useExternalStore = require(script.Parent.useExternalStore)

local callbacks: { [number]: (boolean) -> () } = {}
local nextCallbackId = 0
local connection: RBXScriptConnection? = nil

local function getSnapshot(): boolean
	return GuiService.ReducedMotionEnabled
end

local function subscribe(callback: (boolean) -> ()): () -> ()
	nextCallbackId += 1
	local callbackId = nextCallbackId
	callbacks[callbackId] = callback
	if connection == nil then
		connection = GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
			local value = getSnapshot()
			for _, listener in callbacks do
				listener(value)
			end
		end)
	end
	return function()
		callbacks[callbackId] = nil
		if next(callbacks) == nil and connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
	end
end

return function(): boolean
	return useExternalStore(getSnapshot, subscribe)
end
