-- Compact objective, clock and score hierarchy with a device-independent custom standings entry point.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Config =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("ArenaPresentation"))
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Surface = require(script.Parent.Arena.Surface)
local Label = require(script.Parent.Arena.Label)
local Scoreboard = require(script.Parent.Arena.MatchScoreboard)
local StandingsStrip = require(script.Parent.Arena.StandingsStrip)
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
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
	-- The strip sits beside the band when the safe area leaves room for it at
	-- the right edge; on narrow phones it tucks under the band instead.
	local stripWidth = if short then Config.Standings.ShortWidthPx else Config.Standings.WidthPx
	local bandRight = safe.position.X + safe.size.X / 2 + width / 2
	local stripLeft = safe.position.X + safe.size.X - layout.EdgePx - stripWidth
	local beside = stripLeft - bandRight >= Config.Standings.GapPx
	local stripTop = if beside then top else top + height + Config.Standings.GapPx
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = props.Visible }, {
		HUD = c(Surface, {
			Color = colors.Cyan,
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
				Color = colors.White,
				Align = Enum.TextXAlignment.Left,
				Native = { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -104, 0, 22) },
			}),
			Clock = c(Surface, {
				Color = if view.remaining <= layout.UrgentSeconds then colors.Pink else colors.PanelRaised,
				Radius = UIConfig.Radius.Tile,
				Shadow = false,
				Native = { Position = UDim2.new(1, -88, 0, 8), Size = UDim2.fromOffset(76, if short then 30 else 34) },
			}, { Text = c(Label, { Text = view.clock, Title = true, Size = 29 }) }),
			Scores = if view.teamMode
				then c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(12, 28),
					Size = UDim2.new(1, -108, 1, -31),
				}, {
					Red = c(Surface, {
						Color = colors.Pink,
						Radius = UIConfig.Radius.Tile,
						Shadow = false,
						Native = { Size = UDim2.fromScale(0.42, 1) },
					}, {
						Text = c(Label, {
							Text = `RED  {view.redScore}`,
							Title = true,
							Size = 27,
							Native = { Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -8, 1, 0) },
						}),
					}),
					Blue = c(Surface, {
						Color = colors.Cyan,
						Radius = UIConfig.Radius.Tile,
						Shadow = false,
						Native = { Position = UDim2.fromScale(0.46, 0), Size = UDim2.fromScale(0.54, 1) },
					}, {
						Text = c(Label, {
							Text = `BLUE  {view.blueScore}`,
							Title = true,
							Size = 27,
							Native = { Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -8, 1, 0) },
						}),
					}),
				})
				else c(Label, {
					Text = `{view.score} ELIMS` .. (if view.placement then `  •  #{view.placement}` else ""),
					Title = true,
					Size = 28,
					Align = Enum.TextXAlignment.Left,
					Native = { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -108, 1, -31) },
				}),
			Team = if view.teamMode and view.teamId
				then c(Label, {
					Text = `YOU: {string.upper(view.teamId)}`,
					Size = 13,
					Native = {
						Position = UDim2.new(1, -92, 0, if short then 40 else 44),
						Size = UDim2.fromOffset(84, 22),
					},
				})
				else nil,
			Respawn = if view.respawn
				then c(Surface, {
					Color = colors.Pink,
					Radius = UIConfig.Radius.Control,
					Native = {
						Position = UDim2.new(0.06, 0, 1, 8),
						Size = UDim2.new(0.88, 0, 0, layout.RespawnHeightPx),
					},
				}, {
					Text = c(Label, {
						Text = view.respawn,
						Title = true,
						Size = 23,
						Color = colors.White,
						Native = { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0) },
					}),
				})
				else nil,
		}),
		Start = if view.starting
			then c(Surface, {
				Color = colors.Cyan,
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
					Color = colors.White,
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
		Standings = if not view.starting
			then c(StandingsStrip, {
				Snapshot = view,
				Short = short,
				Position = UDim2.fromOffset(safe.position.X + safe.size.X - layout.EdgePx, stripTop),
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
