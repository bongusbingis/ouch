--!strict
-- Compact candy score band; the complete standings remain one tap away.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local Config = require(RS.Config.Interface.ArenaPresentation)
local T = require(script.Parent.Parent.Tokens)
local useArenaHUDLayout = require(script.Parent.Parent.Hooks.useArenaHUDLayout)
local Surface = require(script.Parent.Arena.HUDSurface)
local Label = require(script.Parent.Arena.HUDLabel)
local Scoreboard = require(script.Parent.Arena.MatchScoreboard)
local StandingsStrip = require(script.Parent.Arena.StandingsStrip)
local ScoresButton = require(script.Parent.Arena.ScoresButton)
local c, C = React.createElement, T.Colors

local function teamPanels(view)
	local panels = {}
	local count = math.max(#view.teams, 1)
	for index, team in view.teams do
		local color = T.ArenaHUD.Colors[team.accent] or C.Cyan
		local fraction = if view.teamScoreMax > 0 then math.clamp(team.score / view.teamScoreMax, 0, 1) else 0
		panels[team.id] = c("Frame", {
			BackgroundColor3 = C.Well,
			BorderSizePixel = 0,
			Position = UDim2.fromScale((index - 1) / count, 0),
			Size = UDim2.new(1 / count, -8, 1, 0),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Name = c(Label, {
				Text = team.label,
				Size = 12,
				Align = Enum.TextXAlignment.Left,
				Native = { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -46, 1, -5) },
			}),
			Score = c(Label, {
				Text = tostring(team.score),
				Title = true,
				Size = 24,
				Native = { Position = UDim2.new(1, -38, 0, 0), Size = UDim2.new(0, 32, 1, -5) },
			}),
			Track = c("Frame", {
				BackgroundColor3 = color,
				BackgroundTransparency = 0.65,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 8, 1, -5),
				Size = UDim2.new(1, -16, 0, 3),
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Fill = c("Frame", {
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(fraction, 1),
				}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
			}),
		})
	end
	return panels
end

return function(props)
	local geometry = useArenaHUDLayout()
	local rect = geometry.hud
	local view = props.Snapshot
	local short = geometry.compact
	local top, width, height = rect.position.Y, rect.size.X, rect.size.Y
	local centerX = rect.position.X + width / 2
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = props.Visible }, {
		HUD = c(Surface, {
			Native = {
				Position = UDim2.fromOffset(rect.position.X, top),
				Size = UDim2.fromOffset(width, height),
				ZIndex = 10,
			},
		}, {
			Objective = c(Label, {
				Text = view.title .. (if view.target > 0 then ` · FIRST TO {view.target}` else " · SURVIVE"),
				Size = if short then 13 else 16,
				Color = C.InkSoft,
				Align = Enum.TextXAlignment.Left,
				Native = { Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -88, 0, 18) },
			}),
			Clock = c(Label, {
				Text = view.clock,
				Title = true,
				Size = if short then 26 else 30,
				Color = if view.remaining <= Config.HUD.UrgentSeconds then C.PinkLip else C.Ink,
				Native = {
					Position = UDim2.new(1, -78, 0, 4),
					Size = UDim2.new(0, 68, 1, if view.teamMode then -28 else -14),
				},
			}),
			Team = if view.teamMode and view.teamId
				then c(Label, {
					Text = `YOU: {string.upper(view.teamId)}`,
					Size = 11,
					Color = C.InkSoft,
					Native = { Position = UDim2.new(1, -78, 1, -23), Size = UDim2.fromOffset(68, 16) },
				})
				else nil,
			Scores = if view.teamMode
				then c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(8, 21),
					Size = UDim2.new(1, -90, 1, -29),
				}, teamPanels(view))
				else c(Label, {
					Text = `{view.score} {view.scoreLabel}` .. (if view.placement then ` · #{view.placement}` else ""),
					Title = true,
					Size = if short then 20 else 25,
					Align = Enum.TextXAlignment.Left,
					Native = { Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -98, 1, -30) },
				}),
		}),
		Respawn = if view.respawn
			then c(Surface, {
				Color = C.Pink,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromOffset(centerX, top + height + 12),
					Size = UDim2.fromOffset(math.min(width, 280), 44),
					ZIndex = 12,
				},
			}, {
				Text = c(
					Label,
					{ Text = view.respawn, Title = true, Size = 20, Native = { Size = UDim2.new(1, 0, 1, -6) } }
				),
			})
			else nil,
		Start = if view.starting
			then c(Surface, {
				Color = C.Yellow,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromOffset(centerX, top + height + 12),
					Size = UDim2.fromOffset(width, 70),
					ZIndex = 12,
				},
			}, {
				Title = c(Label, {
					Text = `BRAWL IN {view.remaining}`,
					Title = true,
					Size = 26,
					Native = { Size = UDim2.new(1, 0, 0, 36) },
				}),
				Objective = c(Label, {
					Text = view.objective,
					Size = 15,
					Native = { Position = UDim2.fromOffset(8, 36), Size = UDim2.new(1, -16, 0, 24) },
				}),
			})
			else nil,
		ScoresButton = if not view.starting
			then c(ScoresButton, {
				Rect = geometry.scores,
				OnActivated = props.OnToggleScores,
				Visible = props.Visible,
			})
			else nil,
		Standings = if not short
				and not view.starting
				and geometry.menu.position.X + geometry.menu.size.X - Config.Standings.WidthPx
					>= rect.position.X + width + T.ArenaHUD.Gap
			then c(StandingsStrip, {
				Snapshot = view,
				Short = false,
				Position = UDim2.fromOffset(
					geometry.menu.position.X + geometry.menu.size.X,
					geometry.menu.position.Y + 56
				),
				OnActivated = props.OnToggleScores,
				ZIndex = 10,
			})
			else nil,
		Scoreboard = c(
			Scoreboard,
			{ Visible = props.Visible and view.scoreboardOpen, Snapshot = view, OnClose = props.OnCloseScores }
		),
	})
end
