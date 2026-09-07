--!strict

-- Soft overlapping foam puffs that inflate quickly and float apart without smoke.

local Palette = require(script.Parent.Palette)
local ParticleKit = require(script.Parent.ParticleKit)
local ParticlePresets = require(script.Parent.ParticlePresets)
local Primitives = require(script.Parent.Primitives)
local Runtime = require(script.Parent.Runtime)

local FoamPoof = {}

local random = Random.new()
local PRESENCE_SCALE = 1.22
local PUFF_COLORS = {
	Palette.Cream,
	Palette.Cream,
	Palette.White,
	Palette.Cream,
	Palette.Cyan,
	Palette.Cream,
	Palette.HotPink,
	Palette.White,
}

local particles = ParticleKit.effect({
	emitters = {
		ParticlePresets.flash(Palette.White, 9.5),
		ParticlePresets.ring(Palette.Cream, 22),
		ParticlePresets.smoke(Palette.Cream, 8, 5.2),
		ParticlePresets.motes(Palette.Cyan, 10, 0.48),
	},
})

local function centerPuff(position: Vector3, frame: CFrame, scale: number, scope: Runtime.Scope?)
	local part = Primitives.part("FoamPoofCore", Palette.White, Vector3.one * 0.1, frame, nil, scope)
	part.Shape = Enum.PartType.Ball
	Runtime.add(part, 0.42, function(alpha)
		local spring = Primitives.popScale(alpha, 0.14, 1.18, 1)
		local wobble = math.sin(alpha * math.pi * 5) * (1 - alpha) * 0.08
		local exit = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.58))
		local shape = Vector3.new(5.2 * (1 + wobble), 4 * (1 - wobble), 1.6 * (1 + wobble * 0.5))
		part.Size = Primitives.size(shape * scale * spring * exit)
		local bounce = math.sin(alpha * math.pi * 3) * (1 - alpha) * 0.12 * scale
		part.CFrame = frame + Vector3.yAxis * (0.45 * scale * alpha + bounce)
		part.Transparency = 0.05 + 0.95 * Primitives.fadeAfter(alpha, 0.68)
	end, { layer = "Hero" })
end

local function puff(
	position: Vector3,
	frame: CFrame,
	scale: number,
	index: number,
	count: number,
	scope: Runtime.Scope?
)
	local angle = ((index - 1) / count) * math.pi * 2 + random:NextNumber(-0.18, 0.18)
	local outward = Primitives.radial(frame, angle, random:NextNumber(-0.12, 0.18))
	local size = random:NextNumber(1.45, 2.35) * scale
	local origin = position + outward * random:NextNumber(0.15, 0.5) * scale
	local velocity = outward * random:NextNumber(2.6, 4.8) * scale + Vector3.yAxis * random:NextNumber(1.3, 3.1) * scale
	local part = Primitives.part(
		"FoamPoofPuff",
		PUFF_COLORS[(index - 1) % #PUFF_COLORS + 1],
		Vector3.one * 0.1,
		CFrame.new(origin),
		nil,
		scope
	)
	part.Shape = Enum.PartType.Ball
	local lifetime = random:NextNumber(0.55, 0.72)
	local aspect = Vector3.new(random:NextNumber(0.9, 1.18), random:NextNumber(0.85, 1.2), random:NextNumber(0.9, 1.15))
	Runtime.add(part, lifetime, function(alpha, elapsed)
		local spring = Primitives.popScale(alpha, 0.12, 1.16, 1)
		local wobble = math.sin(alpha * math.pi * 5 + index) * (1 - alpha) * 0.06
		local exit = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.6))
		local shape = Vector3.new(aspect.X * (1 + wobble), aspect.Y * (1 - wobble), aspect.Z * (1 + wobble * 0.4))
		part.Size = Primitives.size(shape * size * spring * exit)
		part.CFrame = CFrame.new(Primitives.ballistic(origin, velocity, Vector3.yAxis * 1.5, elapsed))
		part.Transparency = 0.03 + 0.97 * Primitives.fadeAfter(alpha, 0.76)
	end, { layer = if index <= 4 then "Hero" else "Secondary" })
end

function FoamPoof.play(context: Primitives.Context)
	local scope = context.scope
	particles.play(context)
	local scale = Primitives.contextScale(context) * PRESENCE_SCALE
	local frame = Primitives.frame(context.position, context.direction)
	centerPuff(context.position, frame, scale, scope)
	local count = Runtime.scaledCount(14, "Secondary")
	for index = 1, count do
		puff(context.position, frame, scale, index, count, scope)
	end
end

return FoamPoof
