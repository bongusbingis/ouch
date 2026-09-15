-- Name: SplashdownHUD.luau
-- Author: Jack C.
-- Description: Splashdown race HUD with a dedicated candy cinematic intro, a race band with clock and checkpoints, countdown and GO, finish banner, round results, and shared standings and scoreboard.
-- Created: 2026-09-14

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Config =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("ArenaPresentation"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local SplashdownIntro = require(script.Parent.SplashdownIntro)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Surface = require(script.Parent.Arena.Surface)
local Label = require(script.Parent.Arena.Label)
local Scoreboard = require(script.Parent.Arena.MatchScoreboard)
local StandingsStrip = require(script.Parent.Arena.StandingsStrip)

local c = React.createElement
local colors = Config.Colors
local layout = Config.HUD

export type Props = {
	Snapshot: any,
	Match: any,
	Visible: boolean,
	OnToggleScores: (() -> ())?,
	OnCloseScores: (() -> ())?,
}

local function toastRows(toast, rowHeight: number, short: boolean, z: number)
	local children = {
		Layout = c("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index, row in toast.rows do
		local textSize = if short then 13 else 16
		children[`Row{index}`] = c("Frame", {
			BackgroundColor3 = if row.isLocal then colors.Pink else colors.Claimed,
			BackgroundTransparency = if row.isLocal then 0 else 0.35,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, rowHeight),
			ZIndex = z,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Radius.Tile) }),
			Rank = c(Label, {
				Text = tostring(row.placement),
				Title = true,
				Size = textSize + 2,
				Color = if row.placement == 1 then colors.Yellow else colors.White,
				Align = Enum.TextXAlignment.Left,
				Native = { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(34, rowHeight), ZIndex = z + 1 },
			}),
			Name = c(Label, {
				Text = row.name,
				Size = textSize,
				Align = Enum.TextXAlignment.Left,
				Native = { Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -46 - 150, 1, 0), ZIndex = z + 1 },
			}),
			Time = c(Label, {
				Text = row.time,
				Size = textSize,
				Align = Enum.TextXAlignment.Right,
				Native = { Position = UDim2.new(1, -150, 0, 0), Size = UDim2.fromOffset(78, rowHeight), ZIndex = z + 1 },
			}),
			Points = c(Label, {
				Text = `+{row.points}`,
				Title = true,
				Size = textSize + 2,
				Color = colors.Yellow,
				Align = Enum.TextXAlignment.Right,
				Native = { Position = UDim2.new(1, -66, 0, 0), Size = UDim2.fromOffset(56, rowHeight), ZIndex = z + 1 },
			}),
		})
	end
	return children
end

return function(props: Props)
	local safe = useSafeArea(Enum.ScreenInsets.None)
	local view = props.Snapshot
	local match = props.Match
	local width = math.min(layout.WidthPx, safe.size.X - layout.EdgePx * 2)
	local top = math.max(safe.position.Y + layout.TopPx, 44)
	local short = safe.size.Y < Config.Results.ShortHeightPx
	local height = if short then 64 else 78
	local stripWidth = if short then Config.Standings.ShortWidthPx else Config.Standings.WidthPx
	local bandRight = safe.position.X + safe.size.X / 2 + width / 2
	local stripLeft = safe.position.X + safe.size.X - layout.EdgePx - stripWidth
	local beside = stripLeft - bandRight >= Config.Standings.GapPx
	local stripTop = if beside then top else top + height + Config.Standings.GapPx
	local centerX = safe.position.X + safe.size.X / 2
	local toast = view.toast
	local rowHeight = if short then 24 else 30
	local rows = if toast then toastRows(toast, rowHeight, short, 22) else nil
	local toastWidth = math.min(520, safe.size.X - 32)
	local toastHeight = (if short then 96 else 124) + (if toast then #toast.rows * (rowHeight + 3) else 0)
	local progressWidth = width - 108 - 24

	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = props.Visible }, {
		HUD = c(Surface, {
			Color = colors.Cyan,
			Native = {
				Visible = not view.intro,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(centerX, top),
				Size = UDim2.fromOffset(width, height),
				ZIndex = 10,
			},
		}, {
			Round = c(Label, {
				Text = `{view.roundLabel} • {view.title}`,
				Size = if short then 14 else 17,
				Color = colors.White,
				Align = Enum.TextXAlignment.Left,
				Native = { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -104, 0, 22) },
			}),
			Clock = c(Surface, {
				Color = if view.closing then colors.Pink else colors.PanelRaised,
				Radius = UIConfig.Radius.Tile,
				Shadow = false,
				Native = { Position = UDim2.new(1, -88, 0, 8), Size = UDim2.fromOffset(76, if short then 30 else 34) },
			}, { Text = c(Label, { Text = view.clock, Title = true, Size = 26 }) }),
			Checkpoint = c(Label, {
				Text = view.checkpointLabel,
				Title = true,
				Size = if short then 20 else 24,
				Align = Enum.TextXAlignment.Left,
				Native = {
					Position = UDim2.fromOffset(12, if short then 26 else 30),
					Size = UDim2.fromOffset(progressWidth, 28),
				},
			}),
			Track = c("Frame", {
				BackgroundColor3 = colors.Ink,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(12, if short then 54 else 62),
				Size = UDim2.fromOffset(progressWidth, if short then 6 else 8),
				ZIndex = 3,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Fill = c("Frame", {
					BackgroundColor3 = if view.finished then colors.Green else colors.Yellow,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(math.clamp(view.checkpointProgress, 0, 1), 1),
					ZIndex = 4,
				}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
			}),
			Closing = if view.closing
				then c(Label, {
					Text = view.closing,
					Size = 13,
					Color = colors.Pink,
					Align = Enum.TextXAlignment.Right,
					Native = {
						Position = UDim2.new(1, -132, 0, if short then 40 else 44),
						Size = UDim2.fromOffset(124, 22),
					},
				})
				else nil,
		}),
		Countdown = if view.countdown
			then c(Label, {
				Text = view.countdown,
				Title = true,
				Size = if short then 72 else 110,
				Color = if view.countdown == "GO!" then colors.Green else colors.Yellow,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(centerX, safe.position.Y + safe.size.Y * 0.34),
					Size = UDim2.fromOffset(360, if short then 90 else 130),
					ZIndex = 14,
				},
			})
			else nil,
		Finish = if view.finished and view.phase == "Racing"
			then c(Surface, {
				Color = colors.Pink,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromOffset(centerX, top + height + 12),
					Size = UDim2.fromOffset(width * 0.84, if short then 58 else 72),
					ZIndex = 12,
				},
			}, {
				Title = c(Label, {
					Text = view.finishLabel or "FINISHED",
					Title = true,
					Color = colors.White,
					Size = if short then 26 else 32,
					Native = { Size = UDim2.new(1, 0, 0, if short then 34 else 42) },
				}),
				Detail = c(Label, {
					Text = "STAY ON THE DECK WHILE THE ROUND CLOSES",
					Size = if short then 13 else 16,
					Native = {
						Position = UDim2.fromOffset(8, if short then 32 else 42),
						Size = UDim2.new(1, -16, 0, 24),
					},
				}),
			})
			else nil,
		Intro = if view.intro
			then c(SplashdownIntro, {
				CourseId = view.courseId,
				Title = view.title,
				RoundLabel = view.roundLabel,
				EndsAt = view.introEndsAt,
			})
			else nil,
		Toast = if toast
			then c(Surface, {
				Color = colors.Panel,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromOffset(centerX, top + height + 16),
					Size = UDim2.fromOffset(toastWidth, toastHeight),
					ZIndex = 20,
				},
			}, {
				Title = c(Label, {
					Text = toast.title,
					Title = true,
					Size = if short then 22 else 28,
					Color = colors.White,
					Native = {
						Position = UDim2.fromOffset(0, 6),
						Size = UDim2.new(1, 0, 0, if short then 26 else 34),
						ZIndex = 21,
					},
				}),
				Subtitle = c(Label, {
					Text = toast.subtitle,
					Size = if short then 13 else 16,
					Color = colors.Yellow,
					Native = {
						Position = UDim2.fromOffset(0, if short then 30 else 40),
						Size = UDim2.new(1, 0, 0, 20),
						ZIndex = 21,
					},
				}),
				Rows = c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(14, if short then 52 else 64),
					Size = UDim2.new(1, -28, 0, #toast.rows * (rowHeight + 3)),
					ZIndex = 21,
				}, rows),
				Summary = c(Label, {
					Text = toast.summary,
					Title = true,
					Size = if short then 16 else 20,
					Color = colors.Yellow,
					Native = {
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0, 0, 1, -6),
						Size = UDim2.new(1, 0, 0, 28),
						ZIndex = 21,
					},
				}),
			})
			else nil,
		Standings = if not view.intro
				and toast == nil
				and match
			then c(StandingsStrip, {
				Snapshot = match,
				Short = short,
				Position = UDim2.fromOffset(safe.position.X + safe.size.X - layout.EdgePx, stripTop),
				OnActivated = props.OnToggleScores,
				ZIndex = 10,
			})
			else nil,
		Scoreboard = if match
			then c(Scoreboard, {
				Visible = props.Visible and not view.intro and match.scoreboardOpen,
				Snapshot = match,
				OnClose = props.OnCloseScores,
			})
			else nil,
	})
end
