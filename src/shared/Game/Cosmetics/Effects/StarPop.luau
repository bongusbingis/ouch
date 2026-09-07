--!strict

-- Chunky star impact with a compressed toy-like pulse and fast graphic arcs.

local Palette = require(script.Parent.Palette)
local ParticleKit = require(script.Parent.ParticleKit)
local ParticlePresets = require(script.Parent.ParticlePresets)
local Primitives = require(script.Parent.Primitives)
local Runtime = require(script.Parent.Runtime)

local StarPop = {}

local random = Random.new()
local PRESENCE_SCALE = 1.2
local STAR_COLORS = {
	Palette.Yellow,
	Palette.Yellow,
	Palette.Yellow,
	Palette.Cyan,
	Palette.Pink,
	Palette.White,
}

local particles = ParticleKit.effect({
	emitters = {
		ParticlePresets.flash(Palette.White, 10),
		ParticlePresets.ring(Palette.Gold, 23),
		ParticlePresets.rays(Palette.Yellow, 8, 6.2),
		ParticlePresets.motes(Palette.Cyan, 8, 0.52),
		ParticlePresets.flare(Palette.White, 2.8, 0),
	},
})

local function star(
	context: Primitives.Context,
	frame: CFrame,
	scale: number,
	index: number,
	count: number,
	layer: Runtime.Layer,
	scope: Runtime.Scope?
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
		Vector2.one * size,
		scope
	)
	local startRotation = random:NextNumber(-28, 28)
	local spin = random:NextNumber(-190, 190)
	local lifetime = random:NextNumber(0.56, 0.7)
	Runtime.add(glyph.root, lifetime, function(alpha, elapsed)
		local position = Primitives.ballistic(origin, velocity, Vector3.new(0, -4.5, 0), elapsed)
		glyph.root.CFrame = CFrame.new(position)
		glyph.label.Rotation = startRotation + spin * elapsed * (1 - alpha * 0.55)
		local pop = Primitives.popScale(alpha, 0.22, 1.18, 1)
		local shrink = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.66))
		local visualScale = pop * shrink
		glyph.gui.Size = UDim2.fromScale(size * visualScale, size * visualScale)
		glyph.label.TextTransparency = Primitives.fadeAfter(alpha, 0.84)
		glyph.label.TextStrokeTransparency = Primitives.fadeAfter(alpha, 0.78)
	end, { layer = layer })
end

function StarPop.play(context: Primitives.Context)
	local scope = context.scope
	particles.play(context)
	local scale = Primitives.contextScale(context) * PRESENCE_SCALE
	local frame = Primitives.frame(context.position, context.direction)
	local count = Runtime.scaledCount(12, "Secondary")
	for index = 1, count do
		star(context, frame, scale, index, count, if index <= 5 then "Hero" else "Secondary", scope)
	end
end

return StarPop
