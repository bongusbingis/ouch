--!strict

-- Oversized toy bubbles drift outward and pop in a staggered sequence.

local Palette = require(script.Parent.Palette)
local ParticleKit = require(script.Parent.ParticleKit)
local ParticlePresets = require(script.Parent.ParticlePresets)
local Primitives = require(script.Parent.Primitives)
local Runtime = require(script.Parent.Runtime)

local BubbleBurst = {}

local random = Random.new()
local PRESENCE_SCALE = 1.3
local BUBBLE_COLORS = {
	Palette.Cyan,
	Palette.LightBlue,
	Palette.Cyan,
	Palette.LightBlue,
	Palette.HotPink,
	Palette.Cyan,
	Palette.LightBlue,
}

local particles = ParticleKit.effect({
	emitters = {
		ParticlePresets.flash(Palette.Cyan, 10),
		ParticlePresets.ring(Palette.LightBlue, 24),
		ParticlePresets.motes(Palette.LightBlue, 14, 0.52),
		ParticlePresets.stars(Palette.White, 6, 0.82),
		ParticlePresets.flare(Palette.Cyan, 3.2, 0),
	},
})

local function bubbleScale(alpha: number): number
	if alpha < 0.18 then
		return 0.12 + Primitives.easeOutQuint(alpha / 0.18) * 1.02
	end
	if alpha < 0.34 then
		return 1.14 - Primitives.smooth((alpha - 0.18) / 0.16) * 0.18
	end
	if alpha < 0.48 then
		return 0.96 + Primitives.smooth((alpha - 0.34) / 0.14) * 0.06
	end
	if alpha < 0.82 then
		return 1 + math.sin((alpha - 0.48) * math.pi * 3) * 0.035
	end
	if alpha < 0.91 then
		return 1 + Primitives.easeOutCubic((alpha - 0.82) / 0.09) * 0.18
	end
	return 1.18 * (1 - Primitives.easeInCubic((alpha - 0.91) / 0.09))
end

local function popStar(position: Vector3, scale: number, delay: number, scope: Runtime.Scope?)
	local glyph = Primitives.glyph(
		"BubblePopStar",
		"★",
		Palette.White,
		Palette.Cyan,
		position,
		Vector2.one * 0.52 * scale,
		scope
	)
	glyph.label.TextTransparency = 1
	glyph.label.TextStrokeTransparency = 1
	Runtime.add(glyph.root, 0.24, function(alpha)
		glyph.root.CFrame = CFrame.new(position + Vector3.yAxis * alpha * 0.65 * scale)
		local pop = Primitives.popScale(alpha, 0.08, 1.22, 1)
		local exit = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.58))
		local size = pop * exit * 0.52 * scale
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
	starAccent: boolean,
	scope: Runtime.Scope?
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
		Primitives.bubble("BubbleBurstBubble", BUBBLE_COLORS[(index - 1) % #BUBBLE_COLORS + 1], origin, diameter, scope)
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
		popStar(popPosition, scale, delay + popElapsed, scope)
	end
end

function BubbleBurst.play(context: Primitives.Context)
	local scope = context.scope
	particles.play(context)
	local scale = Primitives.contextScale(context) * PRESENCE_SCALE
	local frame = Primitives.frame(context.position, context.direction)
	local count = Runtime.scaledCount(12, "Secondary")
	local accentCount = Runtime.scaledCount(4, "Tertiary")
	for index = 1, count do
		spawnBubble(context, frame, scale, index, count, index > 1 and index <= accentCount + 1, scope)
	end
end

return BubbleBurst
