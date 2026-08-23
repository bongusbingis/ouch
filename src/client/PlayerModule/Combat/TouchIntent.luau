--!strict

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))
local TouchRegions = require(script.Parent:WaitForChild("TouchRegions"))

-- Per-touch classification: deciding whether a finger meant to attack or to look
-- around, and never confusing the two.
--
-- Each touch owns a small record and a state. State only moves forward, and the
-- important edge is one-way: once a touch has been claimed by the camera it can
-- never produce an attack, no matter what the finger does afterwards. That single
-- rule removes almost every accidental throw, because the overwhelmingly common
-- accident is "I was moving the camera and it attacked".
--
-- This module is a pure observer of the camera. It never suppresses, redirects
-- or applies camera input -- CameraInput keeps complete ownership of every
-- touch, exactly as upstream wrote it. That is what makes aiming while charging
-- work for free, and it means there is no arbitration to lose: two systems
-- cannot fight over a touch when only one of them is steering.
--
-- When a touch is ambiguous, nothing happens. A missed gesture costs a player
-- one repeat; a false attack costs them a cooldown, their position, and their
-- trust in the controls.

local TouchIntent = {}

export type GestureKind =
	"Pending"
	| "SwipeCandidate"
	| "Camera"
	| "ChargeStarted"
	| "SwipeRecognized"
	| "TapRecognized"
	| "ChargeReleased"
	| "Cancelled"
	| "Ended"

export type GestureEvent = {
	kind: GestureKind,
	origin: Vector2?,
	position: Vector2?,
	progress: number,
	fromBottom: boolean,
}

export type State =
	-- Undecided. Still able to become any of the below.
	"Pending"
	-- Moved enough to be a look. Permanently disqualified from attacking.
	| "Camera"
	-- Held still long enough to be a charge. Still free to aim.
	| "Charging"
	-- Already produced its action. Cannot produce another.
	| "Consumed"
	-- Started somewhere that is not gameplay, or was cancelled.
	| "Ignored"

type Touch = {
	startX: number,
	startY: number,
	x: number,
	y: number,
	startedAt: number,
	-- Furthest the finger has been from where it landed. Peak rather than
	-- current, so returning to the start does not re-qualify a drag as a tap.
	maxDrift: number,
	velocity: number,
	hasVelocity: boolean,
	lastMovedAt: number,
	fromBottom: boolean,
	swipeAlive: boolean,
	-- While true this touch must not steer the camera. A swipe that pans the view
	-- while it throws is indistinguishable from a camera drag, which is the whole
	-- thing this gesture has to be told apart from.
	suppressCamera: boolean,
	state: State,
}

export type Handlers = {
	onNormalThrow: () -> (),
	onBeginCharge: () -> (),
	onReleaseCharge: () -> (),
	onCancelCharge: () -> (),
}

local touches: { [InputObject]: Touch } = {}
local chargeOwner: InputObject? = nil
local handlers: Handlers? = nil
local counters = { taps = 0, cameras = 0, charges = 0, swipes = 0, ambiguous = 0, cancelled = 0 }
local gestureListeners: { (GestureEvent) -> () } = {}

local function emitGesture(kind: GestureKind, touch: Touch?)
	local progress = 0
	if touch and touch.fromBottom then
		local dx, dy = touch.x - touch.startX, touch.y - touch.startY
		progress = math.clamp(
			math.sqrt(dx * dx + dy * dy) / math.max(TouchRegions.scale(CombatConfig.BottomSwipe.MinDistance), 1),
			0,
			1
		)
	end
	local event: GestureEvent = {
		kind = kind,
		origin = if touch then Vector2.new(touch.startX, touch.startY) else nil,
		position = if touch then Vector2.new(touch.x, touch.y) else nil,
		progress = progress,
		fromBottom = touch ~= nil and touch.fromBottom,
	}
	for _, listener in gestureListeners do
		local ok, err = pcall(listener, event)
		if not ok then
			warn("[CombatInput] gesture listener errored: " .. tostring(err))
		end
	end
end

local function log(message: string)
	if CombatConfig.Debug.LogClassification then
		print("[CombatInput] " .. message)
	end
end

local function fire(name: string)
	local resolved = handlers
	if resolved == nil then
		return
	end
	local callback = (resolved :: any)[name]
	if callback then
		local ok, err = pcall(callback)
		if not ok then
			warn("[CombatInput] handler " .. name .. " errored: " .. tostring(err))
		end
	end
end

-- Ends a swipe candidate and hands the camera straight back. Releasing on the
-- same line that kills the candidate is what stops a failed swipe from leaving
-- the view frozen.
local function killSwipe(touch: Touch)
	touch.swipeAlive = false
	touch.suppressCamera = false
end

local function distance(touch: Touch): number
	local dx, dy = touch.x - touch.startX, touch.y - touch.startY
	return math.sqrt(dx * dx + dy * dy)
end

-- Hands the touch to the camera for good. Idempotent, because several signals
-- can independently conclude the same thing on the same frame.
local function claimCamera(touch: Touch, reason: string)
	if touch.state == "Camera" then
		return
	end
	-- A charge that is already running is not undone by later movement: the
	-- player is aiming, which is the whole point of being able to charge and
	-- look at the same time.
	if touch.state == "Charging" or touch.state == "Consumed" then
		return
	end
	touch.state = "Camera"
	killSwipe(touch)
	emitGesture("Camera", touch)
	counters.cameras += 1
	log("-> Camera (" .. reason .. ")")
end

-- Everything an upward flick has to satisfy. Several independent signals rather
-- than one threshold, because any single one of them fires constantly during
-- ordinary camera panning.
local function evaluateBottomSwipe(touch: Touch, now: number): boolean
	if not touch.swipeAlive or touch.state ~= "Pending" then
		return false
	end

	local dx = touch.x - touch.startX
	-- Screen Y grows downward, so travelling up is negative.
	local dy = touch.y - touch.startY
	local travel = math.sqrt(dx * dx + dy * dy)
	if travel <= 1e-3 then
		return false
	end

	local duration = now - touch.startedAt
	if duration > CombatConfig.BottomSwipe.MaxDuration then
		killSwipe(touch)
		log("swipe cancelled: too slow")
		return false
	end

	-- Direction is only meaningful once the finger has actually gone somewhere.
	-- Judging it on the first 1-5px sample rejected nearly every real swipe,
	-- because that sample is dominated by digitizer noise and by the sideways
	-- roll a thumb makes as it starts to flick.
	if travel < TouchRegions.scale(CombatConfig.BottomSwipe.DirectionSampleMinPixels) then
		return false
	end

	local upDot = -dy / travel
	if upDot < CombatConfig.BottomSwipe.DirectionDot then
		killSwipe(touch)
		log("swipe cancelled: direction")
		return false
	end

	if travel < TouchRegions.scale(CombatConfig.BottomSwipe.MinDistance) then
		return false
	end
	-- Far enough to decide. Too slow at this distance means a deliberate pan, not
	-- a flick, and it is killed here rather than left alive until the duration
	-- runs out -- the camera is frozen for as long as the candidate lives, so a
	-- candidate that cannot win any more must not keep holding it.
	if touch.velocity < TouchRegions.scale(CombatConfig.BottomSwipe.MinVelocity) then
		killSwipe(touch)
		log("swipe cancelled: too slow for the distance")
		return false
	end
	return true
end

local function beginCharge(touch: Touch, input: InputObject)
	touch.state = "Charging"
	killSwipe(touch)
	chargeOwner = input
	emitGesture("ChargeStarted", touch)
	counters.charges += 1
	log("-> Charge")
	fire("onBeginCharge")
end

function TouchIntent.setHandlers(value: Handlers)
	handlers = value
end

function TouchIntent.onGesture(listener: (GestureEvent) -> ()): () -> ()
	table.insert(gestureListeners, listener)
	return function()
		local index = table.find(gestureListeners, listener)
		if index then
			table.remove(gestureListeners, index)
		end
	end
end

function TouchIntent.began(input: InputObject, sunk: boolean)
	-- Roblox already knows when UI swallowed a touch. Trusting that is both
	-- cheaper and more accurate than trying to work it out from geometry.
	if sunk then
		touches[input] = nil
		return
	end
	local x, y = input.Position.X, input.Position.Y
	if not TouchRegions.isGameplayArea(x, y) then
		log("ignored: outside gameplay area")
		return
	end

	local now = os.clock()
	touches[input] = {
		startX = x,
		startY = y,
		x = x,
		y = y,
		startedAt = now,
		maxDrift = 0,
		velocity = 0,
		hasVelocity = false,
		lastMovedAt = now,
		fromBottom = TouchRegions.isInBottomSwipeRegion(x, y),
		swipeAlive = TouchRegions.isInBottomSwipeRegion(x, y),
		suppressCamera = TouchRegions.isInBottomSwipeRegion(x, y),
		state = "Pending",
	}
	emitGesture(if TouchRegions.isInBottomSwipeRegion(x, y) then "SwipeCandidate" else "Pending", touches[input])
end

function TouchIntent.moved(input: InputObject, sunk: boolean)
	local touch = touches[input]
	if touch == nil then
		return
	end
	if sunk then
		-- UI took the touch mid-gesture. Drop it rather than guessing -- but hand
		-- back the charge first. ended() returns early for a touch that is no
		-- longer tracked, so without this chargeOwner stayed set forever and no
		-- further charge could ever begin.
		touches[input] = nil
		emitGesture("Cancelled", touch)
		if input == chargeOwner then
			chargeOwner = nil
			counters.cancelled += 1
			log("-> CancelCharge (taken by UI)")
			fire("onCancelCharge")
		end
		return
	end

	local now = os.clock()
	local x, y = input.Position.X, input.Position.Y
	local dt = now - touch.lastMovedAt
	if dt > 1e-4 then
		local stepX, stepY = x - touch.x, y - touch.y
		local sampled = math.sqrt(stepX * stepX + stepY * stepY) / dt
		if touch.hasVelocity then
			-- Smoothed so one noisy sample cannot claim the camera on its own.
			touch.velocity = touch.velocity * 0.5 + sampled * 0.5
		else
			-- Seeded from the first real sample rather than blended up from zero.
			-- Ramping from zero meant the estimate read low for several frames, so
			-- every speed threshold was silently stricter than its configured
			-- value, and more so the lower the frame rate.
			touch.velocity = sampled
			touch.hasVelocity = true
		end
		touch.lastMovedAt = now
	end
	touch.x, touch.y = x, y
	touch.maxDrift = math.max(touch.maxDrift, distance(touch))

	if touch.state ~= "Pending" then
		return
	end

	if touch.fromBottom then
		if evaluateBottomSwipe(touch, now) then
			touch.state = "Consumed"
			counters.swipes += 1
			emitGesture("SwipeRecognized", touch)
			log(("-> NormalThrow (swipe %dpx)"):format(math.floor(touch.maxDrift)))
			fire("onNormalThrow")
			return
		end
		-- Still a live swipe candidate: hold off on claiming the camera so a
		-- fast flick is not stolen by its own speed.
		if touch.swipeAlive then
			emitGesture("SwipeCandidate", touch)
			return
		end
	end

	if touch.maxDrift > TouchRegions.scale(CombatConfig.Camera.ClaimDistance) then
		claimCamera(touch, "displacement")
	elseif touch.velocity > TouchRegions.scale(CombatConfig.Camera.ClaimVelocity) then
		claimCamera(touch, "velocity")
	end
end

-- Time-driven promotion. A finger that lands and never moves produces no move
-- events at all, so the charge threshold has to be checked on a clock.
function TouchIntent.step()
	local now = os.clock()
	for input, touch in touches do
		if touch.state ~= "Pending" then
			continue
		end
		if chargeOwner ~= nil then
			continue
		end
		if now - touch.startedAt < CombatConfig.Charge.HoldDelay then
			continue
		end
		if touch.maxDrift > TouchRegions.scale(CombatConfig.Charge.HoldSlop) then
			continue
		end
		beginCharge(touch, input)
	end
end

function TouchIntent.ended(input: InputObject)
	local touch = touches[input]
	touches[input] = nil
	if touch == nil then
		return
	end

	if input == chargeOwner then
		chargeOwner = nil
	end

	if touch.state == "Charging" then
		emitGesture("ChargeReleased", touch)
		log("-> ReleaseCharge")
		fire("onReleaseCharge")
		return
	end
	if touch.state ~= "Pending" then
		-- Camera, Consumed and Ignored all end silently. This is the guard that
		-- stops one physical action producing two attacks.
		emitGesture("Ended", touch)
		return
	end

	-- Still Pending means the hold threshold was never reached, so the only
	-- question left is whether the finger stayed put.
	local duration = os.clock() - touch.startedAt
	if touch.maxDrift <= TouchRegions.scale(CombatConfig.Tap.MaxDistance) then
		counters.taps += 1
		emitGesture("TapRecognized", touch)
		log(("-> NormalThrow (tap %.2fs %dpx)"):format(duration, math.floor(touch.maxDrift)))
		fire("onNormalThrow")
		return
	end

	-- Neither clearly a tap nor clearly a look. Doing nothing is the right
	-- answer: a missed gesture is cheap, a throw the player did not ask for is
	-- not.
	counters.ambiguous += 1
	emitGesture("Cancelled", touch)
	log(("-> NoAction (ambiguous %.2fs %dpx)"):format(duration, math.floor(touch.maxDrift)))
end

-- Drops every touch and unwinds a charge if one was running. Used for death,
-- respawn, menus, focus loss and teardown -- anything that can swallow the
-- InputEnded that would otherwise have resolved the gesture.
function TouchIntent.cancelAll()
	local hadCharge = chargeOwner ~= nil
	local hadTouches = next(touches) ~= nil
	table.clear(touches)
	chargeOwner = nil
	if hadCharge then
		counters.cancelled += 1
		log("-> CancelCharge (interrupted)")
		fire("onCancelCharge")
	end
	if hadTouches then
		emitGesture("Cancelled", nil)
	end
end

-- True while any touch is mid-swipe. The camera reads this and stops taking
-- touch rotation for as long as it holds, so an intentional flick throws without
-- dragging the view with it.
function TouchIntent.isCameraSuppressed(): boolean
	for _, touch in touches do
		if touch.suppressCamera then
			return true
		end
	end
	return false
end

function TouchIntent.isCameraTouchActive(): boolean
	for _, touch in touches do
		if touch.state == "Camera" then
			return true
		end
	end
	return false
end

function TouchIntent.isCharging(): boolean
	return chargeOwner ~= nil
end

function TouchIntent.debugSnapshot(): ({ [InputObject]: Touch }, { [string]: number })
	return touches, counters
end

return TouchIntent
