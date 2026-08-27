-- Name: SliderControl.luau
-- Author: Jack C.
-- Description: Reusable slider for the settings system: continuous, step-snapped, or an explicit set of allowed stops, all resolved through SettingsValues' single alpha/value mapping so track clicks, thumb drags, and controller nudges can never disagree. Mouse and touch both drive one InputBegan/Changed/Ended path declared on the hit-target frame, so no lingering connection needs cleanup when the row unmounts.
-- Created: 2026-08-25

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SettingsValues = require(Shared:WaitForChild("Game"):WaitForChild("Settings"):WaitForChild("SettingsValues"))
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)
local UIFeedback = require(script.Parent.Parent.Parent.Services.UIFeedback)

local c = React.createElement

local TRACK_COLOR = Color3.fromRGB(52, 52, 52)
local FILL_COLOR = Color3.fromRGB(97, 255, 237)
local DISABLED_FILL = Color3.fromRGB(130, 130, 130)
local THUMB_STROKE = Color3.fromRGB(63, 63, 63)
local DRAG_CLAIM_PIXELS = 10

export type Props = {
	Value: number,
	Definition: SettingsValues.SliderDefinition,
	Enabled: boolean?,
	Format: ((number) -> string)?,
	OnChange: (number, boolean) -> (),
	Position: UDim2?,
	Size: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

type DragState = {
	trackRef: any,
	claimed: boolean,
	rejected: boolean,
	startX: number,
	startY: number,
}

return function(props: Props)
	local enabled = props.Enabled ~= false
	local definition = props.Definition
	local trackRef = React.useRef(nil)
	local drag = React.useRef(nil :: DragState?)

	React.useEffect(function()
		local target = trackRef.current
		if target then
			target.NextSelectionLeft = target
			target.NextSelectionRight = target
		end
	end, {})

	local alpha = SettingsValues.valueToAlpha(definition, props.Value)
	local stops = SettingsValues.stops(definition)
	local displayText = if props.Format then props.Format(props.Value) else tostring(props.Value)

	local function alphaFromX(x: number): number
		local track = trackRef.current
		if track == nil then
			return alpha
		end
		local origin = track.AbsolutePosition.X
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return alpha
		end
		return math.clamp((x - origin) / width, 0, 1)
	end

	local function apply(newAlpha: number, committed: boolean)
		local value = SettingsValues.alphaToValue(definition, newAlpha)
		props.OnChange(value, committed)
	end

	local function endDrag(committed: boolean)
		local state = drag.current
		drag.current = nil
		if state and committed and not state.rejected then
			apply(alphaFromX(state.startX), true)
		end
	end

	local function beginMouseDrag(x: number)
		drag.current = { trackRef = trackRef, claimed = true, rejected = false, startX = x, startY = 0 }
		apply(alphaFromX(x), false)
	end

	local function beginTouch(x: number, y: number)
		drag.current = { trackRef = trackRef, claimed = false, rejected = false, startX = x, startY = y }
	end

	local function moveMouse(x: number)
		local state = drag.current
		if state == nil or not enabled then
			return
		end
		state.startX = x
		apply(alphaFromX(x), false)
	end

	local function moveTouch(x: number, y: number)
		local state = drag.current
		if state == nil or state.rejected or not enabled then
			return
		end
		if not state.claimed then
			local dx = x - state.startX
			local dy = y - state.startY
			if math.abs(dx) >= DRAG_CLAIM_PIXELS and math.abs(dx) >= math.abs(dy) * 1.2 then
				state.claimed = true
			elseif math.abs(dy) >= DRAG_CLAIM_PIXELS and math.abs(dy) > math.abs(dx) * 1.2 then
				state.rejected = true
				return
			else
				return
			end
		end
		state.startX = x
		apply(alphaFromX(x), false)
	end

	local function step(direction: number)
		if not enabled then
			return
		end
		local nextValue = SettingsValues.stepValue(definition, props.Value, direction)
		if nextValue ~= props.Value then
			UIFeedback.click()
		end
		props.OnChange(nextValue, true)
	end

	return c("Frame", {
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = props.Size or UDim2.fromScale(1, 1),
	}, {
		Value = c(ResponsiveText, {
			MeasurementFont = Enum.Font.SourceSansBold,
			MaxTextSize = 20,
			Native = {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(1, 0.16),
				Size = UDim2.fromScale(0.24, 0.4),
				Text = displayText,
				TextColor3 = if enabled then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 150),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 5,
			},
		}),
		HitTarget = c("Frame", {
			ref = trackRef,
			Active = true,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 0.44),
			Selectable = enabled,
			Size = UDim2.fromScale(1, 0.56),
			ZIndex = 4,
			[React.Event.InputBegan] = function(_object, input: InputObject)
				if not enabled then
					return
				end
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					beginMouseDrag(input.Position.X)
				elseif input.UserInputType == Enum.UserInputType.Touch then
					beginTouch(input.Position.X, input.Position.Y)
				elseif input.KeyCode == Enum.KeyCode.DPadLeft then
					step(-1)
				elseif input.KeyCode == Enum.KeyCode.DPadRight then
					step(1)
				end
			end,
			[React.Event.InputChanged] = function(_object, input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseMovement and drag.current then
					moveMouse(input.Position.X)
				elseif input.UserInputType == Enum.UserInputType.Touch then
					moveTouch(input.Position.X, input.Position.Y)
				end
			end,
			[React.Event.InputEnded] = function(_object, input: InputObject)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					endDrag(true)
				end
			end,
		}, {
			Track = c("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = TRACK_COLOR,
				BackgroundTransparency = if enabled then 0.12 else 0.5,
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromScale(1, 0.34),
				ZIndex = 4,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Fill = c("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = if enabled then FILL_COLOR else DISABLED_FILL,
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromScale(alpha, 1),
					ZIndex = 5,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
				Ticks = if #stops > 1
					then c(
						React.Fragment,
						nil,
						(function()
							local marks = {}
							for index, stop in stops do
								marks[`Tick{index}`] = c("Frame", {
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundColor3 = Color3.new(1, 1, 1),
									BackgroundTransparency = 0.55,
									Position = UDim2.fromScale(SettingsValues.valueToAlpha(definition, stop), 0.5),
									Size = UDim2.fromOffset(6, 6),
									ZIndex = 6,
								}, {
									Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
								})
							end
							return marks
						end)()
					)
					else nil,
			}),
			Thumb = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				Position = UDim2.fromScale(alpha, 0.5),
				Size = UDim2.fromOffset(26, 26),
				ZIndex = 6,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Stroke = c("UIStroke", {
					Color = THUMB_STROKE,
					Thickness = 2,
				}),
			}),
		}),
	})
end
