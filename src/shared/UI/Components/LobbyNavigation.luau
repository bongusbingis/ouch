--!strict
-- One connected candy rail. Hitboxes stay still while the selected tile rises.
local RS = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local React = require(RS.Packages.react)
local ReactSpring = require(RS.Packages["react-spring"])
local T = require(script.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local AnimatedButton = require(script.Parent.AnimatedButton)
local CandySurface = require(script.Parent.CandySurface)
local LobbySelectionPillow = require(script.Parent.LobbySelectionPillow)
local Icon = require(script.Parent.Icon)
local InputHint = require(script.Parent.InputHint)
local InputHintModel = require(script.Parent.Parent.Models.InputHintModel)
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local HINTS = require(RS:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Input")).Hints
local CYCLE_ACTION = "CycleMenuTabs"
local c, C, N = React.createElement, T.Colors, T.LobbyNavigation

local function NavigationTab(props)
	local tab = props.Tab
	local selected = props.Selected
	local enabled = tab.Enabled ~= false
	local reducedMotion = useReducedMotion()
	local styles, api = ReactSpring.useSpring(function()
		return { Selection = if selected then 1 else 0 }
	end)
	React.useEffect(function()
		api.start({ Selection = if selected then 1 else 0, config = Motion.Navigation, immediate = reducedMotion })
	end, { selected, reducedMotion })
	React.useEffect(function()
		return function()
			api.stop()
		end
	end, {})
	local function state(map)
		return styles.Selection:map(function(value)
			return map(math.clamp(value, 0, 1))
		end)
	end
	local function geometry(map)
		return styles.Selection:map(function(value)
			-- Keep the pillow, icon, and label within their authored endpoints.
			return map(math.clamp(value, 0, 1))
		end)
	end
	local icon = N.Icons[tab.Id]
	local compact = props.Compact
	local iconOnly = props.IconOnly == true
	-- Decided once per rail so every tab shares one label face.
	local tightLabel = props.Tight == true
	local iconSize = if compact then N.CompactIcon else N.Icon
	local selectedIcon = if compact then N.CompactSelectedIcon else N.SelectedIcon
	local iconTop = if compact then N.CompactIconTop else N.IconTop
	local pad = N.EffectPadding
	return c(AnimatedButton, {
		ButtonRef = tab.ButtonRef,
		Enabled = enabled,
		Style = "Primary",
		HoverRotation = false,
		SelectionRadius = UDim.new(0, N.Radius),
		OnSelectionGained = tab.OnSelectionGained,
		OnActivated = function()
			props.OnNavigate(tab.Id)
		end,
		Native = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = "",
			Position = UDim2.fromOffset(props.Left, 0),
			Size = UDim2.new(0, props.Width, 1, 0),
			ZIndex = if selected then 5 else 3,
		},
	}, {
		RaisedFace = c("CanvasGroup", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = geometry(function(s)
				return UDim2.new(0.5, 0, 0.5, -N.SelectedLift * s)
			end),
			Size = geometry(function(s)
				return UDim2.new(
					1,
					pad * 2 + (if compact then N.CompactSelectedOverhang else N.SelectedOverhang) * s,
					1,
					pad * 2 + (if compact then N.CompactSelectedGrowth else N.SelectedGrowth) * s
				)
			end),
			GroupTransparency = state(function(s)
				return 1 - s
			end),
			ZIndex = 1,
		}, {
			Plate = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(pad, pad),
				Size = UDim2.new(1, -pad * 2, 1, -pad * 2),
			}, {
				Pillow = c(LobbySelectionPillow, {
					Compact = compact,
					Rotation = geometry(function(s)
						return N.SelectedTilt * s
					end),
				}),
			}),
		}),
		Icon = c("ImageLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = geometry(function(s)
				if iconOnly then
					local size = iconSize + (selectedIcon - iconSize) * s
					return UDim2.new(0.5, 0, 0.5, -size / 2 - N.SelectedLift * s)
				end
				return UDim2.new(0.5, 0, 0, iconTop - (if compact then N.SelectedLift else N.SelectedContentLift) * s)
			end),
			Size = geometry(function(s)
				local size = iconSize + (selectedIcon - iconSize) * s
				return UDim2.fromOffset(size, size)
			end),
			Image = if icon then icon.Image else tab.Icon,
			ImageRectOffset = if icon then icon.Offset else Vector2.zero,
			ImageRectSize = if icon then icon.Size else Vector2.zero,
			ImageTransparency = if enabled then 0 else 0.5,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 8,
		}),
		Label = c("TextLabel", {
			Visible = not iconOnly,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = geometry(function(s)
				return UDim2.new(
					0.5,
					0,
					1,
					-(if compact then N.CompactLabelBottom else N.LabelBottom) + N.SelectedLabelDrop * s
				)
			end),
			Size = UDim2.new(1, -T.Shape.StrokeTab * 2, 0, N.LabelHeight),
			Font = if tightLabel then T.Type.CompactLabel else T.Type.Display,
			Text = if tab.Id == "SplashScreen" then "PLAY" else tab.Label,
			TextSize = state(function(s)
				return if tightLabel then T.Type.Minimum else T.Type.Body + (N.SelectedLabel - T.Type.Body) * s
			end),
			TextColor3 = state(function(s)
				return (if enabled then C.Ink else C.InkSoft):Lerp(C.Surface, s)
			end),
			ZIndex = 8,
		}, {
			Outline = c("UIStroke", {
				Color = C.Ink,
				Thickness = T.Type.Outline,
				Transparency = state(function(s)
					return 1 - s
				end),
			}),
		}),
		-- Decorative emphasis, never a notification or reward indicator.
		Accent = if not compact
			then c("CanvasGroup", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -N.AccentInset, 0, -N.SelectedGrowth / 2),
				Size = UDim2.fromOffset(N.AccentSize * 2, N.AccentSize * 2),
				GroupTransparency = state(function(s)
					return 1 - s
				end),
				ZIndex = 9,
			}, {
				Long = c("Frame", {
					BackgroundColor3 = C.Yellow,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.4, 0.6),
					Size = UDim2.fromOffset(N.RayWidth, N.RayHeight),
					Rotation = N.RayAngle,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.StrokeInner) }),
					Outline = c("UIStroke", { Color = C.YellowLip, Thickness = T.Shape.StrokeInner }),
				}),
				Short = c("Frame", {
					BackgroundColor3 = C.Yellow,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.65, 0.68),
					Size = UDim2.fromOffset(N.RayWidth, N.RayHeight * 0.7),
					Rotation = N.RayAngle * 2,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.StrokeInner) }),
					Outline = c("UIStroke", { Color = C.YellowLip, Thickness = T.Shape.StrokeInner }),
				}),
			})
			else nil,
	})
end

return function(props)
	local tabs = table.clone(props.Tabs)
	table.sort(tabs, function(a, b)
		return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
	end)
	local count = #tabs
	local widths, required = {}, 0
	for index, tab in tabs do
		local label = if tab.Id == "SplashScreen" then "PLAY" else tab.Label
		local width = if props.IconOnly
			then T.Layout.MinTarget
			elseif props.Compact then math.max(
				T.Layout.MinTarget,
				TextService:GetTextSize(label, T.Type.Minimum, T.Type.CompactLabel, Vector2.new(10000, N.LabelHeight)).X
					+ N.CompactTextPadding
			)
			else props.Width / count
		widths[index] = width
		required += width
	end
	local remaining = (props.Width - required) / math.max(count, 1)
	local tight = false
	for index = 1, count do
		if widths[index] + remaining < N.CompactLabelWidth then
			tight = true
		end
	end

	-- LB/RB step through the tabs while the owner says this rail has input (no
	-- modal above it, never during combat); sunk so equip binds do not also fire.
	local cycleEnabled = props.CycleEnabled == true
	local ids, enabledIds = {}, {}
	for _, tab in tabs do
		table.insert(ids, tab.Id)
		enabledIds[tab.Id] = tab.Enabled ~= false
	end
	local latest = React.useRef(nil :: any)
	latest.current = { ids = ids, enabled = enabledIds, current = props.CurrentPage, navigate = props.OnNavigate }
	React.useEffect(function()
		if not cycleEnabled then
			return
		end
		ContextActionService:BindActionAtPriority(CYCLE_ACTION, function(_, inputState, input)
			if UserInputService:GetFocusedTextBox() ~= nil then
				return Enum.ContextActionResult.Pass
			end
			if inputState == Enum.UserInputState.Begin then
				local state = latest.current
				local step = if input.KeyCode == HINTS.TabPrevious.Gamepad then -1 else 1
				local nextId = InputHintModel.cycle(state.ids, state.enabled, state.current, step)
				if nextId ~= state.current then
					state.navigate(nextId)
				end
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 1, HINTS.TabPrevious.Gamepad, HINTS.TabNext.Gamepad)
		return function()
			ContextActionService:UnbindAction(CYCLE_ACTION)
		end
	end, { cycleEnabled })
	local hintNative = function(x: number)
		return {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			ZIndex = 12,
		}
	end
	local children = {
		-- Gamepad only: the shoulder glyphs straddle the rail's rounded ends.
		PreviousHint = if cycleEnabled
			then c(InputHint.Component, { Binding = HINTS.TabPrevious, Native = hintNative(0) })
			else nil,
		NextHint = if cycleEnabled
			then c(InputHint.Component, { Binding = HINTS.TabNext, Native = hintNative(1) })
			else nil,
		-- Star = if not props.Compact
		-- 	then c(Icon, {
		-- 		Name = "Star",
		-- 		Color = C.Yellow,
		-- 		Native = {
		-- 			AnchorPoint = Vector2.new(0.5, 0.5),
		-- 			Position = UDim2.fromOffset(0, N.RailInset),
		-- 			Size = UDim2.fromOffset(N.AccentSize, N.AccentSize),
		-- 			Rotation = T.Shape.TiltBadge,
		-- 			ZIndex = 6,
		-- 		},
		-- 	})
		-- 	else nil,
		Rail = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, N.RailInset),
			Size = UDim2.new(1, 0, 1, -N.RailInset * 2),
		}, {
			Surface = c(CandySurface, {
				Color = C.Surface,
				LipColor = C.WellLine,
				StrokeColor = N.Rim,
			}),
		}),
	}
	local left = 0
	for index, tab in tabs do
		local width = widths[index] + remaining
		children[tab.Id] = c(NavigationTab, {
			Tab = tab,
			Left = left,
			Width = width,
			Tight = tight,
			Compact = props.Compact,
			IconOnly = props.IconOnly,
			Selected = tab.Id == props.CurrentPage,
			OnNavigate = props.OnNavigate,
		})
		left += width
		if index < count then
			children["Divider" .. index] = c("Frame", {
				BackgroundColor3 = N.Divider,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, left, 0.5, 0),
				Size = UDim2.new(0, N.DividerWidth, N.DividerHeight, 0),
				ZIndex = 2,
			}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
	end
	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		SelectionGroup = true,
	}, children)
end
