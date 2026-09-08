-- Keeps gamepad scrolling focus consistent with the shared button focus treatment.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local c = React.createElement

return function(props)
	local scrollRef, imageRef = React.useRef(nil), React.useRef(nil)
	local focused, setFocused = React.useState(false)
	React.useEffect(function()
		local scroll = scrollRef.current
		scroll.SelectionImageObject = imageRef.current
		return function()
			scroll.SelectionImageObject = nil
		end
	end, {})
	local native = table.clone(props)
	native.children = nil
	native.ref = scrollRef
	native[React.Event.SelectionGained] = function()
		setFocused(true)
	end
	native[React.Event.SelectionLost] = function()
		setFocused(false)
	end
	local children = table.clone(props.children or {})
	children.FocusImage = c("Frame", {
		ref = imageRef,
		Visible = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
	})
	children.FocusOutline = c("UIStroke", {
		Color = UI.ProgressionStyle.Yellow,
		Thickness = UI.Interaction.FocusStrokePx,
		Transparency = if focused then 0 else 1,
	})
	children.FocusCorner = c("UICorner", { CornerRadius = UDim.new(0, 8) })
	return c("ScrollingFrame", native, children)
end
