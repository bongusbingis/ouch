--!strict

-- Oversized toy bubbles drift outward and pop in a staggered sequence.

local Palette = require(script.Parent.Palette)
local Primitives = require(script.Parent.Primitives)
local Runtime = require(script.Parent.Runtime)

local BubbleBurst = {}

local random = Random.new()
local BUBBLE_COLORS = {
	Palette.Cyan,
	Palette.LightBlue,
	Palette.Cyan,
	Palette.LightBlue,
	Palette.HotPink,
	Palette.Cyan,
	Palette.LightBlue,
}

local function bubbleScale(alpha: number): number
	if alpha < 0.22 then
		return 0.12 + Primitives.easeOutQuint(alpha / 0.22) * 0.88
	end
	if alpha < 0.82 then
		return 1 + math.sin((alpha - 0.22) * math.pi * 3) * 0.035
	end
	if alpha < 0.91 then
		return 1 + Primitives.easeOutCubic((alpha - 0.82) / 0.09) * 0.18
	end
	return 1.18 * (1 - Primitives.easeInCubic((alpha - 0.91) / 0.09))
end

local function popStar(position: Vector3, scale: number, delay: number)
	local glyph =
		Primitives.glyph("BubblePopStar", "★", Palette.White, Palette.Cyan, position, Vector2.one * 0.52 * scale)
	glyph.label.TextTransparency = 1
	glyph.label.TextStrokeTransparency = 1
	Runtime.add(glyph.root, 0.24, function(alpha)
		glyph.root.CFrame = CFrame.new(position + Vector3.yAxis * alpha * 0.65 * scale)
		local size = math.sin(alpha * math.pi) * 0.52 * scale
		glyph.gui.Size = UDim2.fromScale(size, size)
		glyph.label.Rotation = alpha * 90
		glyph.label.TextTransparency = Primitives.fadeAfter(alpha, 0.68)
		glyph.label.TextStrokeTransparency = Primitives.fadeAfter(alpha, 0.62)
	end, { delay = delay, layer = "Tertiary" })
end

local function spawnBubble(
	context: Primitives.Context,
	frame: CFrame,
	scale: number,
	index: number,
	count: number,
	starAccent: boolean
)
	local isCenter = index == 1
	local angle = if isCenter then 0 else ((index - 2) / math.max(count - 1, 1)) * math.pi * 2
	local outward = if isCenter then Vector3.zero else Primitives.radial(frame, angle, random:NextNumber(-0.08, 0.12))
	local diameter = (if isCenter then 3.2 else random:NextNumber(1.05, 1.75)) * scale
	local origin = context.position + outward * (if isCenter then 0 else 0.45 * scale)
	local velocity = outward * random:NextNumber(1.8, 3.5) * scale + Vector3.yAxis * random:NextNumber(1.4, 2.8) * scale
	local delay = if isCenter then 0 else random:NextNumber(0.025, 0.16)
	local duration = if isCenter then 0.6 else random:NextNumber(0.62, 0.78)
	local bubble =
		Primitives.bubble("BubbleBurstBubble", BUBBLE_COLORS[(index - 1) % #BUBBLE_COLORS + 1], origin, diameter)
	bubble.sphere.Size = Vector3.one * 0.025
	bubble.sphere.Transparency = 1
	bubble.highlight.Size = Vector3.one * 0.025
	bubble.highlight.Transparency = 1
	Runtime.add(bubble.root, duration, function(alpha, elapsed)
		local wobble = frame.RightVector * math.sin(elapsed * 8 + index) * 0.16 * scale
		local position = Primitives.ballistic(origin, velocity, Vector3.yAxis * 1.2, elapsed) + wobble
		local visualScale = bubbleScale(alpha)
		local currentDiameter = diameter * visualScale
		bubble.sphere.Size = Primitives.size(Vector3.one * currentDiameter)
		bubble.sphere.CFrame = CFrame.new(position)
		bubble.sphere.Transparency = 0.28 + 0.72 * Primitives.fadeAfter(alpha, 0.84)
		local highlightDiameter = currentDiameter * 0.2
		bubble.highlight.Size = Primitives.size(Vector3.one * highlightDiameter)
		bubble.highlight.CFrame =
			CFrame.new(position + Vector3.new(-currentDiameter * 0.22, currentDiameter * 0.22, -currentDiameter * 0.24))
		bubble.highlight.Transparency = 0.08 + 0.92 * Primitives.fadeAfter(alpha, 0.78)
	end, { delay = delay, layer = if isCenter or index <= 4 then "Hero" else "Secondary" })

	if starAccent then
		local popElapsed = duration * 0.84
		local popPosition = Primitives.ballistic(origin, velocity, Vector3.yAxis * 1.2, popElapsed)
		popStar(popPosition, scale, delay + popElapsed)
	end
end

function BubbleBurst.play(context: Primitives.Context)
	local scale = Primitives.contextScale(context)
	local frame = Primitives.frame(context.position, context.direction)
	-- Bubbles drift and pop, which alone reads as too soft for a kill, so the hit
	-- lands on an immediate flash and ring before the bubbles take over.
	Primitives.flash(context.position, Palette.Cyan, { maxDiameter = 8 * scale, lifetime = 0.22 })
	Primitives.shockwave(context.position, Palette.LightBlue, { maxDiameter = 20 * scale, startDiameter = 3 * scale })
	Primitives.shockwave(
		context.position,
		Palette.Cyan,
		{ maxDiameter = 13 * scale, startDiameter = 2 * scale, lifetime = 0.4, layer = "Secondary" }
	)
	local count = Runtime.scaledCount(10, "Secondary")
	local accentCount = Runtime.scaledCount(3, "Tertiary")
	for index = 1, count do
		spawnBubble(context, frame, scale, index, count, index > 1 and index <= accentCount + 1)
	end
end

return BubbleBurst
