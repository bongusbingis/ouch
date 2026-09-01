--!strict

-- Weighty candy chunks and small sprinkles with decisive ballistic falloff.

local Palette = require(script.Parent.Palette)
local Primitives = require(script.Parent.Primitives)
local Runtime = require(script.Parent.Runtime)

local CandyCrash = {}

local random = Random.new()
local CANDY_COLORS = {
	Palette.HotPink,
	Palette.HotPink,
	Palette.Yellow,
	Palette.Teal,
	Palette.Lavender,
	Palette.HotPink,
	Palette.Yellow,
}

local function core(position: Vector3, frame: CFrame, scale: number)
	local part = Primitives.part("CandyCrashCore", Palette.White, Vector3.one * 0.1, frame)
	part.Shape = Enum.PartType.Ball
	Runtime.add(part, 0.28, function(alpha)
		local expand = Primitives.easeOutQuint(math.min(alpha / 0.2, 1))
		local exit = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.38))
		part.Size = Primitives.size(Vector3.new(4.2, 3.3, 0.8) * scale * expand * exit)
		part.Transparency = 0.04 + 0.96 * Primitives.fadeAfter(alpha, 0.42)
	end, { layer = "Hero" })
end

local function chunk(position: Vector3, frame: CFrame, scale: number, index: number, count: number)
	local angle = ((index - 1) / count) * math.pi * 2 + random:NextNumber(-0.13, 0.13)
	local outward = Primitives.radial(frame, angle, random:NextNumber(0.08, 0.3))
	local velocity = outward * random:NextNumber(8.5, 12) * scale + Vector3.yAxis * random:NextNumber(2.8, 6.2) * scale
	local color = CANDY_COLORS[(index - 1) % #CANDY_COLORS + 1]
	local part: Part
	if index % 3 == 1 then
		part = Primitives.part("CandyGumdrop", color, Vector3.new(0.82, 0.95, 0.7) * scale, CFrame.new(position))
		part.Shape = Enum.PartType.Ball
	elseif index % 3 == 2 then
		part = Primitives.part("CandyWafer", color, Vector3.new(0.52, 0.96, 0.96) * scale, CFrame.new(position))
		part.Shape = Enum.PartType.Cylinder
	else
		part = Primitives.part("CandyChew", color, Vector3.new(0.78, 0.62, 0.92) * scale, CFrame.new(position))
	end
	local baseSize = part.Size
	local initial = CFrame.Angles(
		random:NextNumber(-math.pi, math.pi),
		random:NextNumber(-math.pi, math.pi),
		random:NextNumber(-math.pi, math.pi)
	)
	local spin = Vector3.new(random:NextNumber(-7, 7), random:NextNumber(-9, 9), random:NextNumber(-6, 6))
	local lifetime = random:NextNumber(0.68, 0.84)
	Runtime.add(part, lifetime, function(alpha, elapsed)
		local current = Primitives.ballistic(position, velocity, Vector3.new(0, -30, 0), elapsed)
		part.CFrame = CFrame.new(current)
			* initial
			* CFrame.Angles(spin.X * elapsed, spin.Y * elapsed, spin.Z * elapsed)
		local grow = Primitives.easeOutQuint(math.min(alpha / 0.14, 1))
		local shrink = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.7))
		part.Size = Primitives.size(baseSize * grow * shrink)
		part.Transparency = Primitives.fadeAfter(alpha, 0.82)
	end, { layer = if index <= 4 then "Hero" else "Secondary" })
end

local function sprinkle(position: Vector3, frame: CFrame, scale: number, index: number, count: number)
	local angle = ((index - 1) / count) * math.pi * 2 + 0.25
	local outward = Primitives.radial(frame, angle, 0.12)
	local velocity = outward * random:NextNumber(10, 14) * scale + Vector3.yAxis * random:NextNumber(2, 5) * scale
	local part = Primitives.part(
		"CandySprinkle",
		CANDY_COLORS[index % #CANDY_COLORS + 1],
		Vector3.new(0.18, 0.62, 0.18) * scale,
		CFrame.new(position)
	)
	local baseSize = part.Size
	Runtime.add(part, 0.62, function(alpha, elapsed)
		part.CFrame = CFrame.new(Primitives.ballistic(position, velocity, Vector3.new(0, -34, 0), elapsed))
			* CFrame.Angles(elapsed * 8, elapsed * 11, elapsed * 6)
		local shrink = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.7))
		part.Size = Primitives.size(baseSize * shrink)
		part.Transparency = Primitives.fadeAfter(alpha, 0.82)
	end, { layer = "Tertiary" })
end

function CandyCrash.play(context: Primitives.Context)
	local scale = Primitives.contextScale(context)
	local frame = Primitives.frame(context.position, context.direction)
	Primitives.flash(context.position, Palette.White, { maxDiameter = 8 * scale, lifetime = 0.2 })
	Primitives.shockwave(context.position, Palette.HotPink, { maxDiameter = 21 * scale, startDiameter = 3 * scale })
	Primitives.shockwave(
		context.position,
		Palette.Teal,
		{ maxDiameter = 13 * scale, startDiameter = 2 * scale, lifetime = 0.4, layer = "Secondary" }
	)
	core(context.position, frame, scale)
	local chunkCount = Runtime.scaledCount(9, "Secondary")
	for index = 1, chunkCount do
		chunk(context.position, frame, scale, index, chunkCount)
	end
	local sprinkleCount = Runtime.scaledCount(6, "Tertiary")
	for index = 1, sprinkleCount do
		sprinkle(context.position, frame, scale, index, sprinkleCount)
	end
end

return CandyCrash
