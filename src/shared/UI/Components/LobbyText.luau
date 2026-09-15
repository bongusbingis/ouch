--!strict
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
return function(props)
	local native = table.clone(props)
	native.children = nil
	native.BackgroundTransparency = 1
	native.Font = native.Font or T.Type.Label
	native.TextColor3 = native.TextColor3 or T.Colors.Ink
	native.TextSize = native.TextSize or T.Type.Minimum
	native.TextWrapped = native.TextWrapped ~= false
	native.TextXAlignment = native.TextXAlignment or Enum.TextXAlignment.Left
	native.ZIndex = native.ZIndex or 8
	return React.createElement("TextLabel", native, props.children)
end
