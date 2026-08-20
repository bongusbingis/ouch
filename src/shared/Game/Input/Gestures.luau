--!strict

-- Pure touch-lifecycle classifier. One instance of this state per concurrent
-- touch, keyed by the caller on InputObject identity, so several fingers
-- classify independently: a drag in the action zone and a tap elsewhere in it
-- both resolve correctly.
--
-- Plain numbers throughout, no engine types, so the whole thing is testable
-- headlessly against synthetic event sequences.
--
-- A touch begins Undetermined. It becomes a Drag the moment accumulated travel
-- passes the threshold, or a Hold once it has been still for long enough.
-- Releasing an Undetermined touch is a Tap; releasing a Hold is a charged
-- release; releasing a Drag may still be a Swipe if it was fast and far enough.

local Gestures = {}

export type Phase = "Undetermined" | "Drag" | "Hold"

export type Settings = {
	DragThresholdPixels: number,
	TapMaxSeconds: number,
	HoldMinSeconds: number,
	ChargeFullSeconds: number,
	SwipeMinPixels: number,
	SwipeMaxSeconds: number,
	SwipeAngleToleranceDeg: number,
}

export type Touch = {
	phase: Phase,
	startX: number,
	startY: number,
	x: number,
	y: number,
	startedAt: number,
	travel: number,
	-- Movement seen while still Undetermined. The camera has to receive this
	-- once the touch promotes, or a drag visibly loses its first few pixels and
	-- reads as a stutter.
	pendingDeltaX: number,
	pendingDeltaY: number,
}

export type Release = {
	kind: "Tap" | "ChargedRelease" | "Swipe" | "None",
	-- ChargedRelease only: 0-1.
	charge: number,
	-- Swipe only: "Up" | "Down" | "Left" | "Right".
	direction: string?,
}

function Gestures.begin(x: number, y: number, now: number): Touch
	return {
		phase = "Undetermined",
		startX = x,
		startY = y,
		x = x,
		y = y,
		startedAt = now,
		travel = 0,
		pendingDeltaX = 0,
		pendingDeltaY = 0,
	}
end

-- Charge as a function of how long an input has been held. Ramps only after the
-- hold threshold, so an input that just misses the tap window does not release
-- at a surprising non-zero charge. Shared with the mouse button so a charged
-- throw takes exactly as long to build on every device -- if the ramps differed,
-- one device would have a strictly faster charged throw and this layer would be
-- handing out the advantage it exists to remove.
function Gestures.chargeFor(heldSeconds: number, settings: Settings): number
	local past = heldSeconds - settings.HoldMinSeconds
	if past <= 0 or settings.ChargeFullSeconds <= 0 then
		return 0
	end
	return math.clamp(past / settings.ChargeFullSeconds, 0, 1)
end

function Gestures.charge(touch: Touch, settings: Settings, now: number): number
	if touch.phase ~= "Hold" then
		return 0
	end
	return Gestures.chargeFor(now - touch.startedAt, settings)
end

-- Feeds one movement sample. Returns the phase after the update; the caller
-- checks whether it changed to know a promotion happened.
function Gestures.move(touch: Touch, x: number, y: number, deltaX: number, deltaY: number, settings: Settings): Phase
	touch.x = x
	touch.y = y
	touch.travel += math.sqrt(deltaX * deltaX + deltaY * deltaY)

	if touch.phase == "Undetermined" then
		touch.pendingDeltaX += deltaX
		touch.pendingDeltaY += deltaY
		if touch.travel > settings.DragThresholdPixels then
			touch.phase = "Drag"
		end
	end
	return touch.phase
end

-- Time-driven promotion. A finger that never moves still has to become a Hold,
-- and no movement event will arrive to trigger it.
function Gestures.step(touch: Touch, settings: Settings, now: number): Phase
	if touch.phase == "Undetermined" and now - touch.startedAt >= settings.HoldMinSeconds then
		touch.phase = "Hold"
	end
	return touch.phase
end

-- Consumes the movement buffered before promotion. Returns zeros afterwards, so
-- calling twice cannot apply the same delta to the camera twice.
function Gestures.takePendingDelta(touch: Touch): (number, number)
	local x, y = touch.pendingDeltaX, touch.pendingDeltaY
	touch.pendingDeltaX = 0
	touch.pendingDeltaY = 0
	return x, y
end

local function swipeDirection(dx: number, dy: number, toleranceDeg: number): string?
	local distance = math.sqrt(dx * dx + dy * dy)
	if distance <= 0 then
		return nil
	end
	-- Screen y grows downward, so up is negative dy.
	local candidates = {
		{ name = "Right", x = 1, y = 0 },
		{ name = "Left", x = -1, y = 0 },
		{ name = "Up", x = 0, y = -1 },
		{ name = "Down", x = 0, y = 1 },
	}
	local cosTolerance = math.cos(math.rad(toleranceDeg))
	for _, candidate in candidates do
		local dot = (dx * candidate.x + dy * candidate.y) / distance
		if dot >= cosTolerance then
			return candidate.name
		end
	end
	return nil
end

function Gestures.release(touch: Touch, settings: Settings, now: number): Release
	local duration = now - touch.startedAt
	local dx = touch.x - touch.startX
	local dy = touch.y - touch.startY

	-- A swipe is checked first: it is a drag that was fast and far enough to
	-- mean something more specific than "I moved the camera".
	if touch.phase == "Drag" then
		local distance = math.sqrt(dx * dx + dy * dy)
		if distance >= settings.SwipeMinPixels and duration <= settings.SwipeMaxSeconds then
			local direction = swipeDirection(dx, dy, settings.SwipeAngleToleranceDeg)
			if direction then
				return { kind = "Swipe", charge = 0, direction = direction }
			end
		end
		return { kind = "None", charge = 0, direction = nil }
	end

	if touch.phase == "Hold" then
		return { kind = "ChargedRelease", charge = Gestures.charge(touch, settings, now), direction = nil }
	end

	if duration <= settings.TapMaxSeconds then
		return { kind = "Tap", charge = 0, direction = nil }
	end
	-- Still Undetermined past the tap window but never promoted: the caller's
	-- step() was not running. Treat as a tap rather than swallowing the input.
	return { kind = "Tap", charge = 0, direction = nil }
end

-- Two taps close enough in time to count as one double tap. Kept here rather
-- than in the client layer so the window is testable.
function Gestures.isDoubleTap(previousTapAt: number?, now: number, settings: { DoubleTapMaxSeconds: number }): boolean
	return previousTapAt ~= nil and (now - previousTapAt) <= settings.DoubleTapMaxSeconds
end

return table.freeze(Gestures)
