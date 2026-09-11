-- Name: GameModeCard.luau
-- Author: Jack C.
-- Description: One selectable game mode card on the vote ballot: a page-panel card carrying the mode name, its one-line pitch, a static key-art well with the live vote count, and the VOTE action; when the mode has no key art yet the well shows a labelled per-mode placeholder instead of live 3D.
-- Created: 2026-09-10
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Icon = require(script.Parent.Icon)

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local ButtonSurface = require(script.Parent.ButtonSurface)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Well = require(script.Parent.Well)
local GameModeVoteViewModel = require(script.Parent.Parent.Models.GameModeVoteViewModel)
local TextMetrics = require(script.Parent.Parent.TextMetrics)

local c = React.createElement
local Palette = UIConfig.ProgressionStyle
local DISPLAY_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local REFERENCE_VIEWPORT = Vector2.new(1890, 1200)
local MODES_HOLDER_BOUNDS = TextMetrics.scaleBounds(REFERENCE_VIEWPORT, Vector2.new(0.944456, 0.562031))
local CARD_BOUNDS =
	TextMetrics.fitAspect(TextMetrics.scaleBounds(MODES_HOLDER_BOUNDS, Vector2.new(0.345678, 0.931169)), 0.87)
local TITLE_BOUNDS = TextMetrics.scaleBounds(CARD_BOUNDS, Vector2.new(0.967519, 0.104411)) - Vector2.new(2, 2)
local titleStrokes: { [string]: number } = {}

-- Until a mode has key art its well shows a flat, mode-tinted field with the
-- mode's short name, so the two cards read as different at a glance and the
-- stub is obviously a stub.
local PLACEHOLDER: { [string]: { Colors: { Color3 }, Label: string } } = {
	FFA = { Colors = { Palette.Cyan }, Label = "FFA" },
	TDM = { Colors = { Palette.Pink, Palette.Cyan }, Label = "TDM" },
	Infection = { Colors = { Palette.Green }, Label = "INFECTION" },
}

local function titleStroke(title: string): number
	local thickness = titleStrokes[title]
	if thickness == nil then
		thickness = TextMetrics.scaledTextStroke(3.8, title, Enum.Font.LuckiestGuy, TITLE_BOUNDS)
		titleStrokes[title] = thickness
	end
	return thickness
end

local function inkStroke(thickness: number?)
	return c("UIStroke", {
		Color = Palette.Ink,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = thickness or 0.045,
	})
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

local function placeholder(modeId: string, zIndex: number, compact: boolean, portrait: boolean)
	local spec = PLACEHOLDER[modeId] or { Colors = { Palette.Disabled }, Label = string.upper(modeId) }
	local fields = {}
	local count = #spec.Colors
	for index, color in spec.Colors do
		fields[`Field{index}`] = c("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromScale((index - 1) / count, 0),
			Size = UDim2.fromScale(1 / count, 1),
			ZIndex = zIndex,
		})
	end
	fields.Label = c("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		FontFace = DISPLAY_FONT,
		Position = UDim2.fromScale(if compact then 0.76 else 0.5, if portrait then 0.76 else 0.5),
		Size = UDim2.fromScale(if compact then 0.4 else 0.9, if compact then 0.65 else 0.38),
		Text = spec.Label,
		TextColor3 = Palette.White,
		TextScaled = true,
		ZIndex = zIndex + 1,
	}, { Outline = inkStroke(0.06) })
	return c("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = zIndex,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Radius.Tile) }),
		Fields = c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = zIndex }, fields),
	})
end

return function(props: Props)
	local mode = props.Mode
	local portrait = props.Portrait == true
	local compact = props.Compact == true and not portrait
	local z = 2
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
			Image = UIConfig.Layout.PageSurface.Image,
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromScale(1, 1),
			SliceCenter = UIConfig.Layout.PageSurface.SliceCenter,
			SliceScale = UIConfig.Layout.PageSurface.SliceScale,
			ZIndex = 1,
		}),
		UIAspectRatioConstraint = if portrait
			then nil
			else c("UIAspectRatioConstraint", { AspectRatio = if compact then 1.05 else 0.87 }),
		Title = c(ResponsiveText, {
			HostName = "Title",
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 34,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Position = if compact
					then UDim2.new(0.5, 0, 0, 8)
					else UDim2.fromScale(0.5, if portrait then 0.035 else 0.05),
				Size = if compact
					then UDim2.new(0.88, 0, 0, 24)
					else UDim2.fromScale(if portrait then 0.9 else 0.88, if portrait then 0.18 else 0.104411),
				Text = mode.Title,
				TextColor3 = Palette.White,
				ZIndex = z,
			},
		}, { UIStroke = inkStroke(titleStroke(mode.Title)) }),
		Description = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			BackgroundColor3 = Palette.PanelRaised,
			BorderSizePixel = 0,
			Position = if compact
				then UDim2.new(0.5, 0, 0, 40)
				else UDim2.fromScale(if portrait then 0.72 else 0.5, if portrait then 0.31 else 0.175),
			Size = if compact
				then UDim2.new(0.86, 0, 0, 32)
				else UDim2.fromScale(if portrait then 0.5 else 0.85, if portrait then 0.28 else 0.16),
			ZIndex = z,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Radius.Control) }),
			TextLabel = c(ResponsiveText, {
				MeasurementFont = UIConfig.Text.BodyFont,
				MaxTextSize = 20,
				Wrapped = true,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Font = UIConfig.Text.BodyFont,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.9, 0.86),
					Text = if compact
						then string.match(mode.Description, "^[^.]+[.]?") or mode.Description
						else mode.Description,
					TextColor3 = Palette.White,
					TextWrapped = true,
					ZIndex = z + 1,
				},
			}, { Stroke = inkStroke(0.03) }),
		}),
		Thumbnail = c(Well, {
			AspectRatio = if compact then nil else 1.7,
			Native = {
				AnchorPoint = Vector2.new(0.5, if compact then 0 else 0.5),
				Position = if compact
					then UDim2.new(0.5, 0, 0, 80)
					else UDim2.fromScale(if portrait then 0.23 else 0.5, if portrait then 0.58 else 0.57),
				Size = if compact
					then UDim2.new(0.86, 0, 1, -144)
					else UDim2.fromScale(if portrait then 0.38 else 0.85, if portrait then 0.58 else 0.46),
				ZIndex = z,
			},
		}, {
			Inset = c("Frame", {
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.new(1, -12, 1, -12),
				ZIndex = z + 1,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Radius.Tile) }),
				Placeholder = placeholder(mode.Id, z + 1, compact, portrait),
				Art = c("ImageLabel", {
					BackgroundTransparency = 1,
					Image = mode.ThumbnailId,
					ScaleType = Enum.ScaleType.Crop,
					Size = UDim2.fromScale(1, 1),
					ZIndex = z + 3,
				}),
				VoteCount = c("Frame", {
					BackgroundColor3 = Palette.Ink,
					BackgroundTransparency = 0.15,
					BorderSizePixel = 0,
					AnchorPoint = if compact then Vector2.new(0, 0.5) else Vector2.zero,
					Position = if compact then UDim2.new(0, 4, 0.5, 0) else UDim2.fromOffset(8, 8),
					Size = UDim2.fromOffset(if compact then 72 else 104, if compact then 24 else 28),
					ZIndex = z + 4,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Text = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = DISPLAY_FONT,
						Position = UDim2.fromOffset(0, 1),
						Size = UDim2.fromScale(1, 1),
						Text = GameModeVoteViewModel.formatVoteCount(mode.VoteCount),
						TextColor3 = Palette.White,
						TextSize = if compact then 14 else 16,
						ZIndex = z + 5,
					}),
				}),
			}),
		}),
		VoteButton = c(AnimatedButton, {
			SelectionRadius = UDim.new(0, UIConfig.Radius.Control),
			ButtonRef = props.ButtonRef,
			Enabled = props.Enabled,
			EntranceDelay = (mode.SortOrder - 1) * 0.025,
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Image = "",
				LayoutOrder = 2,
				Position = if compact
					then UDim2.new(0.5, 0, 1, -12)
					else UDim2.new(if portrait then 0.72 else 0.5, 0, 1, if portrait then -20 else -24),
				Size = if compact
					then UDim2.new(0.86, 0, 0, UIConfig.Interaction.MinTargetPx)
					else if portrait then UDim2.new(0.42, 0, 0, 48) else UDim2.new(0.6, 0, 0, 52),
				ZIndex = z,
			},
			Visual = c(ButtonSurface, {
				Color = if mode.Selected then Palette.Pink else Palette.Cyan,
				Enabled = props.Enabled,
			}),
			OnActivated = function()
				props.OnVote(mode.Id)
			end,
		}, {
			Check = if mode.Selected
				then c(Icon, {
					Name = "Check",
					Native = {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(0.5, -42, 0.5, 0),
						Size = UDim2.fromOffset(24, 24),
						ZIndex = z + 2,
					},
				})
				else nil,
			TextLabel = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 32,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = DISPLAY_FONT,
					Position = UDim2.fromScale(if mode.Selected then 0.55 else 0.5, 0.5),
					Size = UDim2.fromScale(if mode.Selected then 0.66 else 0.8, 0.66),
					Text = if mode.Selected then "VOTED" else "VOTE",
					TextColor3 = Palette.White,
					ZIndex = z + 1,
				},
			}, { Stroke = inkStroke() }),
		}),
	})
end
