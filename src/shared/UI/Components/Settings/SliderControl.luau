-- Description: Reusable slider for the settings system: continuous, step-snapped, or an explicit set of allowed stops, all resolved through SettingsValues' single alpha/value mapping so track clicks, thumb drags, and controller nudges can never disagree. A press begins on the hit target, then global move/release tracking keeps the drag claimed until the player lets go even when the pointer leaves the control.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SettingsValues = require(Shared:WaitForChild("Game"):WaitForChild("Settings"):WaitForChild("SettingsValues"))
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)
local UIFeedback = require(script.Parent.Parent.Parent.Services.UIFeedback)
local Selection = require(script.Parent.Parent.Parent.Services.Selection)
local CandySurface = require(script.Parent.Parent.CandySurface)
local Tokens = require(script.Parent.Parent.Parent.Tokens)

local c = React.createElement

local C = Tokens.Colors
local SETTINGS = Tokens.Settings
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
	input: InputObject,
	claimed: boolean,
	rejected: boolean,
	startX: number,
	startY: number,
}

return function(props: Props)
	local enabled = props.Enabled ~= false
	local definition = props.Definition
	local trackRef = React.useRef(nil)
	local selectionImageRef = React.useRef(nil)
	local focused, setFocused = React.useState(false)
	local drag = React.useRef(nil :: DragState?)
	local latestProps = React.useRef(props)
	latestProps.current = props

	React.useEffect(function()
		local target = trackRef.current
		local selectionImage = selectionImageRef.current
		if target then
			target.NextSelectionLeft = target
			target.NextSelectionRight = target
			target.SelectionImageObject = selectionImage
		end
		return function()
			if target and target.SelectionImageObject == selectionImage then
				target.SelectionImageObject = nil
			end
		end
	end, {})

	local alpha = SettingsValues.valueToAlpha(definition, props.Value)
	local stops = SettingsValues.stops(definition)
	local displayText = if props.Format then props.Format(props.Value) else tostring(props.Value)

	local function alphaFromX(x: number): number
		local track = trackRef.current
		if track == nil then
			local latest = latestProps.current
			return SettingsValues.valueToAlpha(latest.Definition, latest.Value)
		end
		local origin = track.AbsolutePosition.X
		local width = track.AbsoluteSize.X
		if width <= 0 then
			local latest = latestProps.current
			return SettingsValues.valueToAlpha(latest.Definition, latest.Value)
		end
		return math.clamp((x - origin) / width, 0, 1)
	end

	local function apply(newAlpha: number, committed: boolean)
		local latest = latestProps.current
		local value = SettingsValues.alphaToValue(latest.Definition, newAlpha)
		latest.OnChange(value, committed)
	end

	local function endDrag(committed: boolean)
		local state = drag.current
		drag.current = nil
		if state and committed and not state.rejected then
			apply(alphaFromX(state.startX), true)
		end
	end

	local function beginMouseDrag(input: InputObject)
		drag.current = {
			trackRef = trackRef,
			input = input,
			claimed = true,
			rejected = false,
			startX = input.Position.X,
			startY = input.Position.Y,
		}
		apply(alphaFromX(input.Position.X), false)
	end

	local function beginTouch(input: InputObject)
		drag.current = {
			trackRef = trackRef,
			input = input,
			claimed = false,
			rejected = false,
			startX = input.Position.X,
			startY = input.Position.Y,
		}
	end

	local function moveMouse(x: number)
		local state = drag.current
		if state == nil or latestProps.current.Enabled == false then
			return
		end
		state.startX = x
		apply(alphaFromX(x), false)
	end

	local function moveTouch(x: number, y: number)
		local state = drag.current
		if state == nil or state.rejected or latestProps.current.Enabled == false then
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

	React.useEffect(function()
		local changed = UserInputService.InputChanged:Connect(function(input: InputObject)
			local state = drag.current
			if state == nil then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				if state.input.UserInputType == Enum.UserInputType.MouseButton1 then
					moveMouse(input.Position.X)
				end
			elseif input.UserInputType == Enum.UserInputType.Touch and input == state.input then
				moveTouch(input.Position.X, input.Position.Y)
			end
		end)
		local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
			local state = drag.current
			if state == nil then
				return
			end
			local mouseReleased = state.input.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseButton1
			if input == state.input or mouseReleased then
				endDrag(true)
			end
		end)
		local focusReleased = UserInputService.WindowFocusReleased:Connect(function()
			if drag.current then
				endDrag(true)
			end
		end)
		return function()
			drag.current = nil
			changed:Disconnect()
			ended:Disconnect()
			focusReleased:Disconnect()
		end
	end, {})

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
		ZIndex = 6,
	}, {
		Value = c(ResponsiveText, {
			MeasurementFont = Tokens.Type.Label,
			MaxTextSize = 20,
			MinTextSize = 16,
			Native = {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Font = Tokens.Type.Label,
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(1, 0, 0, UIConfig.Layout.SettingsControls.SliderLabelHeightPx),
				Text = displayText,
				TextColor3 = C.Ink,
				TextTransparency = if enabled then 0 else 0.3,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 5,
			},
		}),
		HitTarget = c("Frame", {
			ref = trackRef,
			Active = true,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 1, -UIConfig.Interaction.MinTargetPx),
			Selectable = enabled,
			Size = UDim2.new(1, 0, 0, UIConfig.Interaction.MinTargetPx),
			ZIndex = 4,
			[React.Event.SelectionGained] = function(target)
				setFocused(true)
				Selection.scrollIntoView(target)
			end,
			[React.Event.SelectionLost] = function()
				setFocused(false)
			end,
			[React.Event.InputBegan] = function(_object, input: InputObject)
				if not enabled then
					return
				end
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					beginMouseDrag(input)
				elseif input.UserInputType == Enum.UserInputType.Touch then
					beginTouch(input)
				elseif input.KeyCode == Enum.KeyCode.DPadLeft then
					step(-1)
				elseif input.KeyCode == Enum.KeyCode.DPadRight then
					step(1)
				end
			end,
		}, {
			SelectionImage = c("Frame", {
				ref = selectionImageRef,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 10,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Interaction.FocusCornerPx) }),
				Outline = c("UIStroke", {
					Color = C.Yellow,
					Thickness = UIConfig.Interaction.FocusStrokePx,
					Transparency = if focused and enabled then 0 else 1,
				}),
			}),
			Track = c("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.new(1, 0, 0, SETTINGS.SliderTrackHeight),
				ZIndex = 4,
			}, {
				Surface = c(CandySurface, {
					Color = if enabled then C.Surface else C.WellLine,
					LipColor = C.WellLine,
					Radius = Tokens.Shape.RadiusPill,
					Shadow = false,
					ZIndex = 4,
				}),
				Fill = c("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = if enabled then C.Pink else C.WellLine,
					BorderSizePixel = 0,
					Position = UDim2.new(0, 0, 0.5, -Tokens.Shape.LipHeight / 2),
					Size = UDim2.new(alpha, 0, 1, -Tokens.Shape.LipHeight),
					ZIndex = 7,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Highlight = c("Frame", {
						BackgroundColor3 = C.Surface,
						BackgroundTransparency = Tokens.Shape.HighlightTransparency,
						BorderSizePixel = 0,
						Size = UDim2.fromScale(1, 0.45),
						ZIndex = 8,
					}, {
						Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					}),
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
									BackgroundColor3 = C.InkSoft,
									BackgroundTransparency = 0.7,
									BorderSizePixel = 0,
									Position = UDim2.fromScale(SettingsValues.valueToAlpha(definition, stop), 0.5),
									Size = UDim2.fromOffset(6, 6),
									ZIndex = 9,
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
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(alpha, 0.5),
				Size = UDim2.fromOffset(SETTINGS.SliderThumbSize, SETTINGS.SliderThumbSize),
				ZIndex = 10,
			}, {
				Surface = c(CandySurface, {
					Color = if enabled then C.Yellow else C.WellLine,
					LipColor = if enabled then C.YellowLip else C.WellLine,
					Radius = Tokens.Shape.RadiusPill,
					Shadow = false,
					ZIndex = 10,
				}),
			}),
		}),
	})
end
