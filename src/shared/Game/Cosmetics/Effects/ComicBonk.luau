--!strict

-- Short comic-book hit with a chunky angular burst, BONK typography, and spiraling stars.

local Palette = require(script.Parent.Palette)
local ParticleKit = require(script.Parent.ParticleKit)
local ParticlePresets = require(script.Parent.ParticlePresets)
local Primitives = require(script.Parent.Primitives)
local Runtime = require(script.Parent.Runtime)

local ComicBonk = {}

local random = Random.new()
local PRESENCE_SCALE = 1.3

local particles = ParticleKit.effect({
	emitters = {
		ParticlePresets.flash(Palette.White, 10.5),
		ParticlePresets.ring(Palette.Yellow, 26),
		ParticlePresets.rays(Palette.Pink, 8, 7.2),
		ParticlePresets.streaks(Palette.Yellow, 10, 18),
		ParticlePresets.flare(Palette.White, 3.5, 0),
	},
})

type Spike = {
	part: WedgePart,
	angle: number,
	length: number,
	width: number,
}

local function burst(position: Vector3, frame: CFrame, scale: number, scope: Runtime.Scope?)
	local model = Primitives.group("ComicBonkBurst", scope)
	local spikes: { Spike } = {}
	for index = 1, 8 do
		local angle = ((index - 1) / 8) * math.pi * 2
		local length = if index % 2 == 0 then 2.35 else 3.25
		local part = Primitives.wedge(
			"ComicSpike",
			if index % 3 == 0 then Palette.Pink else Palette.Yellow,
			Vector3.one * 0.1,
			frame,
			nil,
			scope
		)
		part.Parent = model
		table.insert(spikes, {
			part = part,
			angle = angle,
			length = length,
			width = if index % 2 == 0 then 0.74 else 0.98,
		})
	end
	Runtime.add(model, 0.46, function(alpha)
		local spring = Primitives.popScale(alpha, 0.06, 1.18, 1)
		local shrink = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.58))
		for _, spike in spikes do
			local radius = spike.length * 0.42 * scale * spring
			spike.part.CFrame = frame * CFrame.Angles(0, 0, spike.angle) * CFrame.new(0, radius, 0)
			spike.part.Size = Primitives.size(Vector3.new(spike.width, spike.length, 0.18) * scale * spring * shrink)
			spike.part.Transparency = Primitives.fadeAfter(alpha, 0.7)
		end
	end, { layer = "Hero" })
end

local function word(position: Vector3, frame: CFrame, scale: number, scope: Runtime.Scope?)
	local origin = position + Vector3.yAxis * 1.25 * scale + frame.LookVector * 0.35 * scale
	local glyph = Primitives.glyph(
		"ComicBonkWord",
		"BONK!",
		Palette.White,
		Palette.Ink,
		origin,
		Vector2.new(4.2, 1.55) * scale,
		scope
	)
	Runtime.add(glyph.root, 0.62, function(alpha)
		glyph.root.CFrame = CFrame.new(origin + Vector3.yAxis * Primitives.easeOutCubic(alpha) * 1.15 * scale)
		local textScale: number
		if alpha < 0.22 then
			textScale = 0.7 + Primitives.easeOutQuint(alpha / 0.22) * 0.45
		elseif alpha < 0.42 then
			textScale = 1.15 - Primitives.smooth((alpha - 0.22) / 0.2) * 0.15
		else
			textScale = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.68))
		end
		glyph.gui.Size = UDim2.fromScale(4.2 * scale * textScale, 1.55 * scale * textScale)
		glyph.label.Rotation = -8 + Primitives.easeOutCubic(alpha) * 11
		glyph.label.TextTransparency = Primitives.fadeAfter(alpha, 0.78)
		glyph.label.TextStrokeTransparency = Primitives.fadeAfter(alpha, 0.72)
	end, { layer = "Hero" })
end

local function star(position: Vector3, frame: CFrame, scale: number, index: number, scope: Runtime.Scope?)
	local angle = index * math.pi * 0.72
	local glyph = Primitives.glyph(
		"ComicBonkStar",
		"★",
		if index == 2 then Palette.Pink else Palette.Yellow,
		Palette.Ink,
		position,
		Vector2.one * 0.75 * scale,
		scope
	)
	local phase = random:NextNumber(-0.2, 0.2)
	Runtime.add(glyph.root, 0.56, function(alpha)
		local radius = Primitives.easeOutCubic(alpha) * (2.5 + index * 0.2) * scale
		local theta = angle + alpha * math.pi * (1.05 + phase)
		local offset = frame.RightVector * math.cos(theta) * radius
			+ frame.UpVector * math.sin(theta) * radius
			+ Vector3.yAxis * alpha * 0.6 * scale
		glyph.root.CFrame = CFrame.new(position + offset)
		local starScale = Primitives.popScale(alpha, 0.16, 1.2, 1)
			* (1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.62)))
		glyph.gui.Size = UDim2.fromScale(0.75 * scale * starScale, 0.75 * scale * starScale)
		glyph.label.Rotation = alpha * 170 * (if index % 2 == 0 then -1 else 1)
		glyph.label.TextTransparency = Primitives.fadeAfter(alpha, 0.8)
	end, { layer = "Secondary" })
end

function ComicBonk.play(context: Primitives.Context)
	local scope = context.scope
	particles.play(context)
	local scale = Primitives.contextScale(context) * PRESENCE_SCALE
	local frame = Primitives.frame(context.position, context.direction)
	burst(context.position, frame, scale, scope)
	word(context.position, frame, scale, scope)
	for index = 1, Runtime.scaledCount(7, "Secondary") do
		star(context.position, frame, scale, index, scope)
	end
end

return ComicBonk
