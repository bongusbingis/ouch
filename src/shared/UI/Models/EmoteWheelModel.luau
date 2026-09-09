-- Name: EmoteWheelModel.luau
-- Author: Jack C.
-- Description: Pure geometry, sector and hit-test logic for the radial emote selector, kept free of React and instances so the wheel's selection behaviour is unit-testable on every capacity and viewport.
-- Created: 2026-09-09
--!strict

local Config = script.Parent.Parent.Parent.Parent.Config

local WheelConfig = require(Config:WaitForChild("Interface"):WaitForChild("EmoteWheel"))
local Emotes = require(Config:WaitForChild("Cosmetics"):WaitForChild("Emotes"))

local EmoteWheelModel = {}

export type Layout = {
	diameter: number,
	radius: number,
	deadZoneRadius: number,
	ringRadius: number,
	tilePx: number,
	labelTextPx: number,
	centerLabelTextPx: number,
	sectorArcDegrees: number,
}

export type Sector = {
	index: number,
	emoteId: string?,
	displayName: string,
	filled: boolean,
	centerAngleDeg: number,
	startAngleDeg: number,
	endAngleDeg: number,
}

local function settings()
	return WheelConfig
end

function EmoteWheelModel.capacity(value: any): number
	local capacity = if type(value) == "number" then math.floor(value) else Emotes.BaseSlots
	return math.clamp(capacity, 1, Emotes.MaxSlots)
end

function EmoteWheelModel.layout(viewport: Vector2, capacity: number): Layout
	local cfg = settings()
	local widthBudget = viewport.X - 2 * cfg.EdgeMarginPx
	local heightBudget = viewport.Y - 2 * cfg.EdgeMarginPx - cfg.CaptionReservePx
	local diameter = math.clamp(viewport.Y * cfg.DiameterScale, cfg.MinDiameterPx, cfg.MaxDiameterPx)
	diameter = math.max(math.min(diameter, widthBudget, heightBudget), 120)
	local radius = diameter / 2
	local tilePx = math.round(diameter * cfg.IconFraction)
	return {
		diameter = diameter,
		radius = radius,
		deadZoneRadius = radius * cfg.DeadZoneFraction,
		ringRadius = radius - tilePx / 2 - cfg.RingInsetPx,
		tilePx = tilePx,
		labelTextPx = cfg.LabelTextPx,
		centerLabelTextPx = cfg.CenterLabelTextPx,
		sectorArcDegrees = 360 / math.max(capacity, 1),
	}
end

-- Slot positions are cardinal-first so the first four never move when the
-- wheel grows to eight: 1 top, 2 bottom, 3 right, 4 left, then the diagonals.
local CARDINAL_FIRST = { 0, 180, 90, 270, 45, 135, 225, 315 }

function EmoteWheelModel.centerAngle(index: number, capacity: number): number
	if (capacity == 4 or capacity == 8) and CARDINAL_FIRST[index] then
		return CARDINAL_FIRST[index]
	end
	return (index - 1) * 360 / math.max(capacity, 1)
end

local function angularDistance(a: number, b: number): number
	local delta = math.abs(a - b) % 360
	return math.min(delta, 360 - delta)
end

function EmoteWheelModel.sectors(slots: { string? }, capacity: number): { Sector }
	local arc = 360 / math.max(capacity, 1)
	local sectors = {}
	for index = 1, capacity do
		local emoteId = slots[index]
		local clip = if emoteId then Emotes.Clips[emoteId] else nil
		local center = EmoteWheelModel.centerAngle(index, capacity)
		sectors[index] = {
			index = index,
			emoteId = if clip then emoteId else nil,
			displayName = if clip then string.upper(clip.DisplayName) else "EMPTY",
			filled = clip ~= nil,
			centerAngleDeg = center,
			startAngleDeg = center - arc / 2,
			endAngleDeg = center + arc / 2,
		}
	end
	return sectors
end

-- Degrees from twelve o'clock, clockwise, for a screen-space offset (Y down).
function EmoteWheelModel.angleOf(offset: Vector2): number
	return (math.deg(math.atan2(offset.X, -offset.Y)) + 360) % 360
end

-- Sector index under the cursor, or nil inside the dead zone. Gaps between
-- tiles are visual only: hit-testing always resolves to the nearest sector so
-- the selection never flickers off while sweeping across a boundary.
function EmoteWheelModel.hitTest(offset: Vector2, layout: Layout, capacity: number): number?
	if capacity < 1 or offset.Magnitude < layout.deadZoneRadius then
		return nil
	end
	local angle = EmoteWheelModel.angleOf(offset)
	local best, bestDistance = 1, math.huge
	for index = 1, capacity do
		local distance = angularDistance(angle, EmoteWheelModel.centerAngle(index, capacity))
		if distance < bestDistance then
			best, bestDistance = index, distance
		end
	end
	return best
end

-- Pixel offset of a tile centre from the wheel centre.
function EmoteWheelModel.slotOffset(index: number, capacity: number, layout: Layout): Vector2
	local radians = math.rad(EmoteWheelModel.centerAngle(index, capacity))
	return Vector2.new(
		math.round(math.sin(radians) * layout.ringRadius),
		math.round(-math.cos(radians) * layout.ringRadius)
	)
end

-- Converts a thumbstick vector (Y up) into a screen-space offset usable by hitTest.
function EmoteWheelModel.stickOffset(stick: Vector2, layout: Layout): Vector2
	if stick.Magnitude < settings().StickDeadZone then
		return Vector2.new(0, 0)
	end
	return Vector2.new(stick.X, -stick.Y).Unit * layout.radius
end

return EmoteWheelModel
