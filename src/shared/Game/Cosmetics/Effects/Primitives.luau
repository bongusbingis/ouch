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
	scope: Runtime.Scope?,
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

local function prepare(part: BasePart, name: string, color: Color3, material: Enum.Material, scope: Runtime.Scope?)
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = color
	part.Material = material
	Runtime.mount(part, scope)
end

function Primitives.part(
	name: string,
	color: Color3,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material?,
	scope: Runtime.Scope?
): Part
	local part = Instance.new("Part")
	prepare(part, name, color, material or Enum.Material.SmoothPlastic, scope)
	part.Size = Primitives.size(size)
	part.CFrame = cframe
	return part
end

function Primitives.wedge(
	name: string,
	color: Color3,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material?,
	scope: Runtime.Scope?
): WedgePart
	local part = Instance.new("WedgePart")
	prepare(part, name, color, material or Enum.Material.SmoothPlastic, scope)
	part.Size = Primitives.size(size)
	part.CFrame = cframe
	return part
end

function Primitives.group(name: string, scope: Runtime.Scope?): Model
	local model = Instance.new("Model")
	model.Name = name
	Runtime.mount(model, scope)
	return model
end

function Primitives.glyph(
	name: string,
	text: string,
	color: Color3,
	strokeColor: Color3,
	position: Vector3,
	studSize: Vector2,
	scope: Runtime.Scope?
): Glyph
	local root = Primitives.part(name, color, Vector3.one * 0.1, CFrame.new(position), nil, scope)
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

function Primitives.ribbon(name: string, color: Color3, position: Vector3, width: number, scope: Runtime.Scope?): Ribbon
	local root = Primitives.part(name, color, Vector3.one * 0.1, CFrame.new(position), nil, scope)
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

function Primitives.bubble(
	name: string,
	color: Color3,
	position: Vector3,
	diameter: number,
	scope: Runtime.Scope?
): Bubble
	local root = Primitives.group(name, scope)
	local sphere =
		Primitives.part("Bubble", color, Vector3.one * diameter, CFrame.new(position), Enum.Material.Glass, scope)
	sphere.Shape = Enum.PartType.Ball
	sphere.Transparency = 0.28
	sphere.Parent = root
	local highlight = Primitives.part(
		"Highlight",
		Color3.new(1, 1, 1),
		Vector3.one * diameter * 0.2,
		CFrame.new(position + Vector3.new(-diameter * 0.22, diameter * 0.22, -diameter * 0.24)),
		Enum.Material.SmoothPlastic,
		scope
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
	local progress = math.clamp(alpha, 0, 1)
	local amplitude = overshoot - endScale
	local compression = endScale - amplitude * 0.32
	local rebound = endScale + amplitude * 0.12
	if progress < 0.22 then
		return startScale + (overshoot - startScale) * Primitives.easeOutQuint(progress / 0.22)
	end
	if progress < 0.42 then
		return overshoot + (compression - overshoot) * Primitives.smooth((progress - 0.22) / 0.2)
	end
	if progress < 0.6 then
		return compression + (rebound - compression) * Primitives.smooth((progress - 0.42) / 0.18)
	end
	return rebound + (endScale - rebound) * Primitives.smooth((progress - 0.6) / 0.4)
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

function Primitives.cameraRight(scope: Runtime.Scope?): Vector3
	if scope and scope.camera then
		return scope.camera().RightVector
	end
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.RightVector else Vector3.xAxis
end

return Primitives
