-- Compact objective, clock and score hierarchy with a device-independent custom standings entry point.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Config = require(ReplicatedStorage.Config.Interface.ArenaPresentation)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Surface = require(script.Parent.Arena.Surface)
local Label = require(script.Parent.Arena.Label)
local ActionButton = require(script.Parent.Arena.ActionButton)
local Scoreboard = require(script.Parent.Arena.MatchScoreboard)
local c = React.createElement
local colors = Config.Colors
local layout = Config.HUD

return function(props)
	local safe = useSafeArea(Enum.ScreenInsets.None)
	local view = props.Snapshot
	local width = math.min(layout.WidthPx, safe.size.X - layout.EdgePx * 2)
	local top = math.max(safe.position.Y + layout.TopPx, 44)
	local short = safe.size.Y < Config.Results.ShortHeightPx
	local height = if short then 64 else 78
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = props.Visible }, {
		HUD = c(Surface, {
			Color = colors.Ink,
			Transparency = 0.1,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(safe.position.X + safe.size.X / 2, top),
				Size = UDim2.fromOffset(width, height),
				ZIndex = 10,
			},
		}, {
			Objective = c(Label, {
				Text = view.title .. " • " .. (if view.target > 0 then `FIRST TO {view.target} ELIMS` else "SURVIVE"),
				Size = if short then 14 else 17,
				Color = colors.Muted,
				Align = Enum.TextXAlignment.Left,
				Native = { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -172, 0, 22) },
			}),
			Clock = c(Label, {
				Text = view.clock,
				Title = true,
				Size = 29,
				Color = if view.remaining <= layout.UrgentSeconds then colors.Pink else colors.Yellow,
				Native = { Position = UDim2.new(1, -164, 0, 4), Size = UDim2.fromOffset(70, 30) },
			}),
			Scores = if view.teamMode
				then c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(12, 28),
					Size = UDim2.new(1, -192, 1, -31),
				}, {
					Red = c(Label, {
						Text = `RED  {view.redScore}`,
						Title = true,
						Color = colors.Pink,
						Size = 27,
						Align = Enum.TextXAlignment.Left,
						Native = { Size = UDim2.fromScale(0.42, 1) },
					}),
					Blue = c(Label, {
						Text = `BLUE  {view.blueScore}`,
						Title = true,
						Color = colors.Cyan,
						Size = 27,
						Align = Enum.TextXAlignment.Left,
						Native = { Position = UDim2.fromScale(0.46, 0), Size = UDim2.fromScale(0.54, 1) },
					}),
				})
				else c(Label, {
					Text = `{view.score} ELIMS` .. (if view.placement then `  •  #{view.placement}` else ""),
					Title = true,
					Size = 28,
					Align = Enum.TextXAlignment.Left,
					Native = { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -192, 1, -31) },
				}),
			Team = if view.teamMode and view.teamId
				then c(Label, {
					Text = `YOU: {string.upper(view.teamId)}`,
					Size = 14,
					Native = { Position = UDim2.new(1, -191, 0, 37), Size = UDim2.fromOffset(102, 24) },
				})
				else nil,
			Standings = c(ActionButton, {
				Enabled = not view.starting,
				Text = "SCORES",
				TextSize = 15,
				Color = colors.Raised,
				Native = { Position = UDim2.new(1, -80, 0, 9), Size = UDim2.fromOffset(68, 44) },
				OnActivated = props.OnToggleScores,
			}),
			Respawn = if view.respawn
				then c(Surface, {
					Color = colors.Ink,
					Native = {
						Position = UDim2.new(0.06, 0, 1, 8),
						Size = UDim2.new(0.88, 0, 0, layout.RespawnHeightPx),
					},
				}, {
					Text = c(Label, {
						Text = view.respawn,
						Title = true,
						Size = 23,
						Color = colors.Yellow,
						Native = { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0) },
					}),
				})
				else nil,
		}),
		Start = if view.starting
			then c(Surface, {
				Color = colors.Surface,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromOffset(safe.position.X + safe.size.X / 2, top + height + 12),
					Size = UDim2.fromOffset(width * 0.84, 76),
					ZIndex = 12,
				},
			}, {
				Title = c(Label, {
					Text = `BRAWL IN {view.remaining}`,
					Title = true,
					Color = colors.Yellow,
					Size = 32,
					Native = { Size = UDim2.new(1, 0, 0, 42) },
				}),
				Objective = c(Label, {
					Text = view.objective,
					Size = 18,
					Native = { Position = UDim2.fromOffset(8, 42), Size = UDim2.new(1, -16, 0, 28) },
				}),
			})
			else nil,
		Scoreboard = c(
			Scoreboard,
			{ Visible = props.Visible and view.scoreboardOpen, Snapshot = view, OnClose = props.OnCloseScores }
		),
	})
end
