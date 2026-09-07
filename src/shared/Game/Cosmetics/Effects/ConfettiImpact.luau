--!strict

-- Confetti impact: a fountain of matte paper that flutters up off the shared
-- flash-and-shockwave lead and rains back down.

local Palette = require(script.Parent.Palette)
local ParticleKit = require(script.Parent.ParticleKit)
local ParticlePresets = require(script.Parent.ParticlePresets)
local Primitives = require(script.Parent.Primitives)
local Runtime = require(script.Parent.Runtime)

local ConfettiImpact = {}

local random = Random.new()
local PRESENCE_SCALE = 1.22
local CONFETTI_COLORS = {
	Palette.Pink,
	Palette.Yellow,
	Palette.Cyan,
	Palette.Purple,
}

local particles = ParticleKit.effect({
	emitters = {
		ParticlePresets.flash(Palette.White, 9.5),
		ParticlePresets.ring(Palette.Pink, 22),
		ParticlePresets.streaks(Palette.Pink, 3, 16),
		ParticlePresets.streaks(Palette.Yellow, 3, 16),
		ParticlePresets.streaks(Palette.Cyan, 3, 16),
		ParticlePresets.streaks(Palette.Purple, 3, 16),
		ParticlePresets.motes(Palette.Gold, 8, 0.5),
	},
})

local function paper(position: Vector3, scale: number, index: number, count: number, scope: Runtime.Scope?)
	local angle = (index / count) * math.pi * 2 + random:NextNumber() * 0.6
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local velocity = outward * random:NextNumber(7.5, 11) * scale + Vector3.yAxis * random:NextNumber(4.5, 8) * scale
	local size = Vector3.new(random:NextNumber(0.32, 0.52), random:NextNumber(0.62, 0.92), 0.1) * scale
	local part = Primitives.part(
		"ConfettiImpactPaper",
		CONFETTI_COLORS[(index - 1) % #CONFETTI_COLORS + 1],
		size,
		CFrame.new(position + Vector3.yAxis * scale),
		nil,
		scope
	)
	local origin = part.Position
	local initial = CFrame.Angles(
		random:NextNumber(-math.pi, math.pi),
		random:NextNumber(-math.pi, math.pi),
		random:NextNumber(-math.pi, math.pi)
	)
	local spin = Vector3.new(random:NextNumber(-8, 8), random:NextNumber(-5, 5), random:NextNumber(-9, 9))
	local lifetime = random:NextNumber(0.72, 0.95)
	Runtime.add(part, lifetime, function(alpha, elapsed)
		local current = Primitives.ballistic(origin, velocity, Vector3.new(0, -16, 0), elapsed)
		local flutter = math.sin(elapsed * 18 + index) * 0.35
		part.CFrame = CFrame.new(current)
			* initial
			* CFrame.Angles(spin.X * elapsed, spin.Y * elapsed + flutter, spin.Z * elapsed)
		local pop = Primitives.popScale(alpha, 0.34, 1.18, 1)
		local shrink = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.8))
		part.Size = Primitives.size(size * pop * shrink)
		part.Transparency = Primitives.fadeAfter(alpha, 0.86)
	end, { layer = "Secondary" })
end

function ConfettiImpact.play(context: Primitives.Context)
	local scope = context.scope
	particles.play(context)
	local scale = Primitives.contextScale(context) * PRESENCE_SCALE
	local count = Runtime.scaledCount(18, "Secondary")
	for index = 1, count do
		paper(context.position, scale, index, count, scope)
	end
end

return ConfettiImpact
