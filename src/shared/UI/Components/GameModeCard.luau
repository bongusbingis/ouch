--!strict
-- A candy ballot card. The vote snapshot and activation contract stay with the caller.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local CandyPanel = require(script.Parent.CandyPanel)
local PuffyButton = require(script.Parent.PuffyButton)
local Well = require(script.Parent.Well)
local VoteModel = require(script.Parent.Parent.Models.GameModeVoteViewModel)
local T = require(script.Parent.Parent.Tokens)

local c, C, S, F = React.createElement, T.Colors, T.Shape, T.Type

export type Mode = {
	Id: string,
	Title: string,
	Description: string,
	ThumbnailId: string,
	SortOrder: number,
	VoteCount: number,
	Selected: boolean,
}

export type Props = {
	Mode: Mode,
	Enabled: boolean,
	OnVote: (string) -> (),
	ButtonRef: any?,
	Portrait: boolean?,
	Compact: boolean?,
	CardHeight: number?,
}

local accents: { [string]: Color3 } = {
	FFA = C.Cyan,
	TDM = C.Grape,
	Infection = C.Lime,
}

return function(props: Props)
	local mode = props.Mode
	local portrait = props.Portrait == true
	local compact = props.Compact == true or portrait
	local accent = accents[mode.Id] or C.Yellow
	local shortName = if mode.Id == "Infection" then "INFECT" else string.upper(mode.Id)
	local cardHeight = props.CardHeight or 350
	local wellTop = if portrait then 118 else if compact then 112 else 152
	local wellBottom = if compact then 70 else 88
	local actionHeight = if compact then 48 else 56
	local inset = if compact then 14 else 20
	local art = mode.ThumbnailId ~= nil and mode.ThumbnailId ~= ""

	return c(CandyPanel, {
		Native = {
			BackgroundTransparency = 1,
			LayoutOrder = mode.SortOrder,
			Size = if portrait then UDim2.new(0.96, 0, 0, cardHeight) else UDim2.fromScale(0.30, 0.95),
		},
		Tilt = S.TiltPanel,
	}, {
		Accent = c("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(inset, if compact then 14 else 20),
			Size = UDim2.fromOffset(if compact then 44 else 54, if compact then 7 else 9),
			ZIndex = 5,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		Title = c("TextLabel", {
			BackgroundTransparency = 1,
			Font = F.Display,
			Position = UDim2.fromOffset(inset, if compact then 28 else 40),
			Size = UDim2.new(1, -inset * 2, 0, if compact then 34 else 40),
			Text = mode.Title,
			TextColor3 = C.Ink,
			TextSize = if compact then F.TileLabel else F.Section,
			-- Long names (TEAM DEATHMATCH) shrink to fit the card down to the menu floor
			-- instead of truncating.
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
		}, {
			Fit = c("UITextSizeConstraint", {
				MaxTextSize = if compact then F.TileLabel else F.Section,
				MinTextSize = F.Minimum,
			}),
		}),
		Description = c("TextLabel", {
			BackgroundTransparency = 1,
			Font = F.Label,
			Position = UDim2.fromOffset(inset, if compact then 62 else 80),
			-- Room for three wrapped lines at the 18 px floor so no description clips mid-sentence.
			Size = UDim2.new(1, -inset * 2, 0, if portrait then 52 else if compact then 44 else 66),
			Text = if compact
				then string.match(mode.Description, "^[^.]+[.]?") or mode.Description
				else mode.Description,
			TextColor3 = C.InkSoft,
			TextSize = F.Minimum,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 5,
		}),
		Artwork = c(Well, {
			Candy = true,
			Native = {
				Position = UDim2.fromOffset(inset, wellTop),
				Size = UDim2.new(1, -inset * 2, 1, -(wellTop + wellBottom)),
				ZIndex = 5,
			},
		}, {
			Field = c("Frame", {
				BackgroundColor3 = accent:Lerp(C.Surface, 0.48),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Position = UDim2.fromOffset(7, 7),
				Size = UDim2.new(1, -14, 1, -14),
				ZIndex = 6,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, S.RadiusCard - 4) }),
				Circle = c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = C.Surface,
					BackgroundTransparency = 0.48,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.76, 0.42),
					Size = UDim2.fromOffset(if compact then 130 else 200, if compact then 130 else 200),
					ZIndex = 7,
				}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
				ShortName = c("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Font = F.Display,
					Position = UDim2.fromScale(0.5, 0.54),
					Size = UDim2.new(1, -20, 0, if compact then 52 else 76),
					Text = shortName,
					TextColor3 = C.Ink,
					TextSize = if compact then 48 else 70,
					TextScaled = true,
					ZIndex = 8,
				}, {
					Fit = c("UITextSizeConstraint", {
						MaxTextSize = if compact then 48 else 70,
						MinTextSize = F.Minimum,
					}),
				}),
				Art = if art
					then c("ImageLabel", {
						BackgroundTransparency = 1,
						Image = mode.ThumbnailId,
						ScaleType = Enum.ScaleType.Crop,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 9,
					})
					else nil,
				Count = c("Frame", {
					BackgroundColor3 = C.SurfaceWarm,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(9, 9),
					Size = UDim2.fromOffset(if compact then 92 else 112, 30),
					ZIndex = 10,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Outline = c("UIStroke", { Color = C.Ink, Thickness = S.StrokeInner }),
					Label = c("TextLabel", {
						BackgroundTransparency = 1,
						Font = F.Label,
						Size = UDim2.fromScale(1, 1),
						Text = VoteModel.formatVoteCount(mode.VoteCount),
						TextColor3 = C.Ink,
						TextSize = F.Minimum,
						ZIndex = 11,
					}),
				}),
			}),
		}),
		-- Top-right of the card, level with the accent bar, so it never shares the
		-- artwork well with the vote-count pill.
		Selection = if mode.Selected and not compact
			then c("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = C.Yellow,
				BorderSizePixel = 0,
				Position = UDim2.new(1, -inset, 0, 8),
				Size = UDim2.fromOffset(118, 30),
				Rotation = -3,
				ZIndex = 10,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Outline = c("UIStroke", { Color = C.Ink, Thickness = S.StrokeInner }),
				Label = c("TextLabel", {
					BackgroundTransparency = 1,
					Font = F.Label,
					Size = UDim2.fromScale(1, 1),
					Text = "YOUR PICK",
					TextColor3 = C.Ink,
					TextSize = F.Minimum,
					ZIndex = 11,
				}),
			})
			else nil,
		VoteButton = c(PuffyButton, {
			ButtonRef = props.ButtonRef,
			Enabled = props.Enabled,
			EntranceDelay = (mode.SortOrder - 1) * 0.025,
			FocusHint = true,
			Color = if mode.Selected then C.Yellow else C.Pink,
			LipColor = if mode.Selected then C.YellowLip else C.PinkLip,
			Text = if mode.Selected then "VOTED" else "VOTE",
			TextColor = if mode.Selected then C.Ink else C.Surface,
			TextSize = if compact then F.TileLabel else F.Tab,
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, if compact then -14 else -20),
				Size = UDim2.new(1, -inset * 2, 0, actionHeight),
				ZIndex = 7,
			},
			OnActivated = function()
				props.OnVote(mode.Id)
			end,
		}),
	})
end
