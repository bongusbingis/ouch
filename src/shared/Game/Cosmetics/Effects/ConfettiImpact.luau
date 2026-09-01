--!strict

-- Legacy confetti impact retained for existing owners and migrated onto the
-- shared script-effect runtime.

local Palette = require(script.Parent.Palette)
local Primitives = require(script.Parent.Primitives)
local Runtime = require(script.Parent.Runtime)

local ConfettiImpact = {}

local random = Random.new()
local CONFETTI_COLORS = {
	Palette.Pink,
	Palette.Yellow,
	Palette.Cyan,
	Palette.Purple,
}

local function paper(position: Vector3, scale: number, index: number, count: number)
	local angle = (index / count) * math.pi * 2 + random:NextNumber() * 0.6
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local velocity = outward * 9 * scale + Vector3.new(0, 7 * random:NextNumber(0.6, 1.6) * scale, 0)
	local size = Vector3.one * 0.9 * random:NextNumber(0.7, 1.3) * scale
	local part = Primitives.part(
		"ConfettiImpactPaper",
		CONFETTI_COLORS[(index - 1) % #CONFETTI_COLORS + 1],
		size,
		CFrame.new(position + Vector3.yAxis * scale),
		Enum.Material.Neon
	)
	local origin = part.Position
	local initial = CFrame.Angles(
		random:NextNumber(-math.pi, math.pi),
		random:NextNumber(-math.pi, math.pi),
		random:NextNumber(-math.pi, math.pi)
	)
	local spin = Vector3.new(random:NextNumber(-8, 8), random:NextNumber(-10, 10), random:NextNumber(-8, 8))
	local lifetime = 0.9 * random:NextNumber(0.75, 1.25)
	Runtime.add(part, lifetime, function(alpha, elapsed)
		part.CFrame = CFrame.new(Primitives.ballistic(origin, velocity, Vector3.new(0, -18, 0), elapsed))
			* initial
			* CFrame.Angles(spin.X * elapsed, spin.Y * elapsed, spin.Z * elapsed)
		part.Size = Primitives.size(size:Lerp(size * 0.2, Primitives.easeOutCubic(alpha)))
		part.Transparency = alpha
	end, { layer = "Secondary" })
end

function ConfettiImpact.play(context: Primitives.Context)
	local scale = Primitives.contextScale(context)
	Primitives.flash(context.position, Palette.White, { maxDiameter = 7 * scale, lifetime = 0.2 })
	Primitives.shockwave(context.position, Palette.Yellow, { maxDiameter = 26 * scale, startDiameter = 3 * scale })
	Primitives.shockwave(
		context.position,
		Palette.Cyan,
		{ maxDiameter = 17.7 * scale, startDiameter = 2 * scale, layer = "Secondary" }
	)
	local count = Runtime.scaledCount(14, "Secondary")
	for index = 1, count do
		paper(context.position, scale, index, count)
	end
end

return ConfettiImpact
