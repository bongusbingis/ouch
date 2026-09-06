-- Name: OnboardingOverlay.luau
-- Author: Jack C.
-- Description: Renders the first-session instruction panel, progress, skip action, and completion card.
-- Created: 2026-08-26

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Input"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Motion = require(script.Parent.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Parent.Hooks.useReducedMotion)
local useEntrance = require(script.Parent.Parent.Parent.Hooks.useEntrance)
local useViewportSize = require(script.Parent.Parent.Parent.Hooks.useViewportSize)
local usePreferredTextSize = require(script.Parent.Parent.Parent.Hooks.usePreferredTextSize)
local AnimatedButton = require(script.Parent.Parent.AnimatedButton)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)

local c = React.createElement

local PANEL_IMAGE = "rbxassetid://124751224634629"
local PANEL_SLICE = Rect.new(31, 41, 978, 620)
local BUTTON_IMAGE = "rbxassetid://136021539696619"
local BUTTON_SLICE = Rect.new(198, 228, 841, 468)
local INK = Color3.fromRGB(24, 41, 48)
local ACCENT = Color3.fromRGB(97, 255, 237)
local SUCCESS = Color3.fromRGB(0, 255, 42)
local HEADLINE_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

local CUE_COPY: { [string]: { title: string, detail: string? } } = {
	Ready = { title = "READY?" },
	Throw = { title = "THROW!", detail = "AIM AT THE DUMMY, THEN THROW" },
	Cross = { title = "GET ACROSS!", detail = "USE THE BRIDGE" },
	Bonk = { title = "BONK!", detail = "GET CLOSE, THEN SWING" },
	Charge = { title = "HOLD FOR POWER!", detail = "HOLD, THEN RELEASE" },
	Brawl = { title = "KNOCK 'EM OUT!" },
	Done = { title = "NICE WORK!" },
}

local SKILLS = { "THROW", "BONK", "POWER" }
local LESSONS = { "NormalThrow", "Hammer", "ChargedThrow", "Practice" }

-- The one action label a mouse or gamepad player needs to read for each hands-on
-- cue. Touch players are shown the physical gesture instead, so this is only
-- consulted off touch.
local CONTROL_VERB: { [string]: string } = {
	Throw = "THROW",
	Bonk = "SWING",
	Charge = "HOLD",
}

local function lessonProgress(step: string): number
	if step == "Celebration" then
		return #LESSONS
	end
	local index = table.find(LESSONS, step)
	return if index then index - 1 else 0
end

local function textStroke(thickness: number)
	return c("UIStroke", {
		Color = INK,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = thickness,
		Transparency = 0.08,
	})
end

-- The runtime-built input context may not have replicated yet, so callers fall
-- back to a plain label when an action is not resolvable.
local function boundAction(name: string): any
	local context = Players.LocalPlayer:FindFirstChild(InputConfig.ContextName)
	local action = context and context:FindFirstChild(name)
	return if action and action:IsA("InputAction") then action else nil
end

local function skipAction(): any
	return boundAction("OnboardingSkip")
end

-- A compact, device-accurate control prompt shown inline on the panel for mouse
-- and gamepad players in place of a floating gesture diagram: the bound Throw
-- glyph beside the verb for the current cue.
local function ControlHint(props: { verb: string, fallback: string })
	local preferredTextSize = usePreferredTextSize()
	local glyphTextSize =
		math.round(UIConfig.Text.InputGlyphSize * (UIConfig.Text.PreferredScale[preferredTextSize.Name] or 1))
	local action = boundAction("Throw")
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.75),
		Size = UDim2.fromScale(0.9, 0.24),
		ZIndex = 62,
	}, {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.03, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Key = if action
			then c("InputActionLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = BODY_FONT,
				ImageColor3 = Color3.new(1, 1, 1),
				InputAction = action,
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.16, 0.95),
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = glyphTextSize,
				ZIndex = 63,
			})
			else c("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.19, 0.86),
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0.28, 0) }),
				Stroke = c("UIStroke", {
					Color = INK,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.07,
				}),
				Text = c(ResponsiveText, {
					MeasurementFont = Enum.Font.Highway,
					MaxTextSize = 20,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = BODY_FONT,
						Position = UDim2.fromScale(0.5, 0.52),
						Size = UDim2.fromScale(0.78, 0.6),
						Text = props.fallback,
						TextColor3 = INK,
						ZIndex = 63,
					},
				}),
			}),
		Verb = c(ResponsiveText, {
			HostName = "Verb",
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 26,
			Native = {
				BackgroundTransparency = 1,
				FontFace = HEADLINE_FONT,
				LayoutOrder = 2,
				Size = UDim2.fromScale(0.52, 0.86),
				Text = props.verb,
				TextColor3 = ACCENT,
				ZIndex = 62,
			},
		}, { Stroke = textStroke(0.06) }),
	})
end

local function ProgressPips(props: { done: number })
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
			BackgroundColor3 = if complete then SUCCESS elseif active then ACCENT else INK,
			BackgroundTransparency = if complete or active then 0 else 0.45,
			LayoutOrder = index,
			Size = if active then UDim2.fromOffset(26, 10) else UDim2.fromOffset(14, 10),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = c("UIStroke", {
				Color = INK,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.18,
				Transparency = 0.15,
			}),
		})
	end
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 1.08),
		Size = UDim2.fromOffset(160, 12),
		ZIndex = 63,
	}, pips)
end

export type Props = {
	Snapshot: any,
	OnSkip: () -> (),
}

return function(props: Props)
	local snapshot = props.Snapshot
	local preferredTextSize = usePreferredTextSize()
	local glyphTextSize =
		math.round(UIConfig.Text.InputGlyphSize * (UIConfig.Text.PreferredScale[preferredTextSize.Name] or 1))
	local reducedMotion = useReducedMotion()
	local viewport = useViewportSize()
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
	local title = if snapshot.succeeded and not celebrating then "NICE!" else copy.title
	local detail = if snapshot.hintLevel and snapshot.hintLevel >= 2 then copy.detail else nil
	local done = lessonProgress(snapshot.step or "Intro")
	local touch = snapshot.deviceClass == "Touch"
	local action = if touch then nil else skipAction()
	-- Off touch, hands-on cues carry an inline control glyph rather than a
	-- floating gesture; the escalated tip only shows when there is no glyph, so
	-- the compact panel never stacks two secondary lines.
	local controlVerb = if not touch and not celebrating and not snapshot.succeeded then CONTROL_VERB[cue] else nil
	local showDetail = detail ~= nil and controlVerb == nil
	local secondaryRow = controlVerb ~= nil or showDetail

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
	}, {
		Prompt = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = PANEL_IMAGE,
			ImageColor3 = if snapshot.succeeded then SUCCESS else Color3.new(1, 1, 1),
			Position = styles.Offset:map(function(offset: number)
				return UDim2.fromScale(0.5, 0.05 + offset)
			end),
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromScale(0.34, 0.13),
			SliceCenter = PANEL_SLICE,
			SliceScale = 0.35,
			ZIndex = 61,
		}, {
			Scale = c("UIScale", { Scale = styles.Scale }),
			Progress = if celebrating then nil else c(ProgressPips, { done = done }),
			Aspect = c("UIAspectRatioConstraint", {
				AspectRatio = 3.4,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			}),
			Bounds = c("UISizeConstraint", {
				MaxSize = Vector2.new(560, 165),
				MinSize = Vector2.new(260, 76),
			}),
			Title = c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 46,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = HEADLINE_FONT,
					Position = UDim2.fromScale(0.5, if secondaryRow then 0.4 else 0.5),
					Size = UDim2.fromScale(0.86, 0.42),
					Text = title,
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 62,
				},
			}, {
				Stroke = textStroke(0.045),
				Pop = c("UIScale", {
					Scale = entrance.Alpha:map(function(alpha: number)
						return 0.55 + 0.45 * alpha
					end),
				}),
			}),
			Detail = if showDetail
				then c(ResponsiveText, {
					HostName = "Detail",
					MeasurementFont = Enum.Font.Highway,
					MaxTextSize = 28,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = BODY_FONT,
						Position = UDim2.fromScale(0.5, 0.73),
						Size = UDim2.fromScale(0.84, 0.2),
						Text = detail,
						TextColor3 = ACCENT,
						ZIndex = 62,
					},
				}, { Stroke = textStroke(0.06) })
				else nil,
			Control = if controlVerb
				then c(ControlHint, {
					verb = controlVerb,
					fallback = if snapshot.deviceClass == "Gamepad" then "RT" else "LMB",
				})
				else nil,
		}),

		Skills = if celebrating
			then c(
				"Frame",
				{
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, if viewport.X < 600 then 0.34 else 0.27),
					Size = UDim2.fromScale(0.44, 0.08),
					ZIndex = 61,
				},
				(function()
					local cells: { [string]: any } = {
						Layout = c("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Padding = UDim.new(0.03, 0),
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
					}
					for index, name in SKILLS do
						local appearAt = (index - 1) * 0.22
						cells[name] = c("ImageLabel", {
							BackgroundTransparency = 1,
							Image = BUTTON_IMAGE,
							ImageColor3 = SUCCESS,
							LayoutOrder = index,
							ScaleType = Enum.ScaleType.Slice,
							Size = UDim2.fromScale(0.31, 1),
							SliceCenter = BUTTON_SLICE,
							SliceScale = 0.1,
							ZIndex = 62,
						}, {
							Pop = c("UIScale", {
								Scale = entrance.Alpha:map(function(alpha: number)
									return 0.2 + 0.8 * math.clamp((alpha - appearAt) / 0.4, 0, 1)
								end),
							}),
							Label = c(ResponsiveText, {
								MeasurementFont = Enum.Font.LuckiestGuy,
								MaxTextSize = 26,
								Native = {
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									FontFace = HEADLINE_FONT,
									Position = UDim2.fromScale(0.5, 0.54),
									Size = UDim2.fromScale(0.82, 0.5),
									Text = name,
									TextColor3 = Color3.new(1, 1, 1),
									ZIndex = 63,
								},
							}, { Stroke = textStroke(0.05) }),
						})
					end
					return cells
				end)()
			)
			else nil,

		Skip = if not celebrating and touch
			then c(AnimatedButton, {
				Native = {
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 1,
					Image = BUTTON_IMAGE,
					ImageTransparency = 0.25,
					Position = if viewport.X < 600 then UDim2.fromScale(0.98, 0.31) else UDim2.fromScale(0.98, 0.035),
					ScaleType = Enum.ScaleType.Slice,
					Size = UDim2.fromScale(0.11, 0.075),
					SliceCenter = BUTTON_SLICE,
					SliceScale = 0.12,
					ZIndex = 63,
				},
				OnActivated = props.OnSkip,
			}, {
				Aspect = c("UIAspectRatioConstraint", { AspectRatio = 3.1 }),
				Sizer = c("UISizeConstraint", {
					MinSize = Vector2.new(UIConfig.Interaction.MinTargetPx * 3.1, UIConfig.Interaction.MinTargetPx),
					MaxSize = Vector2.new(190, 61),
				}),
				Label = c(ResponsiveText, {
					MeasurementFont = Enum.Font.LuckiestGuy,
					MaxTextSize = 24,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = HEADLINE_FONT,
						Position = UDim2.fromScale(0.5, 0.54),
						Size = UDim2.fromScale(0.76, 0.54),
						Text = "SKIP",
						TextColor3 = Color3.new(1, 1, 1),
						ZIndex = 64,
					},
				}, { Stroke = textStroke(0.05) }),
			})
			else if not celebrating
				then c("ImageLabel", {
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 1,
					Image = BUTTON_IMAGE,
					ImageTransparency = 0.12,
					Position = UDim2.fromScale(0.98, 0.035),
					ScaleType = Enum.ScaleType.Slice,
					Size = UDim2.fromScale(0.125, 0.075),
					SliceCenter = BUTTON_SLICE,
					SliceScale = 0.12,
					ZIndex = 63,
				}, {
					Aspect = c("UIAspectRatioConstraint", { AspectRatio = 3.35 }),
					Sizer = c("UISizeConstraint", {
						MinSize = Vector2.new(116, 35),
						MaxSize = Vector2.new(210, 63),
					}),
					Glyph = if action
						then c("InputActionLabel", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = BODY_FONT,
							ImageColor3 = Color3.new(1, 1, 1),
							InputAction = action,
							Position = UDim2.fromScale(0.24, 0.5),
							Size = UDim2.fromScale(0.28, 0.62),
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = glyphTextSize,
							ZIndex = 64,
						})
						else c(ResponsiveText, {
							MeasurementFont = Enum.Font.Highway,
							MaxTextSize = 21,
							Native = {
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								FontFace = BODY_FONT,
								Position = UDim2.fromScale(0.24, 0.52),
								Size = UDim2.fromScale(0.24, 0.5),
								Text = if snapshot.deviceClass == "Gamepad" then "B" else "X",
								TextColor3 = Color3.new(1, 1, 1),
								ZIndex = 64,
							},
						}, { Stroke = textStroke(0.06) }),
					Label = c(ResponsiveText, {
						MeasurementFont = Enum.Font.LuckiestGuy,
						MaxTextSize = 23,
						Native = {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = HEADLINE_FONT,
							Position = UDim2.fromScale(0.64, 0.54),
							Size = UDim2.fromScale(0.54, 0.54),
							Text = "SKIP",
							TextColor3 = Color3.new(1, 1, 1),
							ZIndex = 64,
						},
					}, { Stroke = textStroke(0.05) }),
				})
				else nil,
	})
end
