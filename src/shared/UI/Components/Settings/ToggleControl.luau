-- Description: Reusable two-option This/That selector for the settings system. Options are arbitrary values with their own display labels -- never hardcoded to ON/OFF -- so the same control serves any binary setting. Mouse, touch, and controller all resolve through one OnChange call; the value updates immediately and the sliding highlight animates separately.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local Motion = require(script.Parent.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Parent.Hooks.useReducedMotion)
local AnimatedButton = require(script.Parent.Parent.AnimatedButton)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)
local CandySurface = require(script.Parent.Parent.CandySurface)
local Tokens = require(script.Parent.Parent.Parent.Tokens)

local c = React.createElement
local C = Tokens.Colors
local SETTINGS = Tokens.Settings

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
			SelectionRadius = UDim.new(0, SETTINGS.ToggleRadius),
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
				MeasurementFont = Tokens.Type.Display,
				MaxTextSize = 22,
				MinTextSize = 16,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Font = Tokens.Type.Display,
					Position = UDim2.new(0.5, 0, 0.5, 2),
					Size = UDim2.fromScale(0.86, 0.7),
					Text = props.Labels[index],
					TextColor3 = if selected then C.Surface else C.InkSoft,
					ZIndex = 5,
				},
			}, {
				Stroke = if selected then c("UIStroke", { Color = C.Ink, Thickness = 2 }) else nil,
			}),
		})
	end

	return c("Frame", {
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = props.Size or UDim2.fromScale(1, 1),
		ZIndex = 6,
	}, {
		Surface = c(CandySurface, {
			Color = if enabled then C.Surface else C.WellLine,
			LipColor = C.WellLine,
			Radius = SETTINGS.ToggleRadius,
			Shadow = false,
			ZIndex = 1,
		}),
		Highlight = c("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = styles.Alpha:map(function(alpha: number)
				return UDim2.new(alpha * 0.5, 4, 0, 4)
			end),
			Size = UDim2.new(0.5, -8, 1, -8),
			ZIndex = 3,
		}, {
			Surface = c(CandySurface, {
				Color = if enabled then C.Pink else C.WellLine,
				LipColor = if enabled then C.PinkLip else C.WellLine,
				Radius = math.max(SETTINGS.ToggleRadius - 4, 1),
				Shadow = false,
				Stroke = false,
				ZIndex = 3,
			}),
		}),
		OptionA = cell(1),
		OptionB = cell(2),
	})
end
