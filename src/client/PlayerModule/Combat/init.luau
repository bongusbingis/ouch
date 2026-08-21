--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CommonUtils = require(script.Parent:WaitForChild("CommonUtils"))
local PlayerModuleEventBus = CommonUtils.get("PlayerModuleEventBus")

local CombatCamera = require(script:WaitForChild("CombatCamera"))
local CombatConfig = require(script:WaitForChild("CombatConfig"))
local CombatDebug = require(script:WaitForChild("CombatDebug"))
local DeviceInput = require(script:WaitForChild("DeviceInput"))
local TouchIntent = require(script:WaitForChild("TouchIntent"))
local TouchRegions = require(script:WaitForChild("TouchRegions"))

-- The combat input layer: raw device input in, device-independent intent out.
--
-- This is the whole public surface. The game never touches UserInputService,
-- MouseBehavior or MouseIconEnabled for combat purposes -- it enables combat,
-- listens for intents, and asks for the cursor when a menu needs one.
--
--   raw input  ->  classification  ->  intent  ->  weapon systems
--
-- Intents are requests, not outcomes. Whether a throw is legal, what it costs,
-- how far it goes and whether it hits are all decisions for the weapon and
-- server code downstream. Nothing here knows a dodgeball from a hammer beyond
-- which button was pressed.
--
-- Defaults are off with a free cursor. The lobby is a menu and must keep its
-- pointer; the arena turns combat on when a match starts. That way a place that
-- never mentions this module behaves exactly like stock Roblox.

local Combat = {}

export type Intent = "NormalThrow" | "BeginCharge" | "ReleaseCharge" | "CancelCharge" | "HammerAttack"

local started = false
local inputEnabled = false
local listeners: { (Intent) -> () } = {}

local function emit(intent: Intent)
	for _, listener in listeners do
		local ok, err = pcall(listener, intent)
		if not ok then
			warn("[Combat] intent listener errored: " .. tostring(err))
		end
	end
end

-- Combat input is live only when it is switched on and the camera is actually
-- in combat mode. Tying them together means a menu that asks for the cursor also
-- silences attacks, with no second flag for callers to remember.
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
}

--==================================================================
-- Public API
--==================================================================

-- Master switch for producing combat intents. Off during results, cutscenes,
-- intermission, the lobby, or anywhere attacking makes no sense.
function Combat.setInputEnabled(value: boolean)
	if inputEnabled == value then
		return
	end
	inputEnabled = value
	if not value then
		cancelEverything()
	end
end

function Combat.isInputEnabled(): boolean
	return inputEnabled
end

-- Over-the-shoulder locked camera. Independent of input: a spectator or a
-- cutscene may want the framing without the attacks, and vice versa.
function Combat.setCameraEnabled(value: boolean)
	CombatCamera.setEnabled(value)
end

function Combat.isCameraEnabled(): boolean
	return CombatCamera.isEnabled()
end

-- Ask for the pointer back while a menu is open, keyed by who wants it. Combat
-- input goes quiet for as long as any request is outstanding, and the cursor
-- only returns to the game when the last requester releases.
function Combat.requestCursor(reason: string)
	-- Guarded because callers poll this every frame. Unguarded, cancelEverything
	-- ran 60x a second for the whole mode vote, clearing the touch table before
	-- any gesture could be tracked.
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

-- True while a charge is building on any device, for HUD and pose systems that
-- want to reflect it without tracking presses themselves.
function Combat.isCharging(): boolean
	return TouchIntent.isCharging()
end

-- Screen space owned by a HUD control, so touches there never become attacks.
-- Pass nil to clear. The hammer button is the expected caller.
function Combat.registerHudExclusion(name: string, rect: TouchRegions.Rect?)
	TouchRegions.setExclusion(name, rect)
end

-- For an on-screen hammer button to call directly. A button press is
-- unambiguous, so it bypasses classification entirely -- the touch belongs to
-- the hammer from the moment it lands and can never become a look or a throw.
function Combat.hammerPressed()
	if not isLive() then
		return
	end
	emit("HammerAttack")
end

-- True while any touch is being used to look around. Presentation systems that
-- want to know the player is actively aiming read this rather than keeping their
-- own touch listener.
function Combat.isCameraTouchActive(): boolean
	return TouchIntent.isCameraTouchActive()
end

function Combat.getConfig()
	return CombatConfig
end

function Combat.start()
	if started then
		return
	end
	started = true

	TouchRegions.start()

	-- The movement stick and jump button report their own rectangles. Position
	-- guessing cannot work here: a dynamic thumbstick materialises wherever the
	-- player's thumb lands, so only the control itself knows where it is.
	PlayerModuleEventBus:subscribe("HUD_REGION"):Connect(function(name: string, rect: TouchRegions.Rect?)
		TouchRegions.setExclusion(name, rect)
	end)
	CombatCamera.setChargingPredicate(TouchIntent.isCharging)
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
	-- Not gated: a release has to resolve its own gesture even if combat was
	-- switched off mid-press, or the charge never unwinds.
	UserInputService.TouchEnded:Connect(function(input)
		TouchIntent.ended(input)
	end)

	RunService.Heartbeat:Connect(TouchIntent.step)
	CombatDebug.start()

	-- Anything that can swallow the release that would have ended a gesture.
	local player = Players.LocalPlayer
	player.CharacterRemoving:Connect(cancelEverything)
	CombatCamera.onChanged(function(active)
		if not active then
			cancelEverything()
		end
	end)
end

return Combat
