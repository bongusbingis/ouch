-- Description: The shared full-screen candy backdrop the loading and transition screens are drawn on: the lobby's sky-to-pink gradient, the faint swirl tile and a slow drift of confetti glyphs, held still for static teleport screens and reduced motion.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Loading = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Loading"))
local T = require(script.Parent.Parent.Tokens)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)

local c, C = React.createElement, T.Colors
local layout = Loading.Layout

export type Props = {
	Transparency: any?,
	RootRef: any?,
	Static: boolean?,
	Native: { [any]: any }?,
	children: { [any]: any }?,
}

local GLYPHS = { "•", "✦", "~", "▪" }
local GLYPH_COLORS = { C.Pink, C.CyanLip, C.Grape, C.Surface }

local function merge(...): { [any]: any }
	local result = {}
	for index = 1, select("#", ...) do
		local source = select(index, ...)
		if source then
			for key, value in source do
				result[key] = value
			end
		end
	end
	return result
end

local function confettiPosition(index: number, drift: number): UDim2
	return UDim2.fromScale((index * 0.618) % 1, (index * 0.381 + drift) % 1)
end

return function(props: Props)
	local reducedMotion = useReducedMotion()
	local drift, setDrift = React.useBinding(0)
	local moving = props.Static ~= true and not reducedMotion

	React.useEffect(function()
		if not moving then
			setDrift(0)
			return
		end
		local elapsed = 0
		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed = (elapsed + deltaTime) % layout.ConfettiDriftSeconds
			setDrift(elapsed / layout.ConfettiDriftSeconds)
		end)
		return function()
			connection:Disconnect()
		end
	end, { moving })

	local confetti = {}
	for index = 1, layout.ConfettiCount do
		confetti[`Piece{index}`] = c("TextLabel", {
			BackgroundTransparency = 1,
			Font = T.Type.Display,
			Position = drift:map(function(value: number)
				return confettiPosition(index, value)
			end),
			Rotation = index * 39 % 180,
			Size = UDim2.fromOffset(layout.ConfettiSize, layout.ConfettiSize),
			Text = GLYPHS[index % #GLYPHS + 1],
			TextColor3 = GLYPH_COLORS[index % #GLYPH_COLORS + 1],
			TextSize = layout.ConfettiSize,
			TextTransparency = 1 - T.Texture.ConfettiOpacity * 2,
			ZIndex = 2,
		})
	end

	return c(
		"CanvasGroup",
		merge({
			ref = props.RootRef,
			Active = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.BackdropMid,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			GroupTransparency = props.Transparency or 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 100,
		}, props.Native),
		merge({
			-- The gradient sits on its own frame: on the group itself it would
			-- tint everything drawn on top of it, panel and text included.
			Sky = c("Frame", {
				BackgroundColor3 = C.Surface,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 0,
			}, {
				Gradient = c("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, C.BackdropTop),
						ColorSequenceKeypoint.new(0.5, C.BackdropMid),
						ColorSequenceKeypoint.new(1, C.BackdropBottom),
					}),
				}),
			}),
			Swirl = c("ImageLabel", {
				BackgroundTransparency = 1,
				Image = T.Texture.Swirl,
				ImageColor3 = C.Surface,
				ImageTransparency = 1 - T.Texture.SwirlOpacity,
				ScaleType = Enum.ScaleType.Tile,
				Size = UDim2.fromScale(1, 1),
				TileSize = UDim2.fromOffset(360, 360),
				ZIndex = 1,
			}),
			Confetti = c("Frame", {
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			}, confetti),
		}, props.children)
	)
end
