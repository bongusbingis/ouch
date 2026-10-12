-- Name: StandingsStrip.luau
-- Author: Jack C.
-- Description: The always-on live leaderboard in a match: the top three players plus the local player's own row, docked at the top-right of the safe area as a translucent ink strip so it can be read at a glance without ever taking the cursor; tapping it on touch opens the full board.
-- Created: 2026-09-10
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Config =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("ArenaPresentation"))
local MatchHUDModel = require(script.Parent.Parent.Parent.Models.MatchHUDModel)
local Icon = require(script.Parent.Parent.Icon)

local c = React.createElement
local Well = require(script.Parent.Parent.Well)
local T = require(script.Parent.Parent.Parent.Tokens)
local colors = T.ArenaHUD.Colors
local DISPLAY_FONT = Font.fromEnum(T.Type.Display)

export type Props = {
	Snapshot: any,
	Short: boolean,
	Position: UDim2,
	AnchorPoint: Vector2?,
	OnActivated: (() -> ())?,
	ZIndex: number?,
}

local function shortName(name: string, limit: number): string
	if #name <= limit then
		return name
	end
	return string.sub(name, 1, limit - 1) .. "…"
end

local function stripHeight(rowCount: number, short: boolean): number
	local layout = Config.Standings
	local row = if short then layout.ShortRowPx else layout.RowPx
	return layout.PadPx * 2 + rowCount * row + math.max(rowCount - 1, 0) * 2
end

return function(props: Props)
	local view = props.Snapshot
	local layout = Config.Standings
	local short = props.Short
	local rowHeight = if short then layout.ShortRowPx else layout.RowPx
	local width = if short then layout.ShortWidthPx else layout.WidthPx
	local limit = if short then 1 else layout.Limit
	local rows = MatchHUDModel.strip(view.entries, limit)
	local z = props.ZIndex or 10
	if #rows == 0 then
		return nil
	end
	local accentByTeam = {}
	for _, team in view.teams or {} do
		accentByTeam[team.id] = team.accent
	end
	local children = {
		Layout = c("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = c("UIPadding", {
			PaddingBottom = UDim.new(0, layout.PadPx),
			PaddingLeft = UDim.new(0, layout.PadPx),
			PaddingRight = UDim.new(0, layout.PadPx),
			PaddingTop = UDim.new(0, layout.PadPx),
		}),
	}
	for index, entry in rows do
		local leader = entry.placement == 1
		local textSize = T.Type.HudMinimum
		children[`Row{index}`] = c("Frame", {
			BackgroundColor3 = if entry.isLocal then colors.Pink else colors.Panel,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, rowHeight),
			ZIndex = z + 1,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }),
			Team = if view.teamMode and entry.teamId
				then c("Frame", {
					BackgroundColor3 = colors[accentByTeam[entry.teamId] or "Cyan"],
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.new(0, 4, 1, 0),
					ZIndex = z + 2,
				}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }) })
				else nil,
			Rank = c("TextLabel", {
				Visible = not leader,
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Position = UDim2.fromOffset(8, 1),
				Size = UDim2.fromOffset(26, rowHeight),
				Text = tostring(entry.placement),
				TextColor3 = colors.Ink,
				TextSize = textSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = z + 2,
			}),
			Crown = if leader
				then c(Icon, {
					Name = "Crown",
					Color = colors.Yellow,
					Native = {
						Position = UDim2.fromOffset(6, 1),
						Size = UDim2.fromOffset(24, rowHeight - 2),
						ZIndex = z + 2,
					},
				})
				else nil,
			Name = c("TextLabel", {
				BackgroundTransparency = 1,
				Font = T.Type.Label,
				Position = UDim2.fromOffset(34, 0),
				Size = UDim2.new(1, -34 - 52, 1, 0),
				Text = if entry.isLocal then "YOU" else shortName(entry.displayName, layout.NameChars),
				TextColor3 = colors.Ink,
				TextSize = textSize,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = z + 2,
			}),
			Score = c("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Position = UDim2.new(1, -8, 0, 1),
				Size = UDim2.fromOffset(48, rowHeight),
				Text = tostring(entry.score),
				TextColor3 = colors.Ink,
				TextSize = textSize,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = z + 2,
			}),
		})
	end
	local height = stripHeight(#rows, short)
	return c("TextButton", {
		Active = props.OnActivated ~= nil,
		AutoButtonColor = false,
		AnchorPoint = props.AnchorPoint or Vector2.new(1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = props.Position,
		Selectable = false,
		Size = UDim2.fromOffset(width, height),
		Text = "",
		ZIndex = z,
		[React.Event.Activated] = props.OnActivated,
	}, {
		Well = c(Well, { Candy = true, Native = { Size = UDim2.fromScale(1, 1), ZIndex = z } }, {
			Rows = c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 1 }, children),
		}),
	})
end
