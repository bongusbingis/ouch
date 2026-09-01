-- Name: Gestures.luau
-- Author: Jack C.
-- Description: Pure touch-lifecycle classifier that turns one finger's event stream into a tap, hold, charged release, drag, or swipe using plain numbers so it can be tested headlessly.
-- Created: 2026-08-19

--!strict

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
	pendingDeltaX: number,
	pendingDeltaY: number,
}

export type Release = {
	kind: "Tap" | "ChargedRelease" | "Swipe" | "None",
	charge: number,
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

function Gestures.step(touch: Touch, settings: Settings, now: number): Phase
	if touch.phase == "Undetermined" and now - touch.startedAt >= settings.HoldMinSeconds then
		touch.phase = "Hold"
	end
	return touch.phase
end

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
	return { kind = "Tap", charge = 0, direction = nil }
end

function Gestures.isDoubleTap(previousTapAt: number?, now: number, settings: { DoubleTapMaxSeconds: number }): boolean
	return previousTapAt ~= nil and (now - previousTapAt) <= settings.DoubleTapMaxSeconds
end

return table.freeze(Gestures)
