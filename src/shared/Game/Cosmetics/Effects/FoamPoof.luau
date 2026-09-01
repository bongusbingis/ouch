--!strict

-- Soft overlapping foam puffs that inflate quickly and float apart without smoke.

local Palette = require(script.Parent.Palette)
local Primitives = require(script.Parent.Primitives)
local Runtime = require(script.Parent.Runtime)

local FoamPoof = {}

local random = Random.new()
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

local function centerPuff(position: Vector3, frame: CFrame, scale: number)
	local part = Primitives.part("FoamPoofCore", Palette.White, Vector3.one * 0.1, frame)
	part.Shape = Enum.PartType.Ball
	Runtime.add(part, 0.42, function(alpha)
		local inflate = Primitives.easeOutQuint(math.min(alpha / 0.25, 1))
		local exit = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.58))
		part.Size = Primitives.size(Vector3.new(5.2, 4, 1.6) * scale * (0.14 + inflate * 0.86) * exit)
		part.CFrame = frame + Vector3.yAxis * (0.45 * scale * alpha)
		part.Transparency = 0.05 + 0.95 * Primitives.fadeAfter(alpha, 0.68)
	end, { layer = "Hero" })
end

local function puff(position: Vector3, frame: CFrame, scale: number, index: number, count: number)
	local angle = ((index - 1) / count) * math.pi * 2 + random:NextNumber(-0.18, 0.18)
	local outward = Primitives.radial(frame, angle, random:NextNumber(-0.12, 0.18))
	local size = random:NextNumber(1.45, 2.35) * scale
	local origin = position + outward * random:NextNumber(0.15, 0.5) * scale
	local velocity = outward * random:NextNumber(2.6, 4.8) * scale + Vector3.yAxis * random:NextNumber(1.3, 3.1) * scale
	local part = Primitives.part(
		"FoamPoofPuff",
		PUFF_COLORS[(index - 1) % #PUFF_COLORS + 1],
		Vector3.one * 0.1,
		CFrame.new(origin)
	)
	part.Shape = Enum.PartType.Ball
	local lifetime = random:NextNumber(0.55, 0.72)
	local aspect = Vector3.new(random:NextNumber(0.9, 1.18), random:NextNumber(0.85, 1.2), random:NextNumber(0.9, 1.15))
	Runtime.add(part, lifetime, function(alpha, elapsed)
		local inflate = Primitives.easeOutQuint(math.min(alpha / 0.3, 1))
		local exit = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.6))
		local puffScale = size * (0.12 + inflate * 0.94) * exit
		part.Size = Primitives.size(aspect * puffScale)
		part.CFrame = CFrame.new(Primitives.ballistic(origin, velocity, Vector3.yAxis * 1.5, elapsed))
		part.Transparency = 0.03 + 0.97 * Primitives.fadeAfter(alpha, 0.76)
	end, { layer = if index <= 4 then "Hero" else "Secondary" })
end

function FoamPoof.play(context: Primitives.Context)
	local scale = Primitives.contextScale(context)
	local frame = Primitives.frame(context.position, context.direction)
	-- A soft white bloom, not a neon flash, so the burst still lands hard while
	-- keeping foam's plush read.
	Primitives.flash(
		context.position,
		Palette.White,
		{ maxDiameter = 7 * scale, lifetime = 0.26, material = Enum.Material.SmoothPlastic }
	)
	centerPuff(context.position, frame, scale)
	local count = Runtime.scaledCount(11, "Secondary")
	for index = 1, count do
		puff(context.position, frame, scale, index, count)
	end
end

return FoamPoof
