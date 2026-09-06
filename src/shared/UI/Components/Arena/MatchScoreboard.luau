-- Custom standings expose the same authoritative scores on keyboard, gamepad and touch.
--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.react)
local Config = require(ReplicatedStorage.Config.Interface.ArenaPresentation)
local Surface = require(script.Parent.Surface)
local Label = require(script.Parent.Label)
local ActionButton = require(script.Parent.ActionButton)
local useSafeArea = require(script.Parent.Parent.Parent.Hooks.useSafeArea)
local Selection = require(script.Parent.Parent.Parent.Services.Selection)
local c = React.createElement

return function(props)
	local safe = useSafeArea(Enum.ScreenInsets.None)
	local closeRef = React.useRef(nil)
	React.useEffect(function()
		if not props.Visible then
			return
		end
		local previous = GuiService.SelectedObject
		local active = true
		if string.find(UserInputService:GetLastInputType().Name, "Gamepad") then
			task.defer(function()
				if active and Selection.isSelectable(closeRef.current) then
					GuiService.SelectedObject = closeRef.current
				end
			end)
		end
		return function()
			active = false
			if GuiService.SelectedObject == closeRef.current then
				GuiService.SelectedObject = if Selection.isSelectable(previous) then previous else nil
			end
		end
	end, { props.Visible })
	if not props.Visible then
		return nil
	end
	local view = props.Snapshot
	local colors = Config.Colors
	local width = math.min(safe.size.X * Config.Scoreboard.WidthScale, Config.Scoreboard.MaxWidthPx)
	local height = safe.size.Y * Config.Scoreboard.HeightScale
	local rows = { Layout = c("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for index, entry in view.entries do
		rows[tostring(entry.userId)] = c(Surface, {
			Color = if entry.isLocal then colors.Raised else colors.Surface,
			Shadow = false,
			StrokeTransparency = if entry.isLocal then 0 else 0.8,
			Native = { Size = UDim2.new(1, -8, 0, Config.Scoreboard.RowPx), LayoutOrder = index },
		}, {
			Rank = c(Label, {
				Text = if view.teamMode then "" else tostring(entry.placement),
				Title = true,
				Size = 25,
				Native = { Size = UDim2.fromScale(0.1, 1) },
			}),
			Name = c(Label, {
				Text = entry.displayName .. (if entry.isLocal then " (YOU)" else ""),
				Size = 24,
				Align = Enum.TextXAlignment.Left,
				Native = { Position = UDim2.fromScale(0.11, 0), Size = UDim2.fromScale(0.49, 1) },
			}),
			Status = c(Label, {
				Text = if not entry.alive
					then "RESPAWNING"
					else if view.teamMode and entry.teamId then string.upper(entry.teamId) else "",
				Color = if entry.teamId == "Red" then colors.Pink else colors.Cyan,
				Size = 17,
				Native = { Position = UDim2.fromScale(0.62, 0), Size = UDim2.fromScale(0.23, 1) },
			}),
			Score = c(Label, {
				Text = tostring(entry.score),
				Title = true,
				Color = colors.Yellow,
				Size = 28,
				Native = { Position = UDim2.fromScale(0.86, 0), Size = UDim2.fromScale(0.14, 1) },
			}),
		})
	end
	return c("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		Active = true,
		BackgroundColor3 = colors.Ink,
		BackgroundTransparency = 0.22,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 80,
	}, {
		Panel = c(Surface, {
			Color = colors.Ink,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(safe.position.X + safe.size.X / 2, safe.position.Y + safe.size.Y / 2),
				Size = UDim2.fromOffset(width, height),
				ZIndex = 81,
				SelectionGroup = true,
			},
		}, {
			Title = c(Label, {
				Text = "SCOREBOARD",
				Title = true,
				Size = 34,
				Align = Enum.TextXAlignment.Left,
				Native = { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -134, 0, 44) },
			}),
			Close = c(ActionButton, {
				ButtonRef = closeRef,
				Text = "BACK",
				TextSize = 22,
				OnActivated = props.OnClose,
				Native = { Position = UDim2.new(1, -106, 0, 8), Size = UDim2.fromOffset(92, 44) },
			}),
			Mode = c(Label, {
				Text = view.title .. "  •  " .. view.clock,
				Color = colors.Muted,
				Size = 18,
				Align = Enum.TextXAlignment.Left,
				Native = { Position = UDim2.fromOffset(16, 57), Size = UDim2.new(1, -128, 0, 25) },
			}),
			ScoreHeading = c(Label, {
				Text = "ELIMS",
				Color = colors.Yellow,
				Title = true,
				Size = 18,
				Native = { Position = UDim2.new(1, -94, 0, 57), Size = UDim2.fromOffset(74, 25) },
			}),
			List = c("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(16, 92),
				Size = UDim2.new(1, -32, 1, -108),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = colors.Cyan,
				ZIndex = 3,
			}, rows),
		}),
	})
end
