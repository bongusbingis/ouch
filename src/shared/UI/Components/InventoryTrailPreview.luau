--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local TrailCosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("TrailCosmetics"))

local c = React.createElement

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

export type Props = {
	EffectId: string,
	Config: any,
	Elapsed: any,
	ZIndex: number,
}

return function(props: Props)
	local definition = TrailCosmetics[props.EffectId]
	assert(definition ~= nil, `[InventoryTrailPreview] unknown trail cosmetic {props.EffectId}`)
	local children = {}
	local ribbonCount = math.min(#definition.Trails, props.Config.MaxRibbonLayers)

	for index, layer in definition.Trails do
		if index > ribbonCount then
			break
		end
		local yOffset = (index - (ribbonCount + 1) * 0.5) * 0.018
		children[`Ribbon{index}`] = c("Frame", {
			AnchorPoint = props.Elapsed:map(function(elapsed: number)
				local phase = elapsed * math.pi * 2 / props.Config.TravelSeconds
				return Vector2.new(if math.cos(phase) >= 0 then 1 else 0, 0.5)
			end),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.22,
			BorderSizePixel = 0,
			Position = props.Elapsed:map(function(elapsed: number)
				local phase = elapsed * math.pi * 2 / props.Config.TravelSeconds
				local movingRight = math.cos(phase) >= 0
				local ballX = props.Config.ScreenCenter.X + math.sin(phase) * props.Config.ScreenTravelScale
				local ballY = props.Config.ScreenCenter.Y + math.sin(phase * 2) * props.Config.ScreenBobScale
				local headX = ballX + if movingRight then -props.Config.HeadInsetScale else props.Config.HeadInsetScale
				return UDim2.fromScale(headX, ballY + yOffset)
			end),
			Size = UDim2.fromScale(props.Config.RibbonLengthScale, props.Config.RibbonHeightScale * layer.Width),
			ZIndex = props.ZIndex + index,
		}, {
			UICorner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UIGradient = c("UIGradient", {
				Color = colorSequence(layer.Colors),
				Offset = Vector2.zero,
				Rotation = props.Elapsed:map(function(elapsed: number)
					return if math.cos(elapsed * math.pi * 2 / props.Config.TravelSeconds) >= 0 then 0 else 180
				end),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.2, 0.45),
					NumberSequenceKeypoint.new(1, 0.05),
				}),
			}),
		})
	end

	for emitterIndex, emitter in definition.Emitters do
		if emitterIndex > props.Config.MaxEmitterLayers then
			break
		end
		local count = math.min(props.Config.ParticlesPerEmitter, if #emitter.Colors > 1 then 2 else 1)
		local sparkle = string.find(emitter.Texture, "sparkles", 1, true) ~= nil
		for index = 1, count do
			local ageOffset = (index - 1) / count
			local colorAlpha = (index - 1) / math.max(count - 1, 1)
			local speed = props.Config.ParticleCyclesPerSecond * (0.9 + index * 0.08)
			local drift = if index % 2 == 0 then 1 else -1
			local baseRotation = if sparkle then 45 else 0
			children[`Mote{emitterIndex}_{index}`] = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = sampleColor(emitter.Colors, colorAlpha),
				BackgroundTransparency = props.Elapsed:map(function(elapsed: number)
					return 0.18 + ((elapsed * speed + ageOffset) % 1) * 0.8
				end),
				BorderSizePixel = 0,
				Position = props.Elapsed:map(function(elapsed: number)
					local phase = elapsed * math.pi * 2 / props.Config.TravelSeconds
					local movingRight = math.cos(phase) >= 0
					local direction = if movingRight then -1 else 1
					local age = (elapsed * speed + ageOffset) % 1
					local ballX = props.Config.ScreenCenter.X + math.sin(phase) * props.Config.ScreenTravelScale
					local ballY = props.Config.ScreenCenter.Y + math.sin(phase * 2) * props.Config.ScreenBobScale
					local headX = ballX
						+ if movingRight then -props.Config.HeadInsetScale else props.Config.HeadInsetScale
					local length = props.Config.RibbonLengthScale * (0.35 + math.abs(math.cos(phase)) * 0.65)
					return UDim2.fromScale(
						headX + direction * length * age,
						ballY + math.sin(age * math.pi * 2 + index) * props.Config.ParticleDriftScale * drift
					)
				end),
				Rotation = baseRotation + index * 24,
				Size = UDim2.fromScale(
					math.clamp(0.018 + emitter.Size * 0.035, 0.025, 0.065),
					math.clamp(0.018 + emitter.Size * 0.035, 0.025, 0.065)
				),
				ZIndex = props.ZIndex + 4 + emitterIndex,
			}, {
				UICorner = c("UICorner", { CornerRadius = if sparkle then UDim.new(0.15, 0) else UDim.new(1, 0) }),
			})
		end
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex + 1,
	}, children)
end
