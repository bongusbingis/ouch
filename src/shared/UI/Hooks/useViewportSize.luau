-- Description: React hook exposing the current viewport size, updating as the camera and window change, so layouts can respond per device.

--!strict

local Workspace = game:GetService("Workspace")

local useExternalStore = require(script.Parent.useExternalStore)

local callbacks: { [number]: (Vector2) -> () } = {}
local nextCallbackId = 0
local cameraConnection: RBXScriptConnection? = nil
local workspaceConnection: RBXScriptConnection? = nil

local function getSnapshot(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.zero
end

local function emit()
	local value = getSnapshot()
	for _, callback in callbacks do
		callback(value)
	end
end

local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(emit)
	end
	emit()
end

local function subscribe(callback: (Vector2) -> ()): () -> ()
	nextCallbackId += 1
	local callbackId = nextCallbackId
	callbacks[callbackId] = callback
	if workspaceConnection == nil then
		workspaceConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
		watchCamera()
	end
	return function()
		callbacks[callbackId] = nil
		if next(callbacks) == nil then
			if cameraConnection then
				cameraConnection:Disconnect()
				cameraConnection = nil
			end
			if workspaceConnection then
				workspaceConnection:Disconnect()
				workspaceConnection = nil
			end
		end
	end
end

return function(): Vector2
	return useExternalStore(getSnapshot, subscribe)
end
