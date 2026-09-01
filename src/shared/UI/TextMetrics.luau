-- Name: TextMetrics.luau
-- Author: Jack C.
-- Description: Text measurement helpers that fit labels to a box, scale strokes with size, and compute aspect-correct bounds.
-- Created: 2026-08-17

--!strict

local TextService = game:GetService("TextService")

local TextMetrics = {}

local PROBE_BOUNDS = Vector2.new(100000, 100000)

function TextMetrics.fittingSize(
	text: string,
	font: Enum.Font,
	bounds: Vector2,
	minimum: number,
	maximum: number,
	wrapped: boolean
): number
	local low = minimum
	local high = maximum
	local best = minimum
	while low <= high do
		local candidate = math.floor((low + high) * 0.5)
		local measureBounds = if wrapped then Vector2.new(math.max(bounds.X, 1), 100000) else PROBE_BOUNDS
		local measured = TextService:GetTextSize(text, candidate, font, measureBounds)
		if measured.X <= bounds.X and measured.Y <= bounds.Y then
			best = candidate
			low = candidate + 1
		else
			high = candidate - 1
		end
	end
	return best
end

function TextMetrics.scaledTextStroke(
	pixels: number,
	text: string,
	font: Enum.Font,
	referenceBounds: Vector2,
	maximumTextSize: number?
): number
	local textSize = TextMetrics.fittingSize(text, font, referenceBounds, 1, maximumTextSize or 100, false)
	return pixels / textSize
end

function TextMetrics.fitAspect(bounds: Vector2, aspectRatio: number): Vector2
	if bounds.X / bounds.Y > aspectRatio then
		return Vector2.new(bounds.Y * aspectRatio, bounds.Y)
	end
	return Vector2.new(bounds.X, bounds.X / aspectRatio)
end

function TextMetrics.scaleBounds(bounds: Vector2, scale: Vector2): Vector2
	return Vector2.new(bounds.X * scale.X, bounds.Y * scale.Y)
end

return table.freeze(TextMetrics)
