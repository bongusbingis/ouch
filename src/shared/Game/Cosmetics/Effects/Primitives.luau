--!strict

-- Small shape and motion helpers shared by script cosmetic effects. Artistic
-- timing and composition remain inside each effect module.

local Workspace = game:GetService("Workspace")

local Runtime = require(script.Parent.Runtime)

local Primitives = {}

export type Context = {
	position: Vector3,
	direction: Vector3?,
	scale: number?,
}

export type Glyph = {
	root: Part,
	gui: BillboardGui,
	label: TextLabel,
}

export type Ribbon = {
	root: Part,
	startAttachment: Attachment,
	endAttachment: Attachment,
	beam: Beam,
}

export type Bubble = {
	root: Model,
	sphere: Part,
	highlight: Part,
}

local MIN_SIZE = 0.025
local DISPLAY_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")

local function component(value: number): number
	return math.max(value, MIN_SIZE)
end

function Primitives.size(value: Vector3): Vector3
	return Vector3.new(component(value.X), component(value.Y), component(value.Z))
end

local function prepare(part: BasePart, name: string, color: Color3, material: Enum.Material)
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = color
	part.Material = material
	part.Parent = Runtime.container()
end

function Primitives.part(name: string, color: Color3, size: Vector3, cframe: CFrame, material: Enum.Material?): Part
	local part = Instance.new("Part")
	prepare(part, name, color, material or Enum.Material.SmoothPlastic)
	part.Size = Primitives.size(size)
	part.CFrame = cframe
	return part
end

function Primitives.wedge(
	name: string,
	color: Color3,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material?
): WedgePart
	local part = Instance.new("WedgePart")
	prepare(part, name, color, material or Enum.Material.SmoothPlastic)
	part.Size = Primitives.size(size)
	part.CFrame = cframe
	return part
end

function Primitives.group(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = Runtime.container()
	return model
end

function Primitives.glyph(
	name: string,
	text: string,
	color: Color3,
	strokeColor: Color3,
	position: Vector3,
	studSize: Vector2
): Glyph
	local root = Primitives.part(name, color, Vector3.one * 0.1, CFrame.new(position))
	root.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "Billboard"
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 180
	gui.Size = UDim2.fromScale(studSize.X, studSize.Y)
	gui.Parent = root
	local label = Instance.new("TextLabel")
	label.Name = "Glyph"
	label.BackgroundTransparency = 1
	label.FontFace = DISPLAY_FONT
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeColor3 = strokeColor
	label.TextStrokeTransparency = 0
	label.Parent = gui
	return {
		root = root,
		gui = gui,
		label = label,
	}
end

function Primitives.ribbon(name: string, color: Color3, position: Vector3, width: number): Ribbon
	local root = Primitives.part(name, color, Vector3.one * 0.1, CFrame.new(position))
	root.Transparency = 1
	local startAttachment = Instance.new("Attachment")
	startAttachment.Name = "Start"
	startAttachment.Parent = root
	local endAttachment = Instance.new("Attachment")
	endAttachment.Name = "End"
	endAttachment.Parent = root
	local beam = Instance.new("Beam")
	beam.Name = "Streamer"
	beam.Attachment0 = startAttachment
	beam.Attachment1 = endAttachment
	beam.Color = ColorSequence.new(color)
	beam.FaceCamera = true
	beam.LightEmission = 0.35
	beam.Segments = 6
	beam.Width0 = width
	beam.Width1 = width * 0.72
	beam.Parent = root
	return {
		root = root,
		startAttachment = startAttachment,
		endAttachment = endAttachment,
		beam = beam,
	}
end

function Primitives.bubble(name: string, color: Color3, position: Vector3, diameter: number): Bubble
	local root = Primitives.group(name)
	local sphere = Primitives.part("Bubble", color, Vector3.one * diameter, CFrame.new(position), Enum.Material.Glass)
	sphere.Shape = Enum.PartType.Ball
	sphere.Transparency = 0.28
	sphere.Parent = root
	local highlight = Primitives.part(
		"Highlight",
		Color3.new(1, 1, 1),
		Vector3.one * diameter * 0.2,
		CFrame.new(position + Vector3.new(-diameter * 0.22, diameter * 0.22, -diameter * 0.24)),
		Enum.Material.SmoothPlastic
	)
	highlight.Shape = Enum.PartType.Ball
	highlight.Transparency = 0.08
	highlight.Parent = root
	return {
		root = root,
		sphere = sphere,
		highlight = highlight,
	}
end

function Primitives.contextScale(context: Context): number
	return math.clamp(context.scale or 1, 0.25, 2.5)
end

function Primitives.unitDirection(direction: Vector3?): Vector3?
	if direction == nil or direction.Magnitude < 1e-5 then
		return nil
	end
	return direction.Unit
end

function Primitives.frame(position: Vector3, direction: Vector3?): CFrame
	local forward = Primitives.unitDirection(direction) or Vector3.yAxis
	local up = if math.abs(forward:Dot(Vector3.yAxis)) > 0.94 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(position, position + forward, up)
end

function Primitives.radial(frame: CFrame, angle: number, forwardBias: number): Vector3
	return (frame.RightVector * math.cos(angle) + frame.UpVector * math.sin(angle) + frame.LookVector * forwardBias).Unit
end

function Primitives.ballistic(origin: Vector3, velocity: Vector3, gravity: Vector3, elapsed: number): Vector3
	return origin + velocity * elapsed + gravity * (0.5 * elapsed * elapsed)
end

function Primitives.velocityAt(velocity: Vector3, gravity: Vector3, elapsed: number): Vector3
	return velocity + gravity * elapsed
end

function Primitives.easeOutCubic(alpha: number): number
	return 1 - (1 - alpha) ^ 3
end

function Primitives.easeOutQuint(alpha: number): number
	return 1 - (1 - alpha) ^ 5
end

function Primitives.easeInCubic(alpha: number): number
	return alpha ^ 3
end

function Primitives.smooth(alpha: number): number
	return alpha * alpha * (3 - 2 * alpha)
end

function Primitives.popScale(alpha: number, startScale: number, overshoot: number, endScale: number): number
	if alpha < 0.28 then
		return startScale + (overshoot - startScale) * Primitives.easeOutQuint(alpha / 0.28)
	end
	local settle = (alpha - 0.28) / 0.72
	return overshoot + (endScale - overshoot) * Primitives.smooth(settle)
end

function Primitives.fadeAfter(alpha: number, startAt: number): number
	return math.clamp((alpha - startAt) / math.max(1 - startAt, 1e-4), 0, 1)
end

function Primitives.lookAlong(position: Vector3, direction: Vector3, roll: number): CFrame
	if direction.Magnitude < 1e-5 then
		return CFrame.new(position) * CFrame.Angles(0, 0, roll)
	end
	local up = if math.abs(direction.Unit:Dot(Vector3.yAxis)) > 0.94 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(position, position + direction, up) * CFrame.Angles(0, 0, roll)
end

function Primitives.cameraRight(): Vector3
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.RightVector else Vector3.xAxis
end

export type FlashOptions = {
	maxDiameter: number,
	lifetime: number?,
	layer: Runtime.Layer?,
	material: Enum.Material?,
	holdUntil: number?,
}

-- A punchy bulb that snaps to full size and then blows out. It is a sphere, so it
-- reads as a flash from any camera angle -- the lead "hit" beat that makes an
-- impact land before any debris has moved.
function Primitives.flash(position: Vector3, color: Color3, options: FlashOptions)
	local lifetime = options.lifetime or 0.22
	local holdUntil = options.holdUntil or 0.24
	local part =
		Primitives.part("Flash", color, Vector3.one * 0.1, CFrame.new(position), options.material or Enum.Material.Neon)
	part.Shape = Enum.PartType.Ball
	Runtime.add(part, lifetime, function(alpha)
		local pop = Primitives.easeOutQuint(math.min(alpha / 0.24, 1))
		part.Size = Primitives.size(Vector3.one * options.maxDiameter * pop)
		part.Transparency = 0.05 + 0.95 * Primitives.fadeAfter(alpha, holdUntil)
	end, { layer = options.layer or "Hero" })
end

export type ShockwaveOptions = {
	maxDiameter: number,
	startDiameter: number?,
	thickness: number?,
	lifetime: number?,
	layer: Runtime.Layer?,
}

-- The big expanding ring the confetti reference established, factored out so every
-- impact can lead with the same fast ground-plane shockwave. It expands hard on an
-- easeOut so the ring is already wide within a few frames of the hit.
function Primitives.shockwave(position: Vector3, color: Color3, options: ShockwaveOptions)
	local startDiameter = options.startDiameter or 3
	local thickness = options.thickness or 0.6
	local lifetime = options.lifetime or 0.45
	local part = Primitives.part(
		"Shockwave",
		color,
		Vector3.new(thickness, 1, 1),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Neon
	)
	part.Shape = Enum.PartType.Cylinder
	Runtime.add(part, lifetime, function(alpha)
		local eased = Primitives.easeOutCubic(alpha)
		local diameter = startDiameter + (options.maxDiameter - startDiameter) * eased
		part.Size = Primitives.size(Vector3.new(thickness, diameter, diameter))
		part.Transparency = alpha
	end, { layer = options.layer or "Hero" })
end

return Primitives
