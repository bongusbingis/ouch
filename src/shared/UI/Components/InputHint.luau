-- Description: The one input-hint chip for every actionable control: a cream candy keycap with the key in plum Fredoka on keyboard/mouse, the platform's own controller glyph (Xbox or PlayStation, via GetImageForKeyCode) on gamepad, and nothing on touch. Follows the live DeviceClass; static, so reduced motion needs nothing extra.

--!strict

local RS = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local Model = require(script.Parent.Parent.Models.InputHintModel)
local useDeviceClass = require(script.Parent.Parent.Hooks.useDeviceClass)
local CandySurface = require(script.Parent.CandySurface)
local c, C, S = React.createElement, T.Colors, T.InputHint

export type Props = {
	Binding: Model.Binding?,
	-- Overrides the live device (stories, or a caller that already knows it).
	Device: string?,
	Native: { [string]: any }?,
}

local function textWidth(text: string): number?
	local ok, size =
		pcall(TextService.GetTextSize, TextService, text, S.TextSize, T.Type.Display, Vector2.new(400, S.Size))
	return if ok then size.X else nil
end

local function glyphImage(keyCode: Enum.KeyCode): string
	local ok, image = pcall(UserInputService.GetImageForKeyCode, UserInputService, keyCode)
	return if ok and typeof(image) == "string" then image else ""
end

local function keycap(text: string, width: number, native: { [string]: any })
	local radius = math.floor(S.Size / 3)
	native.BackgroundTransparency = 1
	native.Size = UDim2.fromOffset(width, S.Size)
	local z = native.ZIndex or 1
	return c("Frame", native, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, radius) }),
		Outline = c("UIStroke", {
			Color = C.Ink,
			Thickness = T.Shape.StrokeInner,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Surface = c(CandySurface, {
			Color = C.SurfaceWarm,
			LipColor = C.WellLine,
			Radius = radius,
			Shadow = false,
			Stroke = false,
			ZIndex = z,
		}),
		Key = c("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -T.Shape.LipHeight / 2),
			Font = T.Type.Display,
			Text = text,
			TextSize = S.TextSize,
			TextColor3 = C.Ink,
			ZIndex = z + 4,
		}),
	})
end

local function InputHint(props: Props)
	local live = useDeviceClass()
	local hint = Model.resolve(props.Device or live, props.Binding)
	if hint.kind == "None" then
		return nil
	end
	local native = table.clone(props.Native or {})
	if hint.kind == "Key" then
		return keycap(hint.text, Model.width(hint, textWidth(hint.text)), native)
	end
	local image = glyphImage(hint.keyCode)
	if image == "" then
		return keycap(
			hint.fallback,
			Model.width({ kind = "Key", text = hint.fallback }, textWidth(hint.fallback)),
			native
		)
	end
	native.BackgroundTransparency = 1
	native.Image = image
	native.ScaleType = Enum.ScaleType.Fit
	native.Size = UDim2.fromOffset(S.Size, S.Size)
	return c("ImageLabel", native)
end

-- Extra width a caller reserves beside its label for this binding on this device.
local function reserve(device: string, binding: Model.Binding?): number
	local hint = Model.resolve(device, binding)
	if hint.kind == "Glyph" and glyphImage(hint.keyCode) == "" then
		hint = { kind = "Key", text = hint.fallback }
	end
	return Model.reserve(hint, if hint.kind == "Key" then textWidth(hint.text) else nil)
end

return table.freeze({
	Component = InputHint,
	reserve = reserve,
})
