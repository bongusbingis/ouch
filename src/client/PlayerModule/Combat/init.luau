-- Name: init.luau
-- Author: Jack C.
-- Description: The combat input layer's public surface: raw device input in, device-independent intents out, so the rest of the game never touches the input service or mouse behavior directly for combat.
-- Created: 2026-08-20

--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CommonUtils = require(script.Parent:WaitForChild("CommonUtils"))
local PlayerModuleEventBus = CommonUtils.get("PlayerModuleEventBus")

local CombatCamera = require(script:WaitForChild("CombatCamera"))
local CombatConfig = require(script:WaitForChild("CombatConfig"))
local DeviceInput = require(script:WaitForChild("DeviceInput"))
local TouchIntent = require(script:WaitForChild("TouchIntent"))
local TouchRegions = require(script:WaitForChild("TouchRegions"))

local Combat = {}

export type Intent =
	"NormalThrow"
	| "BeginCharge"
	| "ReleaseCharge"
	| "CancelCharge"
	| "HammerAttack"
	| "EquipHammer"
	| "EquipDodgeball"
export type GestureEvent = TouchIntent.GestureEvent

local started = false
local inputEnabled = false
-- While a weapon is forced, the player's own equip controls go quiet. The
-- programmatic equipHammer/equipDodgeball below deliberately bypass this: they
-- are how the forced weapon gets set in the first place.
local weaponLocked = false
local listeners: { (Intent) -> () } = {}

local function emit(intent: Intent)
	for _, listener in listeners do
		local ok, err = pcall(listener, intent)
		if not ok then
			warn("[Combat] intent listener errored: " .. tostring(err))
		end
	end
end

local function isLive(): boolean
	return inputEnabled and CombatCamera.isActive()
end

local function cancelEverything()
	TouchIntent.cancelAll()
	DeviceInput.cancel()
end

local handlers = {
	onNormalThrow = function()
		emit("NormalThrow")
	end,
	onBeginCharge = function()
		emit("BeginCharge")
	end,
	onReleaseCharge = function()
		emit("ReleaseCharge")
	end,
	onCancelCharge = function()
		emit("CancelCharge")
	end,
	onHammer = function()
		emit("HammerAttack")
	end,
	onEquipHammer = function()
		Combat.requestWeaponEquip("Hammer")
	end,
	onEquipDodgeball = function()
		Combat.requestWeaponEquip("Dodgeball")
	end,
}

function Combat.setInputEnabled(value: boolean)
	if inputEnabled == value then
		return
	end
	inputEnabled = value
	if not value then
		cancelEverything()
	end
end

function Combat.setWeaponLocked(value: boolean)
	weaponLocked = value
end

function Combat.isWeaponLocked(): boolean
	return weaponLocked
end

function Combat.isInputEnabled(): boolean
	return inputEnabled
end

function Combat.isActive(): boolean
	return isLive()
end

function Combat.setCameraEnabled(value: boolean)
	CombatCamera.setEnabled(value)
end

function Combat.isCameraEnabled(): boolean
	return CombatCamera.isEnabled()
end

function Combat.requestCursor(reason: string)
	if CombatCamera.isCursorRequested(reason) then
		return
	end
	CombatCamera.requestCursor(reason)
	cancelEverything()
end

function Combat.releaseCursor(reason: string)
	CombatCamera.releaseCursor(reason)
end

function Combat.onIntent(listener: (Intent) -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function Combat.onGesture(listener: (GestureEvent) -> ()): () -> ()
	return TouchIntent.onGesture(listener)
end

function Combat.requestWeaponEquip(kind: string): boolean
	if weaponLocked or not isLive() then
		return false
	end
	if kind == "Hammer" then
		emit("EquipHammer")
		return true
	elseif kind == "Dodgeball" then
		emit("EquipDodgeball")
		return true
	end
	return false
end

function Combat.equipHammer()
	emit("EquipHammer")
end

function Combat.equipDodgeball()
	emit("EquipDodgeball")
end

function Combat.isCharging(): boolean
	return TouchIntent.isCharging()
end

function Combat.registerHudExclusion(name: string, rect: TouchRegions.Rect?)
	TouchRegions.setExclusion(name, rect)
end

function Combat.hammerPressed()
	if not isLive() then
		return
	end
	emit("HammerAttack")
end

function Combat.isCameraTouchActive(): boolean
	return TouchIntent.isCameraTouchActive()
end

function Combat.getConfig()
	return CombatConfig
end

export type InputGeometry = {
	viewport: Vector2,
	-- Where a tap or a hold is read: the whole viewport below the platform inset.
	pressCenter: Vector2,
	-- How far a finger may drift and still count as a tap, in pixels.
	tapDriftPixels: number,
	-- How long a press must be held before it becomes a charge, in seconds.
	holdDelaySeconds: number,
	-- The region a bottom swipe must START inside, in viewport pixels.
	swipeRect: TouchRegions.Rect,
	-- A representative free point inside that region, biased to the aiming thumb,
	-- for a prompt that must land where the swipe is actually performed.
	swipeAnchor: Vector2,
	-- Where the movement stick is read, in viewport pixels.
	moveRect: TouchRegions.Rect,
	-- The on-screen primary action button (the touch hammer/BONK control), if it
	-- is currently shown, so a prompt can point at the real control.
	actionButtonRect: TouchRegions.Rect?,
	-- How far that swipe must travel to register, in pixels.
	swipeDistancePixels: number,
	swipeEnabled: boolean,
}

-- The real geometry of every touch region, in viewport pixels. Instructional UI
-- reads it from here instead of re-deriving it from the config, so a prompt
-- that points at "where to press" cannot drift from where input is read.
function Combat.inputGeometry(): InputGeometry
	return {
		viewport = TouchRegions.viewportSize(),
		pressCenter = TouchRegions.gameplayCenter(),
		tapDriftPixels = TouchRegions.scale(CombatConfig.Tap.MaxDistance),
		holdDelaySeconds = CombatConfig.Charge.HoldDelay,
		swipeRect = TouchRegions.bottomSwipeRect(),
		swipeAnchor = TouchRegions.bottomSwipeAnchor(),
		moveRect = TouchRegions.thumbstickRect(),
		actionButtonRect = TouchRegions.getExclusion("HammerButton"),
		swipeDistancePixels = TouchRegions.scale(CombatConfig.BottomSwipe.MinDistance),
		swipeEnabled = CombatConfig.BottomSwipe.Enabled,
	}
end

function Combat.start()
	if started then
		return
	end
	started = true

	TouchRegions.start()

	PlayerModuleEventBus:subscribe("HUD_REGION"):Connect(function(name: string, rect: TouchRegions.Rect?)
		TouchRegions.setExclusion(name, rect)
	end)
	CombatCamera.setChargingPredicate(TouchIntent.isCharging)
	CombatCamera.setCameraSuppressedPredicate(TouchIntent.isCameraSuppressed)
	CombatCamera.start()
	TouchIntent.setHandlers(handlers)
	DeviceInput.setHandlers(handlers)
	DeviceInput.setEnabledPredicate(isLive)
	DeviceInput.start()

	UserInputService.TouchStarted:Connect(function(input, sunk)
		if not isLive() then
			return
		end
		TouchIntent.began(input, sunk)
	end)
	UserInputService.TouchMoved:Connect(function(input, sunk)
		TouchIntent.moved(input, sunk)
	end)
	UserInputService.TouchEnded:Connect(function(input)
		TouchIntent.ended(input)
	end)

	RunService.Heartbeat:Connect(TouchIntent.step)
	local player = Players.LocalPlayer
	player.CharacterRemoving:Connect(cancelEverything)
	CombatCamera.onChanged(function(active)
		if not active then
			cancelEverything()
		end
	end)
end

return Combat
