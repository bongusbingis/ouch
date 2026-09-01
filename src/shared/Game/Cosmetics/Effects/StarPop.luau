--!strict

-- Chunky star impact with a compressed toy-like pulse and fast graphic arcs.

local Palette = require(script.Parent.Palette)
local Primitives = require(script.Parent.Primitives)
local Runtime = require(script.Parent.Runtime)

local StarPop = {}

local random = Random.new()
local STAR_COLORS = {
	Palette.Yellow,
	Palette.Yellow,
	Palette.Yellow,
	Palette.Cyan,
	Palette.Pink,
	Palette.White,
}

local function star(
	context: Primitives.Context,
	frame: CFrame,
	scale: number,
	index: number,
	count: number,
	layer: Runtime.Layer
)
	local angle = ((index - 1) / count) * math.pi * 2 + random:NextNumber(-0.12, 0.12)
	local direction = Primitives.radial(frame, angle, random:NextNumber(0.12, 0.32))
	local origin = context.position + frame.LookVector * 0.14 * scale
	local speed = random:NextNumber(8.5, 12.5) * scale
	local velocity = direction * speed + Vector3.yAxis * random:NextNumber(0.8, 2.2) * scale
	local size = random:NextNumber(1.45, 2.15) * scale
	local glyph = Primitives.glyph(
		"StarPopStar",
		"★",
		STAR_COLORS[(index - 1) % #STAR_COLORS + 1],
		Palette.Ink,
		origin,
		Vector2.one * size
	)
	local startRotation = random:NextNumber(-28, 28)
	local spin = random:NextNumber(-190, 190)
	local lifetime = random:NextNumber(0.56, 0.7)
	Runtime.add(glyph.root, lifetime, function(alpha, elapsed)
		local position = Primitives.ballistic(origin, velocity, Vector3.new(0, -4.5, 0), elapsed)
		glyph.root.CFrame = CFrame.new(position)
		glyph.label.Rotation = startRotation + spin * elapsed * (1 - alpha * 0.55)
		local grow = Primitives.easeOutQuint(math.min(alpha / 0.2, 1))
		local shrink = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.66))
		local visualScale = (0.22 + grow * 0.9) * shrink
		glyph.gui.Size = UDim2.fromScale(size * visualScale, size * visualScale)
		glyph.label.TextTransparency = Primitives.fadeAfter(alpha, 0.84)
		glyph.label.TextStrokeTransparency = Primitives.fadeAfter(alpha, 0.78)
	end, { layer = layer })
end

function StarPop.play(context: Primitives.Context)
	local scale = Primitives.contextScale(context)
	local frame = Primitives.frame(context.position, context.direction)
	Primitives.flash(context.position, Palette.Yellow, { maxDiameter = 8 * scale, lifetime = 0.22 })
	Primitives.shockwave(context.position, Palette.Yellow, { maxDiameter = 22 * scale, startDiameter = 3 * scale })
	Primitives.shockwave(
		context.position,
		Palette.Cyan,
		{ maxDiameter = 14 * scale, startDiameter = 2 * scale, lifetime = 0.4, layer = "Secondary" }
	)
	local count = Runtime.scaledCount(10, "Secondary")
	for index = 1, count do
		star(context, frame, scale, index, count, if index <= 5 then "Hero" else "Secondary")
	end
end

return StarPop
