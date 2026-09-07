--!strict

-- Premium gold impact with a composed jewel arc, restrained party burst, and delayed glint.

local Palette = require(script.Parent.Palette)
local ParticleKit = require(script.Parent.ParticleKit)
local ParticlePresets = require(script.Parent.ParticlePresets)
local Primitives = require(script.Parent.Primitives)
local Runtime = require(script.Parent.Runtime)

local RoyalParty = {}

local random = Random.new()
local PRESENCE_SCALE = 1.3

local particles = ParticleKit.effect({
	emitters = {
		ParticlePresets.flash(Palette.White, 11),
		ParticlePresets.ring(Palette.Gold, 26),
		ParticlePresets.rays(Palette.Gold, 12, 7.5),
		ParticlePresets.stars(Palette.White, 7, 1.2),
		ParticlePresets.flare(Palette.White, 3.8, 0),
		ParticlePresets.flare(Palette.Gold, 3.8, 90),
	},
})

type Jewel = {
	part: Part,
	x: number,
	y: number,
	size: number,
}

local function core(position: Vector3, frame: CFrame, scale: number, scope: Runtime.Scope?)
	local part = Primitives.part("RoyalPartyCore", Palette.Gold, Vector3.one * 0.1, frame, Enum.Material.Neon, scope)
	part.Shape = Enum.PartType.Ball
	Runtime.add(part, 0.34, function(alpha)
		local spring = Primitives.popScale(alpha, 0.08, 1.2, 1)
		local exit = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.44))
		part.Size = Primitives.size(Vector3.new(4.2, 3.3, 0.6) * scale * spring * exit)
		part.Transparency = 0.12 + 0.88 * Primitives.fadeAfter(alpha, 0.42)
	end, { layer = "Hero" })
end

local function jewelArc(position: Vector3, scale: number, scope: Runtime.Scope?)
	local model = Primitives.group("RoyalPartyArc", scope)
	local right = Primitives.cameraRight(scope)
	local up = Vector3.yAxis
	local forward = right:Cross(up)
	if forward.Magnitude < 1e-5 then
		forward = Vector3.zAxis
	else
		forward = forward.Unit
	end
	local values = {
		{ -2, 0.45, 0.52 },
		{ -1, 0.92, 0.62 },
		{ 0, 1.42, 0.78 },
		{ 1, 0.92, 0.62 },
		{ 2, 0.45, 0.52 },
	}
	local jewels: { Jewel } = {}
	for index, value in values do
		local part = Primitives.part(
			"RoyalJewel",
			if index == 3 then Palette.White else Palette.Gold,
			Vector3.one * 0.1,
			CFrame.new(position),
			nil,
			scope
		)
		part.Parent = model
		table.insert(jewels, {
			part = part,
			x = value[1],
			y = value[2],
			size = value[3],
		})
	end
	Runtime.add(model, 0.58, function(alpha)
		local rise = Primitives.popScale(alpha, 0, 1.1, 1)
		local pop = Primitives.popScale(alpha, 0.12, 1.18, 1)
		local shrink = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.64))
		for _, jewel in jewels do
			local target = position
				+ right * jewel.x * 0.68 * scale
				+ up * (1.1 + jewel.y) * scale
				+ forward * 0.25 * scale
			local current = position:Lerp(target, rise)
			jewel.part.CFrame = CFrame.lookAt(current, current + forward, up) * CFrame.Angles(0, 0, math.rad(45))
			jewel.part.Size = Primitives.size(Vector3.new(jewel.size, jewel.size, 0.18) * scale * pop * shrink)
			jewel.part.Transparency = Primitives.fadeAfter(alpha, 0.74)
		end
	end, { layer = "Hero" })
end

local function burstPiece(
	position: Vector3,
	frame: CFrame,
	scale: number,
	index: number,
	count: number,
	scope: Runtime.Scope?
)
	local angle = ((index - 1) / count) * math.pi * 2 + random:NextNumber(-0.12, 0.12)
	local outward = Primitives.radial(frame, angle, 0.2)
	local origin = position + frame.LookVector * 0.18 * scale
	local velocity = outward * random:NextNumber(8, 11.5) * scale + Vector3.yAxis * random:NextNumber(2.5, 5) * scale
	if index <= 4 then
		local glyph = Primitives.glyph(
			"RoyalStar",
			"★",
			Palette.Gold,
			Palette.Ink,
			origin,
			Vector2.one * random:NextNumber(0.85, 1.25) * scale,
			scope
		)
		local baseSize = random:NextNumber(0.85, 1.25) * scale
		Runtime.add(glyph.root, 0.72, function(alpha, elapsed)
			glyph.root.CFrame = CFrame.new(Primitives.ballistic(origin, velocity, Vector3.new(0, -9, 0), elapsed))
			local visualScale = Primitives.popScale(alpha, 0.16, 1.2, 1)
				* (1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.68)))
			glyph.gui.Size = UDim2.fromScale(baseSize * visualScale, baseSize * visualScale)
			glyph.label.Rotation = alpha * 150 * (if index % 2 == 0 then -1 else 1)
			glyph.label.TextTransparency = Primitives.fadeAfter(alpha, 0.82)
		end, { layer = if index <= 2 then "Hero" else "Secondary" })
		return
	end
	local color = if index % 2 == 0 then Palette.Cyan else Palette.Pink
	local part =
		Primitives.part("RoyalPartyPiece", color, Vector3.new(0.38, 0.72, 0.18) * scale, CFrame.new(origin), nil, scope)
	local baseSize = part.Size
	Runtime.add(part, 0.68, function(alpha, elapsed)
		part.CFrame = CFrame.new(Primitives.ballistic(origin, velocity, Vector3.new(0, -17, 0), elapsed))
			* CFrame.Angles(elapsed * 7, elapsed * 5, elapsed * 9)
		local pop = Primitives.popScale(alpha, 0.28, 1.17, 1)
		local shrink = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.7))
		part.Size = Primitives.size(baseSize * pop * shrink)
		part.Transparency = Primitives.fadeAfter(alpha, 0.84)
	end, { layer = "Secondary" })
end

local function glint(position: Vector3, scale: number, scope: Runtime.Scope?)
	local origin = position + Vector3.yAxis * 2.65 * scale + Primitives.cameraRight(scope) * 0.25 * scale
	local glyph =
		Primitives.glyph("RoyalGlint", "✦", Palette.White, Palette.Gold, origin, Vector2.one * 1.5 * scale, scope)
	glyph.label.TextTransparency = 1
	glyph.label.TextStrokeTransparency = 1
	Runtime.add(glyph.root, 0.32, function(alpha)
		local pop = Primitives.popScale(alpha, 0.05, 1.22, 1)
		local exit = 1 - Primitives.easeInCubic(Primitives.fadeAfter(alpha, 0.58))
		local visualScale = pop * exit * 1.5 * scale
		glyph.gui.Size = UDim2.fromScale(visualScale, visualScale)
		glyph.label.Rotation = -18 + alpha * 36
		glyph.label.TextTransparency = Primitives.fadeAfter(alpha, 0.7)
		glyph.label.TextStrokeTransparency = Primitives.fadeAfter(alpha, 0.62)
	end, { delay = 0.2, layer = "Hero" })
end

function RoyalParty.play(context: Primitives.Context)
	local scope = context.scope
	particles.play(context)
	local scale = Primitives.contextScale(context) * PRESENCE_SCALE
	local frame = Primitives.frame(context.position, context.direction)
	core(context.position, frame, scale, scope)
	jewelArc(context.position, scale, scope)
	local count = Runtime.scaledCount(7, "Secondary")
	for index = 1, count do
		burstPiece(context.position, frame, scale, index, count, scope)
	end
	glint(context.position, scale, scope)
end

return RoyalParty
