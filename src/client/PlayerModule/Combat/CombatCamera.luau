-- Description: Owns combat camera behavior and mouse cursor ownership: locks the camera for aiming, suppresses it while charging or when a menu asks for the cursor, and notifies listeners when that state changes.

--!strict

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraModule = require(script.Parent.Parent:WaitForChild("CameraModule"))
local CameraInput = require(script.Parent.Parent:WaitForChild("CameraModule"):WaitForChild("CameraInput"))
local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local CombatCamera = {}

local RENDER_NAME = "CombatCameraState"

local enabled = false
local started = false
local cursorRequests: { [string]: boolean } = {}
local appliedCursor: boolean? = nil
local listeners: { (boolean) -> () } = {}
local chargingPredicate: () -> boolean = function()
	return false
end
local suppressPredicate: () -> boolean = function()
	return false
end

local function cursorIsRequested(): boolean
	return next(cursorRequests) ~= nil
end

local function isActive(): boolean
	return enabled and CombatConfig.CombatCamera.Enabled and not cursorIsRequested()
end

local function notify()
	local active = isActive()
	for _, listener in listeners do
		local ok, err = pcall(listener, active)
		if not ok then
			warn("[CombatCamera] listener errored: " .. tostring(err))
		end
	end
end

local function apply()
	local config = CombatConfig.CombatCamera
	local active = isActive()

	local controller = (CameraModule :: any).activeCameraController
	if controller then
		controller:SetIsMouseLocked(active)
		if active then
			controller:SetMouseLockOffset(config.ShoulderOffset)
		end
		controller.combatRotationType = if not active
			then nil
			elseif config.CharacterFollowsCameraYaw then Enum.RotationType.CameraRelative
			else Enum.RotationType.MovementRelative
	end

	local scale = 1
	if active then
		scale = config.MouseSensitivityMultiplier
		if chargingPredicate() then
			scale *= CombatConfig.Camera.ChargeSensitivityMultiplier
		end
		if suppressPredicate() then
			scale = 0
		end
	end
	CameraInput.setSensitivityScale(scale)

	local hideCursor = active and config.HideMouseCursor
	if appliedCursor ~= hideCursor and UserInputService.MouseEnabled then
		appliedCursor = hideCursor
		UserInputService.MouseIconEnabled = not hideCursor
	end
end

function CombatCamera.setChargingPredicate(predicate: () -> boolean)
	chargingPredicate = predicate
end

function CombatCamera.setCameraSuppressedPredicate(predicate: () -> boolean)
	suppressPredicate = predicate
end

function CombatCamera.setEnabled(value: boolean)
	if enabled == value then
		return
	end
	enabled = value
	apply()
	notify()
end

function CombatCamera.isEnabled(): boolean
	return enabled
end

function CombatCamera.isActive(): boolean
	return isActive()
end

function CombatCamera.requestCursor(reason: string)
	if cursorRequests[reason] then
		return
	end
	cursorRequests[reason] = true
	apply()
	notify()
end

function CombatCamera.isCursorRequested(reason: string): boolean
	return cursorRequests[reason] == true
end

function CombatCamera.releaseCursor(reason: string)
	if cursorRequests[reason] == nil then
		return
	end
	cursorRequests[reason] = nil
	apply()
	notify()
end

function CombatCamera.subscribe(listener: (boolean) -> ()): () -> ()
	table.insert(listeners, listener)
	listener(isActive())
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function CombatCamera.start()
	if started then
		return
	end
	started = true

	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value - 1, apply)

	UserInputService.WindowFocusReleased:Connect(function()
		CombatCamera.requestCursor("WindowFocus")
	end)
	UserInputService.WindowFocused:Connect(function()
		CombatCamera.releaseCursor("WindowFocus")
	end)
end

return CombatCamera
