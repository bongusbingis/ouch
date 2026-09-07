--!strict

-- Composed paper celebration with curved streamers, chunky pieces, and sparse stars.

local Palette = require(script.Parent.Palette)
local ParticleKit = require(script.Parent.ParticleKit)
local ParticlePresets = require(script.Parent.ParticlePresets)
local Primitives = require(script.Parent.Primitives)
local Runtime = require(script.Parent.Runtime)

local PartyPopper = {}

local random = Random.new()
local PRESENCE_SCALE = 1.25
local PARTY_COLORS = {
	Palette.Pink,
	Palette.Cyan,
	Palette.Yellow,
	Palette.Purple,
}

local particles = ParticleKit.effect({
	emitters = {
		ParticlePresets.flash(Palette.White, 10.5),
		ParticlePresets.ring(Palette.Cyan, 24),
		ParticlePresets.rays(Palette.Pink, 10, 7),
		ParticlePresets.stars(Palette.Gold, 8, 1.05),
		ParticlePresets.flare(Palette.White, 3.2, 0),
		ParticlePresets.flare(Palette.White, 3.2, 90),
	},
})

local function core(position: Vector3, scale: number, scope: Runtime.Scope?)
	local part = Primitives.part("PartyPopperCore", Palette.Yellow, Vector3.one * 0.1, CFrame.new(position), nil, scope)
	part.Shape = Enum.PartType.Ball
	Runtime.add(part, 0.3, function(alpha)
		local pop = Primitives.popScale(alpha, 0.08, 1.2, 1)
		local exit = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.42))
		part.Size = Primitives.size(Vector3.one * 3.4 * scale * pop * exit)
		part.Transparency = 0.08 + 0.92 * Primitives.fadeAfter(alpha, 0.38)
	end, { layer = "Hero" })
end

local function streamer(
	position: Vector3,
	frame: CFrame,
	scale: number,
	index: number,
	count: number,
	scope: Runtime.Scope?
)
	local angle = ((index - 1) / count) * math.pi * 2 + 0.32
	local outward = Primitives.radial(frame, angle, 0.16)
	local velocity = outward * (9.5 + index * 0.55) * scale + Vector3.yAxis * (4.2 + index * 0.35) * scale
	local gravity = Vector3.new(0, -10, 0)
	local ribbon =
		Primitives.ribbon("PartyStreamer", PARTY_COLORS[(index - 1) % #PARTY_COLORS + 1], position, 0.22 * scale, scope)
	Runtime.add(ribbon.root, 0.78, function(alpha, elapsed)
		local tip = Primitives.ballistic(position, velocity, gravity, elapsed)
		local tailTime = math.max(elapsed - 0.12, 0)
		local tail = Primitives.ballistic(position, velocity * 0.72, gravity * 0.55, tailTime)
		ribbon.startAttachment.Position = tail - position
		ribbon.endAttachment.Position = tip - position
		ribbon.beam.CurveSize0 = math.sin(alpha * math.pi * 2 + index) * 1.5 * scale
		ribbon.beam.CurveSize1 = math.cos(alpha * math.pi * 2.5 + index) * 1.1 * scale
		local fade = Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.6))
		local pop = Primitives.popScale(alpha, 0.22, 1.18, 1)
		ribbon.beam.Transparency = NumberSequence.new(fade)
		ribbon.beam.Width0 = 0.22 * scale * pop * (1 - fade * 0.75)
		ribbon.beam.Width1 = ribbon.beam.Width0 * 0.72
	end, { layer = if index <= 2 then "Hero" else "Secondary" })
end

local function paper(
	position: Vector3,
	frame: CFrame,
	scale: number,
	index: number,
	count: number,
	scope: Runtime.Scope?
)
	local angle = ((index - 1) / count) * math.pi * 2 + random:NextNumber(-0.15, 0.15)
	local outward = Primitives.radial(frame, angle, random:NextNumber(-0.05, 0.24))
	local velocity = outward * random:NextNumber(7.5, 11) * scale + Vector3.yAxis * random:NextNumber(4.5, 7.5) * scale
	local color = PARTY_COLORS[(index - 1) % #PARTY_COLORS + 1]
	local piece: BasePart
	if index % 3 == 0 then
		piece = Primitives.wedge(
			"PartyTriangle",
			color,
			Vector3.new(0.55, 0.62, 0.12) * scale,
			CFrame.new(position),
			nil,
			scope
		)
	else
		piece =
			Primitives.part("PartyPaper", color, Vector3.new(0.28, 0.78, 0.1) * scale, CFrame.new(position), nil, scope)
	end
	local baseSize = piece.Size
	local rotation = CFrame.Angles(
		random:NextNumber(-math.pi, math.pi),
		random:NextNumber(-math.pi, math.pi),
		random:NextNumber(-math.pi, math.pi)
	)
	local spin = Vector3.new(random:NextNumber(-8, 8), random:NextNumber(-5, 5), random:NextNumber(-9, 9))
	local lifetime = random:NextNumber(0.72, 0.9)
	Runtime.add(piece, lifetime, function(alpha, elapsed)
		local current = Primitives.ballistic(position, velocity, Vector3.new(0, -16, 0), elapsed)
		local flutter = math.sin(elapsed * 18 + index) * 0.35
		piece.CFrame = CFrame.new(current)
			* rotation
			* CFrame.Angles(spin.X * elapsed, spin.Y * elapsed + flutter, spin.Z * elapsed)
		local pop = Primitives.popScale(alpha, 0.3, 1.16, 1)
		local shrink = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.78))
		piece.Size = Primitives.size(baseSize * pop * shrink)
		piece.Transparency = Primitives.fadeAfter(alpha, 0.84)
	end, { layer = "Secondary" })
end

local function accentStar(position: Vector3, frame: CFrame, scale: number, index: number, scope: Runtime.Scope?)
	local side = if index == 1 then -1 else 1
	local origin = position + frame.RightVector * side * 0.35 * scale
	local glyph =
		Primitives.glyph("PartyStar", "★", Palette.White, Palette.Pink, origin, Vector2.one * 0.72 * scale, scope)
	local velocity = (frame.RightVector * side + Vector3.yAxis * 0.8).Unit * 6 * scale
	Runtime.add(glyph.root, 0.55, function(alpha, elapsed)
		glyph.root.CFrame = CFrame.new(Primitives.ballistic(origin, velocity, Vector3.new(0, -7, 0), elapsed))
		local pop = Primitives.popScale(alpha, 0.18, 1.2, 1)
		local size = pop * (1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.64))) * 0.72 * scale
		glyph.gui.Size = UDim2.fromScale(size, size)
		glyph.label.Rotation = side * 120 * elapsed
		glyph.label.TextTransparency = Primitives.fadeAfter(alpha, 0.8)
	end, { layer = "Tertiary" })
end

function PartyPopper.play(context: Primitives.Context)
	local scope = context.scope
	particles.play(context)
	local scale = Primitives.contextScale(context) * PRESENCE_SCALE
	local frame = Primitives.frame(context.position, context.direction)
	core(context.position, scale, scope)
	local streamerCount = Runtime.scaledCount(6, "Secondary")
	for index = 1, streamerCount do
		streamer(context.position, frame, scale, index, streamerCount, scope)
	end
	local paperCount = Runtime.scaledCount(8, "Secondary")
	for index = 1, paperCount do
		paper(context.position, frame, scale, index, paperCount, scope)
	end
	for index = 1, Runtime.scaledCount(2, "Tertiary") do
		accentStar(context.position, frame, scale, index, scope)
	end
end

return PartyPopper
