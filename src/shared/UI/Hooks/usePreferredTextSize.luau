--!strict

local GuiService = game:GetService("GuiService")

local useExternalStore = require(script.Parent.useExternalStore)

local callbacks: { [number]: (Enum.PreferredTextSize) -> () } = {}
local nextCallbackId = 0
local connection: RBXScriptConnection? = nil

local function getSnapshot(): Enum.PreferredTextSize
	return GuiService.PreferredTextSize
end

local function emit()
	local value = getSnapshot()
	for _, callback in callbacks do
		callback(value)
	end
end

local function subscribe(callback: (Enum.PreferredTextSize) -> ()): () -> ()
	nextCallbackId += 1
	local callbackId = nextCallbackId
	callbacks[callbackId] = callback
	if connection == nil then
		connection = GuiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(emit)
	end
	return function()
		callbacks[callbackId] = nil
		if next(callbacks) == nil and connection then
			connection:Disconnect()
			connection = nil
		end
	end
end

return function(): Enum.PreferredTextSize
	return useExternalStore(getSnapshot, subscribe)
end
