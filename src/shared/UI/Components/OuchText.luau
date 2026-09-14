--!strict
-- Shared rounded face and proportional outline for text on colored surfaces.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local UI = require(ReplicatedStorage.Config.Interface.UI)
local ResponsiveText = require(script.Parent.ResponsiveText)

return function(props)
	local styled = table.clone(props)
	styled.Native = table.clone(props.Native or {})
	styled.Native.Font = nil
	styled.Native.FontFace = UI.Text.DefaultFont
	styled.Native.TextStrokeTransparency = 1
	styled.MeasurementFont = UI.Text.BodyFont
	local children = table.clone(props.children or {})
	-- Reuse one outline even for callers that previously supplied their own.
	for key, child in children do
		if React.isValidElement(child) and child.type == "UIStroke" then
			children[key] = nil
		end
	end
	children.Outline = React.createElement("UIStroke", {
		Color = UI.ProgressionStyle.Ink,
		Thickness = UI.Text.OutlineScale,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Transparency = if styled.Native.TextColor3 == UI.ProgressionStyle.Ink then 1 else 0,
	})
	return React.createElement(ResponsiveText, styled, children)
end
