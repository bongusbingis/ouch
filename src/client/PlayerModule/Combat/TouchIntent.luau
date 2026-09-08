-- Description: Classifies touch input into combat intents, tracking each finger's lifecycle to separate camera drags from taps, charged holds, and bottom-screen swipes.

--!strict

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))
local TouchRegions = require(script.Parent:WaitForChild("TouchRegions"))

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

export type State = "Pending" | "Camera" | "Charging" | "Consumed" | "Ignored"

type Touch = {
	startX: number,
	startY: number,
	x: number,
	y: number,
	startedAt: number,
	maxDrift: number,
	velocity: number,
	hasVelocity: boolean,
	lastMovedAt: number,
	fromBottom: boolean,
	swipeAlive: boolean,
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

local function killSwipe(touch: Touch)
	touch.swipeAlive = false
	touch.suppressCamera = false
end

local function distance(touch: Touch): number
	local dx, dy = touch.x - touch.startX, touch.y - touch.startY
	return math.sqrt(dx * dx + dy * dy)
end

local function claimCamera(touch: Touch, reason: string)
	if touch.state == "Camera" then
		return
	end
	if touch.state == "Charging" or touch.state == "Consumed" then
		return
	end
	touch.state = "Camera"
	killSwipe(touch)
	emitGesture("Camera", touch)
	counters.cameras += 1
	log("-> Camera (" .. reason .. ")")
end

local function evaluateBottomSwipe(touch: Touch, now: number): boolean
	if not touch.swipeAlive or touch.state ~= "Pending" then
		return false
	end

	local dx = touch.x - touch.startX
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
			touch.velocity = touch.velocity * 0.5 + sampled * 0.5
		else
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
		emitGesture("Ended", touch)
		return
	end

	local duration = os.clock() - touch.startedAt
	if touch.maxDrift <= TouchRegions.scale(CombatConfig.Tap.MaxDistance) then
		counters.taps += 1
		emitGesture("TapRecognized", touch)
		log(("-> NormalThrow (tap %.2fs %dpx)"):format(duration, math.floor(touch.maxDrift)))
		fire("onNormalThrow")
		return
	end

	counters.ambiguous += 1
	emitGesture("Cancelled", touch)
	log(("-> NoAction (ambiguous %.2fs %dpx)"):format(duration, math.floor(touch.maxDrift)))
end

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
