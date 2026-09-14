--!strict
-- Candy-colored rings and sparks use native UI only; no artwork is resized or generated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local UI = require(ReplicatedStorage.Config.Interface.UI)
local c = React.createElement
local colors = UI.ProgressionStyle

return function(props)
	local motion = props.Motion
	local bits = {}
	bits.Core = c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = colors.White,
		BackgroundTransparency = motion.charge:map(function(v)
			return 0.5 - math.clamp(v, 0, 1) * 0.4
		end),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = motion.charge:map(function(v)
			local size = 0.16 + math.clamp(v, 0, 1.15) * 0.12
			return UDim2.fromScale(size, size)
		end),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Glow = c("UIStroke", { Color = colors.Yellow, Thickness = 10, Transparency = 0.7 }),
		Gloss = c("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(colors.White, colors.Yellow),
		}),
	})
	for index = 1, 12 do
		local angle = index / 12 * math.pi * 2
		bits[`Spark{index}`] = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if index % 2 == 0 then colors.Yellow else colors.White,
			BackgroundTransparency = motion.charge:map(function(v)
				return 0.65 - math.clamp(v, 0, 1) * 0.55
			end),
			BorderSizePixel = 0,
			Position = motion.charge:map(function(v)
				local radius = 0.28 + math.clamp(v, 0, 1.15) * 0.13
				return UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.5 + math.sin(angle) * radius)
			end),
			Rotation = math.deg(angle),
			Size = UDim2.fromScale(0.07, 0.025),
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	for index = 1, 3 do
		bits[`Halo{index}`] = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = motion.charge:map(function(v)
				local diameter = 0.22 + index * 0.09 + math.clamp(v, 0, 1.15) * 0.12
				return UDim2.fromScale(diameter, diameter)
			end),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Ring = c("UIStroke", {
				Color = if index == 1 then colors.Pink else colors.Yellow,
				Thickness = if index == 1 then 12 else 5,
				Transparency = (index - 1) * 0.24,
			}, { Gloss = c("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.65) }) }),
		})
	end
	return c("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = motion.landing:map(function(v)
			return UDim2.new(0.5, 0, 0.5, v)
		end),
		Size = UDim2.fromScale(1, 1),
		Rotation = motion.turn,
		ZIndex = 114,
	}, bits)
end
