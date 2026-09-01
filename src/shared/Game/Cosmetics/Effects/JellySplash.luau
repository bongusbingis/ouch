--!strict

-- Gummy central splat with stretched, wobbling candy droplets.

local Palette = require(script.Parent.Palette)
local Primitives = require(script.Parent.Primitives)
local Runtime = require(script.Parent.Runtime)

local JellySplash = {}

local random = Random.new()
local JELLY_COLORS = {
	Palette.HotPink,
	Palette.HotPink,
	Palette.HotPink,
	Palette.Purple,
	Palette.Cyan,
	Palette.HotPink,
	Palette.Purple,
}

type SplashBlob = {
	part: Part,
	angle: number,
	radius: number,
	size: Vector3,
}

local function splash(context: Primitives.Context, frame: CFrame, scale: number)
	local model = Primitives.group("JellySplashCore")
	local blobs: { SplashBlob } = {}
	for index = 1, 6 do
		local angle = ((index - 1) / 5) * math.pi * 2
		local isCore = index == 1
		local part = Primitives.part(
			"JellyBlob",
			if isCore then Palette.HotPink else JELLY_COLORS[index],
			Vector3.one * 0.1,
			frame,
			Enum.Material.SmoothPlastic
		)
		part.Shape = Enum.PartType.Ball
		part.Transparency = if isCore then 0.04 else 0.08
		part.Parent = model
		table.insert(blobs, {
			part = part,
			angle = angle,
			radius = if isCore then 0 else 1,
			size = if isCore then Vector3.new(3.7, 2.8, 0.6) else Vector3.new(1.65, 1.12, 0.44),
		})
	end
	Runtime.add(model, 0.48, function(alpha)
		local expand = Primitives.easeOutQuint(math.min(alpha / 0.27, 1))
		local collapse = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.62))
		for _, blob in blobs do
			local offset = frame.RightVector * math.cos(blob.angle) + frame.UpVector * math.sin(blob.angle)
			local position = context.position + offset * blob.radius * 1.5 * scale * expand
			blob.part.CFrame = frame.Rotation + position
			blob.part.Size = Primitives.size(blob.size * scale * (0.12 + expand * 0.88) * collapse)
			blob.part.Transparency = 0.05 + 0.95 * Primitives.fadeAfter(alpha, 0.72)
		end
	end, { layer = "Hero" })
end

local function droplet(context: Primitives.Context, frame: CFrame, scale: number, index: number, count: number)
	local angle = ((index - 1) / count) * math.pi * 2 + random:NextNumber(-0.16, 0.16)
	local outward = Primitives.radial(frame, angle, random:NextNumber(0.08, 0.28))
	local origin = context.position + frame.LookVector * 0.15 * scale
	local velocity = outward * random:NextNumber(8.2, 12.8) * scale + Vector3.yAxis * random:NextNumber(1.5, 4) * scale
	local gravity = Vector3.new(0, -18, 0)
	local width = random:NextNumber(0.34, 0.52) * scale
	local length = random:NextNumber(0.85, 1.35) * scale
	local part = Primitives.part(
		"JellyDroplet",
		JELLY_COLORS[(index - 1) % #JELLY_COLORS + 1],
		Vector3.one * 0.1,
		CFrame.new(origin)
	)
	part.Shape = Enum.PartType.Ball
	part.Transparency = 0.06
	local lifetime = random:NextNumber(0.66, 0.82)
	Runtime.add(part, lifetime, function(alpha, elapsed)
		local currentVelocity = Primitives.velocityAt(velocity, gravity, elapsed)
		local position = Primitives.ballistic(origin, velocity, gravity, elapsed)
		local wobble = 1 + math.sin(alpha * math.pi * 4 + index) * 0.1 * (1 - alpha)
		local grow = Primitives.easeOutQuint(math.min(alpha / 0.16, 1))
		local shrink = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.74))
		part.Size = Primitives.size(Vector3.new(width * wobble, width / wobble, length) * grow * shrink)
		part.CFrame = Primitives.lookAlong(position, currentVelocity, math.sin(alpha * math.pi * 3) * 0.18)
		part.Transparency = 0.06 + 0.94 * Primitives.fadeAfter(alpha, 0.82)
	end, { layer = if index <= 4 then "Hero" else "Secondary" })
end

function JellySplash.play(context: Primitives.Context)
	local scale = Primitives.contextScale(context)
	local frame = Primitives.frame(context.position, context.direction)
	Primitives.flash(context.position, Palette.HotPink, { maxDiameter = 7 * scale, lifetime = 0.22 })
	Primitives.shockwave(context.position, Palette.HotPink, { maxDiameter = 19 * scale, startDiameter = 3 * scale })
	Primitives.shockwave(
		context.position,
		Palette.Purple,
		{ maxDiameter = 12 * scale, startDiameter = 2 * scale, lifetime = 0.4, layer = "Secondary" }
	)
	splash(context, frame, scale)
	local count = Runtime.scaledCount(10, "Secondary")
	for index = 1, count do
		droplet(context, frame, scale, index, count)
	end
end

return JellySplash
