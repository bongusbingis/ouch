--!strict
-- The original compact prompt and separate skip, using shared candy surfaces.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local UI = script.Parent.Parent.Parent
local T = require(UI.Tokens)
local Motion = require(UI.Motion)
local Model = require(UI.Models.OnboardingViewModel)
local useSafeArea = require(UI.Hooks.useSafeArea)
local useReducedMotion = require(UI.Hooks.useReducedMotion)
local useEntrance = require(UI.Hooks.useEntrance)
local usePreferredTextSize = require(UI.Hooks.usePreferredTextSize)
local UIConfig = require(RS.Config.Interface.UI)
local Config = require(RS.Config.Interface.Onboarding)
local CandySurface = require(script.Parent.Parent.CandySurface)
local PuffyButton = require(script.Parent.Parent.PuffyButton)
local InputHint = require(script.Parent.Parent.InputHint)
local SKIP = require(RS.Config.Interface.Input).Hints.Skip
local c, C, L = React.createElement, T.Colors, T.Onboarding

return function(props)
	local snapshot = props.Snapshot or {}
	local view = Model.build(snapshot)
	local safe = useSafeArea(nil, Enum.ScreenInsets.CoreUISafeInsets)
	local preferred = usePreferredTextSize()
	local reducedMotion = useReducedMotion()
	local layout = Model.layout(safe.size.X, safe.size.Y, UIConfig.Text.PreferredScale[preferred.Name] or 1)
	local entrance = useEntrance(snapshot.step, Motion.Control, reducedMotion)
	if not snapshot.active then
		return nil
	end
	local top = math.max(0, safe.position.Y) + layout.edge
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60 }, {
		Prompt = c("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(safe.position.X + layout.x, top),
			Size = UDim2.fromOffset(layout.width, layout.height),
			ZIndex = 61,
		}, {
			Scale = c("UIScale", { Scale = entrance.Alpha:map(function(alpha)
				return 0.97 + 0.03 * alpha
			end) }),
			Face = c(
				"Frame",
				{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = T.Shape.TiltPanel, ZIndex = 61 },
				{
					Surface = c(CandySurface, { Color = C.SurfaceWarm, Radius = T.Shape.RadiusCard, ZIndex = 61 }),
				}
			),
			Title = c("TextLabel", {
				BackgroundTransparency = 1,
				Text = view.title,
				Font = T.Type.Display,
				TextSize = layout.title,
				TextColor3 = C.Ink,
				TextWrapped = true,
				Position = UDim2.fromOffset(layout.inset, layout.inset),
				Size = UDim2.new(1, -layout.inset * 2, 0, layout.titleHeight),
				ZIndex = 66,
			}),
			Detail = c("TextLabel", {
				BackgroundTransparency = 1,
				Text = view.detail,
				Font = T.Type.Label,
				TextSize = layout.body,
				TextColor3 = C.InkSoft,
				TextWrapped = true,
				Position = UDim2.fromOffset(layout.inset, layout.inset + layout.titleHeight),
				Size = UDim2.new(1, -layout.inset * 2, 0, layout.bodyHeight),
				ZIndex = 66,
			}),
		}),
		Skip = if not view.celebrating and Config.Eligibility.SkipEnabled
			then c(PuffyButton, {
				Color = C.Yellow,
				TextColor = C.Ink,
				Text = view.skip,
				TextSize = T.Type.Minimum,
				OnActivated = props.OnSkip,
				Shadow = false,
				-- "SKIP [X]": the key trails the verb so it reads as a prompt, never a close icon.
				children = {
					Key = c(InputHint.Component, {
						Binding = SKIP,
						Native = {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -T.InputHint.CornerInset * 2, 0.5, -T.Shape.LipHeight / 2),
							ZIndex = 74,
						},
					}),
				},
				Native = {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromOffset(safe.position.X + safe.size.X - layout.edge, top),
					Size = UDim2.fromOffset(L.SkipWidth, T.Layout.MinTarget),
					ZIndex = 68,
				},
			})
			else nil,
	})
end
