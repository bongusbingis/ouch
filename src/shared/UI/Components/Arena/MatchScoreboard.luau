-- Name: MatchScoreboard.luau
-- Author: Jack C.
-- Description: The full match standings, shown only while the player holds the scoreboard key (Tab or Select) or after tapping the standings strip on touch: a translucent overlay panel listing every player in one or two columns with team totals, which never takes the cursor or GUI selection so the fight underneath keeps playing.
-- Created: 2026-09-10
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Config =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("ArenaPresentation"))
local Surface = require(script.Parent.Surface)
local Label = require(script.Parent.Label)
local ModalClose = require(script.Parent.Parent.ModalClose)
local WellScroll = require(script.Parent.Parent.WellScroll)
local MatchHUDModel = require(script.Parent.Parent.Parent.Models.MatchHUDModel)
local useSafeArea = require(script.Parent.Parent.Parent.Hooks.useSafeArea)

local c = React.createElement
local colors = Config.Colors
local DISPLAY_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")

local function stroke(thickness: number)
	return c("UIStroke", {
		Color = colors.Ink,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = thickness,
	})
end

local function row(entry, index: number, height: number, teamMode: boolean, z: number)
	local textSize = if height < 28 then 14 else 17
	return c("Frame", {
		BackgroundColor3 = if entry.isLocal then colors.Pink else colors.Claimed,
		BackgroundTransparency = if entry.isLocal then 0 else 0.35,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, height),
		ZIndex = z,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, UI.Radius.Tile) }),
		Rank = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = DISPLAY_FONT,
			Position = UDim2.fromOffset(10, 1),
			Size = UDim2.fromOffset(30, height),
			Text = if teamMode then "" else tostring(entry.placement),
			TextColor3 = if entry.placement == 1 then colors.Yellow else colors.White,
			TextSize = textSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = z + 1,
		}, { Outline = stroke(0.045) }),
		Name = c("TextLabel", {
			BackgroundTransparency = 1,
			Font = UI.Text.BodyFont,
			Position = UDim2.fromOffset(if teamMode then 12 else 40, 0),
			Size = UDim2.new(1, -(if teamMode then 12 else 40) - (if entry.alive then 60 else 166), 1, 0),
			Text = entry.displayName .. (if entry.isLocal then " (YOU)" else ""),
			TextColor3 = colors.White,
			TextSize = textSize,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = z + 1,
		}, { Outline = stroke(0.03) }),
		Status = if not entry.alive
			then c("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Font = UI.Text.BodyFont,
				Position = UDim2.new(1, -56, 0, 0),
				Size = UDim2.fromOffset(100, height),
				Text = "RESPAWNING",
				TextColor3 = colors.Muted,
				TextSize = textSize - 3,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = z + 1,
			})
			else nil,
		Score = c("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			FontFace = DISPLAY_FONT,
			Position = UDim2.new(1, -10, 0, 1),
			Size = UDim2.fromOffset(44, height),
			Text = tostring(entry.score),
			TextColor3 = colors.Yellow,
			TextSize = textSize,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = z + 1,
		}, { Outline = stroke(0.045) }),
	})
end

return function(props)
	local safe = useSafeArea(Enum.ScreenInsets.None)
	if not props.Visible then
		return nil
	end
	local view = props.Snapshot
	local layout = Config.Scoreboard
	local short = safe.size.Y < Config.Results.ShortHeightPx
	local rowHeight = if short then layout.ShortRowPx else layout.RowPx
	-- A narrow (portrait) safe area cannot fit two readable columns, so a
	-- free-for-all stays in one column there however long it is.
	local narrow = safe.size.X < layout.TwoColumnMinWidthPx
	local stackTeams = narrow and view.teamMode
	local columns =
		MatchHUDModel.columns(view.entries, view.teamMode, if narrow then math.huge else layout.SingleColumnMaxRows)
	local longest = 0
	for _, column in columns do
		longest = math.max(longest, #column)
	end
	longest = math.max(longest, 1)
	local columnHeader = if view.teamMode then rowHeight + 6 else 0
	local listHeight = columnHeader + longest * rowHeight + (longest - 1) * layout.RowGapPx
	if stackTeams then
		listHeight = 0
		for _, column in columns do
			listHeight += columnHeader + #column * (rowHeight + layout.RowGapPx)
		end
		listHeight += layout.ColumnGapPx
	end
	local width = math.min(safe.size.X * (if short or narrow then 0.94 else layout.WidthScale), layout.MaxWidthPx)
	local height = math.min(safe.size.Y * layout.HeightScale, layout.HeaderPx + listHeight + layout.FooterPx + 20)
	local touch = UserInputService.TouchEnabled
	local z = 81
	local columnChildren = {
		Layout = c("UIListLayout", {
			FillDirection = if stackTeams then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, layout.ColumnGapPx),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for columnIndex, column in columns do
		local rows = {
			Layout = c("UIListLayout", {
				Padding = UDim.new(0, layout.RowGapPx),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		if view.teamMode then
			local red = columnIndex == 1
			rows.Header = c("Frame", {
				BackgroundColor3 = if red then colors.Pink else colors.Cyan,
				BorderSizePixel = 0,
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, rowHeight),
				ZIndex = z + 2,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, UI.Radius.Tile) }),
				Text = c(Label, {
					Text = `{if red then "RED" else "BLUE"}  {if red then view.redScore else view.blueScore}`,
					Title = true,
					Size = if short then 16 else 20,
					Native = { Size = UDim2.fromScale(1, 1), ZIndex = z + 3 },
				}),
			})
		end
		for index, entry in column do
			rows[`Row{index}`] = row(entry, index, rowHeight, view.teamMode, z + 2)
		end
		columnChildren[`Column{columnIndex}`] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = columnIndex,
			Size = if stackTeams
				then UDim2.new(1, 0, 0, columnHeader + #column * (rowHeight + layout.RowGapPx))
				else UDim2.new(1 / #columns, -(layout.ColumnGapPx * (#columns - 1)) / #columns, 0, listHeight),
			ZIndex = z + 2,
		}, rows)
	end
	return c("Frame", {
		Active = false,
		BackgroundColor3 = colors.Ink,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 80,
	}, {
		Dismiss = if touch
			then c("TextButton", {
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Selectable = false,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				ZIndex = 80,
				[React.Event.Activated] = props.OnClose,
			})
			else nil,
		Panel = c(Surface, {
			Color = colors.Panel,
			Transparency = 0,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(safe.position.X + safe.size.X / 2, safe.position.Y + safe.size.Y / 2),
				Size = UDim2.fromOffset(width, height),
				ZIndex = z,
			},
		}, {
			Title = c(Label, {
				Text = "SCOREBOARD",
				Title = true,
				Size = if short then 24 else 30,
				Align = Enum.TextXAlignment.Left,
				Native = { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -140, 0, 34), ZIndex = z + 2 },
			}),
			Mode = c(Label, {
				Text = view.title .. "  •  " .. view.clock .. (if view.target > 0
					then `  •  FIRST TO {view.target}`
					else ""),
				Color = colors.White,
				Size = if short then 13 else 16,
				Align = Enum.TextXAlignment.Left,
				Native = {
					Position = UDim2.fromOffset(16, if short then 32 else 38),
					Size = UDim2.new(1, -140, 0, 20),
					ZIndex = z + 2,
				},
			}),
			Close = if touch
				then c(ModalClose, {
					Position = UDim2.new(1, -12, 0, 12),
					SizePx = UI.Interaction.MinTargetPx,
					OnActivated = props.OnClose,
					ZIndex = z + 3,
				})
				else c(Label, {
					Text = if string.find(UserInputService:GetLastInputType().Name, "Gamepad")
						then "HOLD SELECT"
						else "HOLD TAB",
					Color = colors.White,
					Size = UI.Text.CaptionMinPx,
					Align = Enum.TextXAlignment.Right,
					Native = { Position = UDim2.new(1, -116, 0, 12), Size = UDim2.fromOffset(100, 20), ZIndex = z + 2 },
				}),
			Columns = c(WellScroll, {
				Native = {
					Position = UDim2.fromOffset(16, layout.HeaderPx),
					Size = UDim2.new(1, -32, 1, -layout.HeaderPx - layout.FooterPx),
					CanvasSize = UDim2.fromOffset(0, listHeight),
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ScrollBarThickness = 4,
					ScrollBarImageColor3 = colors.White,
					Selectable = false,
					ZIndex = z + 2,
				},
			}, columnChildren),
			Footer = c(Label, {
				Text = if view.teamMode then "TEAM ELIMINATIONS" else "ELIMINATIONS",
				Color = colors.White,
				Size = UI.Text.CaptionMinPx,
				Native = {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -8),
					Size = UDim2.new(1, -32, 0, 18),
					ZIndex = z + 2,
				},
			}),
		}),
	})
end
