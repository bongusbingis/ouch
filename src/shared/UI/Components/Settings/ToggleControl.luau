-- Name: ToggleControl.luau
-- Author: Jack C.
-- Description: Reusable two-option This/That selector for the settings system. Options are arbitrary values with their own display labels -- never hardcoded to ON/OFF -- so the same control serves any binary setting. Mouse, touch, and controller all resolve through one OnChange call; the value updates immediately and the sliding highlight animates separately.
-- Created: 2026-08-25

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local Motion = require(script.Parent.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Parent.Hooks.useReducedMotion)
local AnimatedButton = require(script.Parent.Parent.AnimatedButton)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)

local c = React.createElement

local SELECTED_IMAGE = "rbxassetid://94748581468730"
local SELECTED_SLICE = Rect.new(198, 228, 841, 468)
local DIM_TEXT = Color3.fromRGB(190, 190, 190)
local DISABLED_TEXT = Color3.fromRGB(120, 120, 120)

export type Props = {
	Value: any,
	Values: { any },
	Labels: { string },
	Enabled: boolean?,
	OnChange: (any) -> (),
	Position: UDim2?,
	Size: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

return function(props: Props)
	local reducedMotion = useReducedMotion()
	local enabled = props.Enabled ~= false
	local selectedIndex = if props.Value == props.Values[1] then 1 else 2

	local styles, api = ReactSpring.useSpring(function()
		return { Alpha = selectedIndex - 1 }
	end)

	React.useEffect(function()
		api.start({ Alpha = selectedIndex - 1, config = Motion.Control, immediate = reducedMotion })
	end, { selectedIndex, reducedMotion })

	local function activate(index: number)
		if not enabled or index == selectedIndex then
			return
		end
		props.OnChange(props.Values[index])
	end

	local function cell(index: number)
		local selected = index == selectedIndex
		return c(AnimatedButton, {
			Enabled = enabled,
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = index,
				Position = UDim2.fromScale((index - 1) * 0.5, 0),
				Size = UDim2.fromScale(0.5, 1),
				ZIndex = 4,
			},
			OnActivated = function()
				activate(index)
			end,
		}, {
			Label = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 22,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.86, 0.7),
					Text = props.Labels[index],
					TextColor3 = if not enabled
						then DISABLED_TEXT
						elseif selected then Color3.new(1, 1, 1)
						else DIM_TEXT,
					ZIndex = 5,
				},
			}),
		})
	end

	return c("Frame", {
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = Color3.fromRGB(52, 52, 52),
		BackgroundTransparency = if enabled then 0.12 else 0.5,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = props.Size or UDim2.fromScale(1, 1),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Highlight = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = SELECTED_IMAGE,
			ImageTransparency = if enabled then 0 else 0.5,
			Position = styles.Alpha:map(function(alpha: number)
				return UDim2.fromScale(alpha * 0.5, 0)
			end),
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromScale(0.5, 1),
			SliceCenter = SELECTED_SLICE,
			SliceScale = 0.2,
			ZIndex = 3,
		}),
		OptionA = cell(1),
		OptionB = cell(2),
	})
end
