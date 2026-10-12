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
-- Each option keeps room to breathe beside the pink segment: a cell never gets narrower than this,
-- however small the row it sits in.
local MIN_CELL_WIDTH = 76

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
				MaxTextSize = Tokens.Type.Body,
				MinTextSize = Tokens.Type.Body,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Font = Tokens.Type.Display,
					Position = UDim2.new(0.5, 0, 0.5, -Tokens.Shape.LipHeight / 2),
					Size = UDim2.new(1, -Tokens.Shape.StrokeTab * 4, 0.7, 0),
					Text = props.Labels[index],
					TextColor3 = if selected then C.Surface else C.InkSoft,
					ZIndex = 5,
				},
			}, {
				Stroke = if selected then c("UIStroke", { Color = C.Ink, Thickness = Tokens.Type.Outline }) else nil,
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
		MinimumWidth = c("UISizeConstraint", { MinSize = Vector2.new(MIN_CELL_WIDTH * 2, 0) }),
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
				return UDim2.new(alpha * 0.5, Tokens.Shape.StrokeTab, 0, Tokens.Shape.StrokeTab)
			end),
			Size = UDim2.new(0.5, -Tokens.Shape.StrokeTab * 2, 1, -Tokens.Shape.StrokeTab * 2),
			ZIndex = 3,
		}, {
			Surface = c(CandySurface, {
				Color = if enabled then C.Pink else C.WellLine,
				LipColor = if enabled then C.PinkLip else C.WellLine,
				Radius = math.max(SETTINGS.ToggleRadius - Tokens.Shape.StrokeTab, 1),
				Shadow = false,
				Stroke = false,
				ZIndex = 3,
			}),
		}),
		OptionA = cell(1),
		OptionB = cell(2),
	})
end
