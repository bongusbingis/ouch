--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrailCosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("TrailCosmetics"))

local InventoryTrailPreview = {}

export type Handle = {
	update: (self: Handle, elapsed: number) -> (),
	destroy: (self: Handle) -> (),
}

type Ribbon = {
	frame: Frame,
	gradient: UIGradient,
	width: number,
	yOffset: number,
}

type Mote = {
	frame: Frame,
	colors: { Color3 },
	phase: number,
	speed: number,
	drift: number,
	baseRotation: number,
}

local function colorSequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keypoints = {}
	for index, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

local function sampleColor(colors: { Color3 }, alpha: number): Color3
	if #colors == 1 then
		return colors[1]
	end
	local position = math.clamp(alpha, 0, 1) * (#colors - 1)
	local index = math.min(math.floor(position) + 1, #colors - 1)
	return colors[index]:Lerp(colors[index + 1], position - math.floor(position))
end

local function createRibbon(parent: GuiObject, layer: any, index: number, count: number): Ribbon
	local frame = Instance.new("Frame")
	frame.Name = `Ribbon_{index}`
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	frame.ZIndex = parent.ZIndex + index
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Color = colorSequence(layer.Colors)
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.45),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	gradient.Parent = frame

	return {
		frame = frame,
		gradient = gradient,
		width = layer.Width,
		yOffset = (index - (count + 1) * 0.5) * 0.018,
	}
end

local function createMotes(parent: GuiObject, emitter: any, emitterIndex: number, count: number): { Mote }
	local motes = {}
	local isSparkle = string.find(emitter.Texture, "sparkles", 1, true) ~= nil
	for index = 1, count do
		local frame = Instance.new("Frame")
		frame.Name = `Mote_{emitterIndex}_{index}`
		local size = math.clamp(0.018 + emitter.Size * 0.035, 0.025, 0.065)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BackgroundColor3 = emitter.Colors[1]
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Rotation = if isSparkle then 45 else 0
		frame.Size = UDim2.fromScale(size, size)
		frame.ZIndex = parent.ZIndex + 4 + emitterIndex
		frame.Parent = parent

		local corner = Instance.new("UICorner")
		corner.CornerRadius = if isSparkle then UDim.new(0.15, 0) else UDim.new(1, 0)
		corner.Parent = frame

		table.insert(motes, {
			frame = frame,
			colors = emitter.Colors,
			phase = (index - 1) / count,
			speed = 0.72 + emitterIndex * 0.08 + index * 0.035,
			drift = if index % 2 == 0 then 1 else -1,
			baseRotation = if isSparkle then 45 else 0,
		})
	end
	return motes
end

function InventoryTrailPreview.mount(viewport: ViewportFrame, effectId: string, config: any): Handle
	local definition = TrailCosmetics[effectId]
	assert(definition ~= nil, `[InventoryTrailPreview] unknown trail cosmetic {effectId}`)

	local overlay = Instance.new("Frame")
	overlay.Name = "TrailPreview"
	overlay.BackgroundTransparency = 1
	overlay.ClipsDescendants = true
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = viewport.ZIndex + 1
	overlay.Parent = viewport

	local ribbons = {}
	for index, layer in definition.Trails do
		table.insert(ribbons, createRibbon(overlay, layer, index, #definition.Trails))
	end

	local motes = {}
	for emitterIndex, emitter in definition.Emitters do
		local count = math.min(config.ParticlesPerEmitter, math.max(2, math.floor(emitter.Rate / 6)))
		for _, mote in createMotes(overlay, emitter, emitterIndex, count) do
			table.insert(motes, mote)
		end
	end

	local destroyed = false
	local handle = {} :: any
	function handle:update(elapsed: number)
		if destroyed then
			return
		end
		local phase = elapsed * math.pi * 2 / config.TravelSeconds
		local velocity = math.cos(phase)
		local speed = math.abs(velocity)
		local movingRight = velocity >= 0
		local center = config.ScreenCenter
		local ballX = center.X + math.sin(phase) * config.ScreenTravelScale
		local ballY = center.Y + math.sin(phase * 2) * config.ScreenBobScale
		local headX = ballX + if movingRight then -config.HeadInsetScale else config.HeadInsetScale
		local trailLength = config.RibbonLengthScale * (0.35 + speed * 0.65)

		for index, ribbon in ribbons do
			ribbon.frame.AnchorPoint = Vector2.new(if movingRight then 1 else 0, 0.5)
			ribbon.frame.Position = UDim2.fromScale(headX, ballY + ribbon.yOffset)
			ribbon.frame.Size = UDim2.fromScale(
				trailLength,
				config.RibbonHeightScale * ribbon.width * (0.92 + math.sin(phase * 2 + index) * 0.08)
			)
			ribbon.frame.BackgroundTransparency = 0.12 + (1 - speed) * 0.18
			ribbon.gradient.Rotation = if movingRight then 0 else 180
			ribbon.gradient.Offset = Vector2.new(math.sin(elapsed * 1.5 + index) * 0.08, 0)
		end

		for index, mote in motes do
			local age = (elapsed * mote.speed + mote.phase) % 1
			local direction = if movingRight then -1 else 1
			local x = headX + direction * trailLength * age
			local y = ballY + math.sin(age * math.pi * 2 + index) * config.ParticleDriftScale * mote.drift
			mote.frame.Position = UDim2.fromScale(x, y)
			mote.frame.BackgroundColor3 = sampleColor(mote.colors, age)
			mote.frame.BackgroundTransparency = 0.18 + age * 0.8
			mote.frame.Rotation = mote.baseRotation + direction * ((elapsed * 90 * mote.speed + index * 24) % 360)
		end
	end

	function handle:destroy()
		if destroyed then
			return
		end
		destroyed = true
		overlay:Destroy()
	end

	return handle :: Handle
end

return InventoryTrailPreview
