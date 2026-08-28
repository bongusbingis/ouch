-- Name: OnboardingOverlay.luau
-- Author: Jack C.
-- Description: The first-session training overlay: a prompt that pops in on every new instruction, an animated demonstration of the input it is asking for, how far through the player is, a discreet skip, and the completion celebration. Presentation only -- every value it renders comes from the onboarding snapshot passed in.
-- Created: 2026-08-26

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local Motion = require(script.Parent.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Parent.Hooks.useReducedMotion)
local useEntrance = require(script.Parent.Parent.Parent.Hooks.useEntrance)
local AnimatedButton = require(script.Parent.Parent.AnimatedButton)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)
local GestureHint = require(script.Parent.GestureHint)

local c = React.createElement

local ACCENT = Color3.fromRGB(97, 255, 237)
local SUCCESS = Color3.fromRGB(0, 255, 42)
local PANEL = Color3.fromRGB(52, 52, 52)

-- Short, verb-first copy. The world is the teacher; this line only names the
-- action so the player knows which one to try.
local CUE_COPY: { [string]: { title: string, detail: string? } } = {
	Ready = { title = "READY?" },
	Throw = { title = "THROW!", detail = "AIM AT THE DUMMY, THEN THROW" },
	Cross = { title = "GET ACROSS!", detail = "USE THE BRIDGE" },
	Bonk = { title = "BONK!", detail = "GET CLOSE, THEN SWING" },
	Charge = { title = "HOLD FOR POWER!", detail = "HOLD, THEN RELEASE" },
	Brawl = { title = "KNOCK 'EM OUT!" },
	Done = { title = "NICE WORK!" },
}

local GESTURE_FOR_CUE: { [string]: GestureHint.Gesture } = {
	Throw = "Tap",
	Cross = "Move",
	Bonk = "Tap",
	Charge = "Hold",
}

local INPUT_HINT: { [string]: { [string]: string } } = {
	Throw = { Mouse = "CLICK", Touch = "TAP", Gamepad = "PRESS RT" },
	Cross = { Mouse = "WASD", Touch = "JOYSTICK", Gamepad = "LEFT STICK" },
	Bonk = { Mouse = "CLICK", Touch = "TAP", Gamepad = "PRESS RT" },
	Charge = { Mouse = "HOLD CLICK", Touch = "HOLD", Gamepad = "HOLD RT" },
}

local SKILLS = { "THROW", "BONK", "POWER" }
local LESSONS = { "NormalThrow", "Hammer", "ChargedThrow", "Practice" }

local function lessonProgress(step: string): number
	if step == "Celebration" then
		return #LESSONS
	end
	local index = table.find(LESSONS, step)
	return if index then index - 1 else 0
end

local function ProgressPips(props: { done: number, reducedMotion: boolean })
	local pips: { [string]: any } = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index = 1, #LESSONS do
		local complete = index <= props.done
		local active = index == props.done + 1
		pips[`Pip{index}`] = c("Frame", {
			BackgroundColor3 = if complete then SUCCESS else PANEL,
			BackgroundTransparency = if complete then 0 elseif active then 0.15 else 0.55,
			LayoutOrder = index,
			Size = if active then UDim2.fromOffset(26, 10) else UDim2.fromOffset(14, 10),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = c("UIStroke", {
				Color = if active then ACCENT else Color3.fromRGB(30, 30, 30),
				Thickness = 2,
				Transparency = if complete or active then 0.1 else 0.6,
			}),
		})
	end
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.026),
		Size = UDim2.fromOffset(160, 12),
		ZIndex = 61,
	}, pips)
end

export type Props = {
	Snapshot: any,
	OnSkip: () -> (),
}

return function(props: Props)
	local snapshot = props.Snapshot
	local reducedMotion = useReducedMotion()
	local active = snapshot ~= nil and snapshot.active == true
	local cue = if snapshot then snapshot.cue or "Ready" else "Ready"
	local celebrating = active and cue == "Done"

	local styles = ReactSpring.useSpring({
		Scale = if active then 1 else 0.85,
		Offset = if active then 0 else -0.08,
		config = Motion.Modal,
		immediate = reducedMotion,
	})
	local entrance = useEntrance(cue, Motion.Pop, reducedMotion)

	if not active then
		return nil
	end

	local copy = CUE_COPY[cue] or CUE_COPY.Ready
	local hint = if snapshot.succeeded
		then nil
		else (INPUT_HINT[cue] and INPUT_HINT[cue][snapshot.deviceClass or "Mouse"])
	local title = if snapshot.succeeded and not celebrating then "NICE!" else copy.title
	local detail = if snapshot.hintLevel and snapshot.hintLevel >= 2 then copy.detail else nil
	local gesture = GESTURE_FOR_CUE[cue]
	local done = lessonProgress(snapshot.step or "Intro")

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
	}, {
		Progress = if celebrating then nil else c(ProgressPips, { done = done, reducedMotion = reducedMotion }),

		Gesture = if gesture and not snapshot.succeeded
			then c(GestureHint, {
				Gesture = gesture,
				DeviceClass = snapshot.deviceClass or "Mouse",
				Label = hint,
			})
			else nil,

		Prompt = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = styles.Offset:map(function(offset: number)
				return UDim2.fromScale(0.5, 0.08 + offset)
			end),
			Size = UDim2.fromScale(0.5, 0.2),
			ZIndex = 61,
		}, {
			Scale = c("UIScale", { Scale = styles.Scale }),
			Aspect = c("UIAspectRatioConstraint", {
				AspectRatio = 3.4,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			}),
			Title = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 64,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromScale(1, 0.54),
					Text = title,
					TextColor3 = if snapshot.succeeded then SUCCESS else Color3.new(1, 1, 1),
					ZIndex = 62,
				},
			}, {
				Stroke = c("UIStroke", {
					Color = Color3.fromRGB(63, 63, 63),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.055,
				}),
				Pop = c("UIScale", {
					Scale = entrance.Alpha:map(function(alpha: number)
						return 0.55 + 0.45 * alpha
					end),
				}),
			}),
			Detail = if detail
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.SourceSans,
					MaxTextSize = 18,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
						Position = UDim2.fromScale(0.5, 0.9),
						Size = UDim2.fromScale(0.9, 0.16),
						Text = detail,
						TextColor3 = Color3.fromRGB(210, 210, 210),
						ZIndex = 62,
					},
				})
				else nil,
		}),

		Skills = if celebrating
			then c(
				"Frame",
				{
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.3),
					Size = UDim2.fromScale(0.44, 0.08),
					ZIndex = 61,
				},
				(function()
					local cells: { [string]: any } = {
						Layout = c("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Padding = UDim.new(0.04, 0),
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
					}
					for index, name in SKILLS do
						local appearAt = (index - 1) * 0.22
						cells[name] = c(ResponsiveText, {
							MeasurementFont = Enum.Font.LuckiestGuy,
							MaxTextSize = 26,
							Native = {
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
								LayoutOrder = index,
								Size = UDim2.fromScale(0.3, 1),
								Text = `✓ {name}`,
								TextColor3 = SUCCESS,
								ZIndex = 62,
							},
						}, {
							Pop = c("UIScale", {
								Scale = entrance.Alpha:map(function(alpha: number)
									return 0.2 + 0.8 * math.clamp((alpha - appearAt) / 0.4, 0, 1)
								end),
							}),
						})
					end
					return cells
				end)()
			)
			else nil,

		-- Discreet, always reachable, and never the loudest thing on screen.
		Skip = if not celebrating
			then c(AnimatedButton, {
				Native = {
					AnchorPoint = Vector2.new(1, 0),
					BackgroundColor3 = PANEL,
					BackgroundTransparency = 0.35,
					Position = UDim2.fromScale(0.98, 0.04),
					Size = UDim2.fromScale(0.09, 0.05),
					ZIndex = 63,
				},
				OnActivated = props.OnSkip,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0.35, 0) }),
				Sizer = c("UISizeConstraint", { MinSize = Vector2.new(76, 30), MaxSize = Vector2.new(150, 56) }),
				Label = c(ResponsiveText, {
					MeasurementFont = Enum.Font.SourceSansBold,
					MaxTextSize = 18,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/SourceSansPro.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.86, 0.7),
						Text = "SKIP",
						TextColor3 = Color3.fromRGB(220, 220, 220),
						ZIndex = 64,
					},
				}),
			})
			else nil,
	})
end
