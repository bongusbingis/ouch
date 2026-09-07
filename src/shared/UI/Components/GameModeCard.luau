-- Name: GameModeCard.luau
-- Author: Jack C.
-- Description: One selectable game mode card on the vote ballot, showing its art, name, live vote count, and selection state.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local CelebrationAvatar = require(script.Parent.Arena.CelebrationAvatar)
local ResponsiveText = require(script.Parent.ResponsiveText)
local GameModeVoteViewModel = require(script.Parent.Parent.Models.GameModeVoteViewModel)
local TextMetrics = require(script.Parent.Parent.TextMetrics)

local c = React.createElement
local REFERENCE_VIEWPORT = Vector2.new(1890, 1200)
local MODES_HOLDER_BOUNDS = TextMetrics.scaleBounds(REFERENCE_VIEWPORT, Vector2.new(0.944456, 0.562031))
local CARD_BOUNDS =
	TextMetrics.fitAspect(TextMetrics.scaleBounds(MODES_HOLDER_BOUNDS, Vector2.new(0.345678, 0.931169)), 0.87)
local TITLE_BOUNDS = TextMetrics.scaleBounds(CARD_BOUNDS, Vector2.new(0.967519, 0.104411)) - Vector2.new(2, 2)
local THUMBNAIL_BOUNDS =
	TextMetrics.fitAspect(TextMetrics.scaleBounds(CARD_BOUNDS, Vector2.new(0.822196, 0.661131)), 1.7)
local VOTE_COUNT_BOUNDS = TextMetrics.scaleBounds(THUMBNAIL_BOUNDS, Vector2.new(0.613327, 0.160588)) - Vector2.new(2, 2)
local VOTE_COUNT_STROKE = TextMetrics.scaledTextStroke(3.8, "000", Enum.Font.Highway, VOTE_COUNT_BOUNDS)
local CHECKMARK_SCALE = Vector2.new(100 / CARD_BOUNDS.X, 100 / CARD_BOUNDS.Y)
local titleStrokes: { [string]: number } = {}

local function titleStroke(title: string): number
	local thickness = titleStrokes[title]
	if thickness == nil then
		thickness = TextMetrics.scaledTextStroke(3.8, title, Enum.Font.LuckiestGuy, TITLE_BOUNDS)
		titleStrokes[title] = thickness
	end
	return thickness
end

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
}

return function(props: Props)
	local mode = props.Mode
	local portrait = props.Portrait == true
	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = mode.SortOrder,
		Position = UDim2.fromScale(0.347443, 0.0847785),
		Size = if portrait
			then UDim2.new(0.96, 0, 0, UIConfig.Layout.GameMode.CardHeightPx)
			else UDim2.fromScale(0.345678, 0.931169),
	}, {
		Background = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = "rbxassetid://136021539696619",
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromScale(1, 1),
			SliceCenter = Rect.new(224, 202, 770, 474),
			SliceScale = 0.2,
		}),
		UIAspectRatioConstraint = if portrait then nil else c("UIAspectRatioConstraint", { AspectRatio = 0.87 }),
		Title = c(ResponsiveText, {
			HostName = "Title",
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 46,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/LuckiestGuy.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.499634, if portrait then 0.035 else 0.0521707),
				Size = UDim2.fromScale(if portrait then 0.9 else 0.88, if portrait then 0.18 else 0.104411),
				Text = mode.Title,
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 2,
			},
		}, {
			UIStroke = c("UIStroke", {
				Color = Color3.fromRGB(77, 77, 77),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = titleStroke(mode.Title),
			}),
		}),
		Line = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderColor3 = Color3.new(),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, if portrait then 0.22 else 0.147617),
			Size = if portrait then UDim2.new(0.88, 0, 0, 2) else UDim2.fromScale(0.817, 0.008),
			ZIndex = 2,
		}),
		Thumbnail = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = UIConfig.ProgressionStyle.Surface,
			Image = mode.ThumbnailId,
			Position = UDim2.fromScale(if portrait then 0.23 else 0.496345, if portrait then 0.58 else 0.57),
			Size = UDim2.fromScale(if portrait then 0.38 else 0.822196, if portrait then 0.58 else 0.661131),
			ZIndex = 2,
		}, {
			Art = if mode.ThumbnailId == ""
				then c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0, 0.1),
					Size = UDim2.fromScale(1, 0.9),
					ZIndex = 3,
				}, {
					First = c(CelebrationAvatar, {
						Static = true,
						ColorId = if mode.Id == "TDM" then "CharacterColorRed" else nil,
						Native = { Position = UDim2.fromScale(0.04, 0), Size = UDim2.fromScale(0.6, 1) },
						ZIndex = 3,
					}),
					Second = c(CelebrationAvatar, {
						Static = true,
						ColorId = "CharacterColorBlue",
						Native = { Position = UDim2.fromScale(0.43, 0.05), Size = UDim2.fromScale(0.53, 0.9) },
						ZIndex = 3,
					}),
				})
				else nil,
			UIAspectRatioConstraint = c("UIAspectRatioConstraint", {
				AspectRatio = 1.7,
			}),
			UICorner = c("UICorner"),
			UIStroke = c("UIStroke", {
				Color = Color3.new(1, 1, 1),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.02,
			}),
			VoteCount = c(ResponsiveText, {
				HostName = "VoteCount",
				MeasurementFont = Enum.Font.Highway,
				MaxTextSize = 22,
				Native = {
					AnchorPoint = Vector2.zero,
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
					Position = UDim2.fromOffset(8, 6),
					Size = UDim2.new(1, -16, 0, 24),
					Text = GameModeVoteViewModel.formatVoteCount(mode.VoteCount),
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 3,
				},
			}, {
				UIStroke = c("UIStroke", {
					Color = Color3.fromRGB(77, 77, 77),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = VOTE_COUNT_STROKE,
				}),
			}),
		}),
		VoteButton = c(AnimatedButton, {
			SelectionRadius = UDim.new(1, 0),
			ButtonRef = props.ButtonRef,
			Enabled = props.Enabled,
			EntranceDelay = (mode.SortOrder - 1) * 0.025,
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Image = "rbxassetid://94748581468730",
				LayoutOrder = 2,
				Position = UDim2.fromScale(if portrait then 0.72 else 0.5, if portrait then 0.92 else 0.95),
				ScaleType = Enum.ScaleType.Slice,
				Size = if portrait then UDim2.new(0.42, 0, 0, 48) else UDim2.fromScale(0.651625, 0.156114),
				SliceCenter = Rect.new(198, 228, 841, 468),
				SliceScale = 0.2,
				ZIndex = 2,
			},
			OnActivated = function()
				props.OnVote(mode.Id)
			end,
		}, {
			TextLabel = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 32,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.736491, 0.6712),
					Text = if mode.Selected then "VOTED" else "VOTE",
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 3,
				},
			}),
			UIAspectRatioConstraint = c("UIAspectRatioConstraint", {
				AspectRatio = 3.48,
			}),
		}),
		Description = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.8,
			Position = UDim2.fromScale(if portrait then 0.72 else 0.496873, if portrait then 0.31 else 0.17),
			Size = UDim2.fromScale(if portrait then 0.5 else 0.850373, if portrait then 0.28 else 0.18),
			ZIndex = 2,
		}, {
			UICorner = c("UICorner", {
				BottomLeftRadius = UDim.new(0.25, 0),
				BottomRightRadius = UDim.new(0.25, 0),
				TopLeftRadius = UDim.new(0.25, 0),
				TopRightRadius = UDim.new(0.25, 0),
			}),
			TextLabel = c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				Wrapped = true,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSansBold,
					Position = UDim2.fromScale(0.5, 0.511),
					Size = UDim2.fromScale(0.927564, 0.9),
					Text = if props.Compact
						then string.match(mode.Description, "^[^.]+[.]?") or mode.Description
						else mode.Description,
					TextColor3 = Color3.new(1, 1, 1),
					TextWrapped = true,
					ZIndex = 3,
				},
			}),
		}),
		Checkmark = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = "rbxassetid://72382658",
			Position = UDim2.fromScale(if portrait then 0.85 else 0.863158, if portrait then -0.06 else -0.0652306),
			Size = if portrait then UDim2.fromOffset(52, 52) else UDim2.fromScale(CHECKMARK_SCALE.X, CHECKMARK_SCALE.Y),
			Visible = mode.Selected,
			ZIndex = 6,
		}, {
			UIAspectRatioConstraint = c("UIAspectRatioConstraint", {
				AspectRatio = 1,
			}),
		}),
	})
end
