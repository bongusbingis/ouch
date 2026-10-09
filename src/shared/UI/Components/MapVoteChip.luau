-- Description: One candy chip on the ballot's map dock: placeholder-backed art, name, live vote count and the local player's pick.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local CandySurface = require(script.Parent.CandySurface)
local Icon = require(script.Parent.Icon)
local Well = require(script.Parent.Well)
local VoteModel = require(script.Parent.Parent.Models.GameModeVoteViewModel)
local Motion = require(script.Parent.Parent.Motion)
local T = require(script.Parent.Parent.Tokens)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)

local c, C, S, F, M = React.createElement, T.Colors, T.Shape, T.Type, T.MapVote

export type Map = {
	Id: string,
	Title: string,
	ShortName: string,
	ThumbnailId: string,
	Accent: Color3,
	SortOrder: number,
	VoteCount: number,
	Selected: boolean,
}

export type Props = {
	Map: Map,
	Enabled: boolean,
	OnVote: (string) -> (),
	Height: number,
	Width: number,
	Compact: boolean,
	EntranceDelay: number?,
	LayoutOrder: number?,
}

-- Only the face tilts; the content above it stays upright. PressDepth is forwarded
-- by AnimatedButton so the face still sinks under a press.
local function Face(props)
	return c("Frame", {
		BackgroundTransparency = 1,
		Rotation = S.TiltPanel,
		Size = UDim2.fromScale(1, 1),
	}, {
		Surface = c(CandySurface, {
			Color = props.Color,
			LipColor = props.LipColor,
			Radius = S.RadiusCard,
			Shadow = true,
			PressDepth = props.PressDepth,
			ZIndex = props.ZIndex,
		}),
	})
end

return function(props: Props)
	local map = props.Map
	local selected = map.Selected
	local compact = props.Compact
	local reduced = useReducedMotion()
	local styles, api = ReactSpring.useSpring(function()
		return { Selected = if selected then 1 else 0 }
	end)
	React.useEffect(function()
		api.start({ Selected = if selected then 1 else 0, config = Motion.Control, immediate = reduced })
	end, { selected, reduced })
	React.useEffect(function()
		return function()
			api.stop()
		end
	end, {})
	local fill = styles.Selected:map(function(value)
		return C.SurfaceWarm:Lerp(C.Yellow, math.clamp(value, 0, 1))
	end)
	local lip = styles.Selected:map(function(value)
		return C.WellLine:Lerp(C.YellowLip, math.clamp(value, 0, 1))
	end)

	local pad = if compact then M.CompactPadding else M.Padding
	local artHeight = props.Height - pad * 2
	local artWidth = if compact then M.CompactArtWidth else math.floor(artHeight * M.ArtAspect)
	local textX = pad + artWidth + M.Padding
	local nameSize = if compact or props.Width < 210
		then M.CompactNameSize
		else if props.Height < 72 then M.MidNameSize else M.NameSize
	local pillHeight = if compact then M.CompactPillHeight else M.PillHeight
	local pillWidth = if compact then M.CompactPillWidth else M.PillWidth
	local art = map.ThumbnailId ~= ""
	local z = 5

	return c(AnimatedButton, {
		Enabled = props.Enabled,
		Style = "Card",
		HoverRotation = false,
		FocusHint = true,
		SelectionRadius = UDim.new(0, S.RadiusCard),
		EntranceDelay = props.EntranceDelay,
		Native = {
			BackgroundTransparency = 1,
			Image = "",
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromOffset(props.Width, props.Height),
			ZIndex = z,
		},
		Visual = c(Face, { Color = fill, LipColor = lip, ZIndex = z }),
		OnActivated = function()
			if props.Enabled then
				props.OnVote(map.Id)
			end
		end,
	}, {
		Artwork = c(Well, {
			Candy = true,
			Native = {
				Position = UDim2.fromOffset(pad, pad),
				Size = UDim2.fromOffset(artWidth, artHeight),
				ZIndex = z + 2,
			},
		}, {
			Field = c("Frame", {
				BackgroundColor3 = map.Accent:Lerp(C.Surface, 0.48),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Position = UDim2.fromOffset(S.StrokeInner, S.StrokeInner),
				Size = UDim2.new(1, -S.StrokeInner * 2, 1, -S.StrokeInner * 2),
				ZIndex = z + 3,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, S.RadiusCard - S.StrokeInner) }),
				Circle = c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = C.Surface,
					BackgroundTransparency = 0.48,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.76, 0.42),
					Size = UDim2.fromOffset(artHeight, artHeight),
					ZIndex = z + 4,
				}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
				ShortName = c("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Font = F.Display,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -S.StrokeCard, 0, M.PillHeight),
					Text = map.ShortName,
					TextColor3 = C.Ink,
					TextSize = if compact then F.Minimum else F.Tab,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = z + 5,
				}),
				Art = if art
					then c("ImageLabel", {
						BackgroundTransparency = 1,
						Image = map.ThumbnailId,
						ScaleType = Enum.ScaleType.Crop,
						Size = UDim2.fromScale(1, 1),
						ZIndex = z + 6,
					}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, S.RadiusCard - S.StrokeInner) }) })
					else nil,
			}),
		}),
		Text = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(textX, 0),
			Size = UDim2.new(1, -(textX + pad), 1, 0),
			ZIndex = z + 2,
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, S.StrokeInner),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Name = c("TextLabel", {
				BackgroundTransparency = 1,
				Font = F.Display,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, nameSize + S.StrokeCard),
				Text = map.Title,
				TextColor3 = C.Ink,
				TextSize = nameSize,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = z + 3,
			}),
			CountRow = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, pillHeight),
				ZIndex = z + 3,
			}, {
				Count = c("Frame", {
					BackgroundColor3 = C.SurfaceWarm,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(pillWidth, pillHeight),
					ZIndex = z + 3,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Outline = c("UIStroke", { Color = C.Ink, Thickness = S.StrokeInner }),
					Label = c("TextLabel", {
						BackgroundTransparency = 1,
						Font = F.Label,
						Size = UDim2.fromScale(1, 1),
						Text = VoteModel.formatVoteCount(map.VoteCount),
						TextColor3 = C.Ink,
						TextSize = F.Minimum,
						ZIndex = z + 4,
					}),
				}),
				Check = if selected
					then c(Icon, {
						Name = "Check",
						Color = C.Pink,
						Native = {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.fromScale(1, 0.5),
							Size = UDim2.fromOffset(M.CheckSize, M.CheckSize),
							ZIndex = z + 4,
						},
					})
					else nil,
			}),
		}),
	})
end
