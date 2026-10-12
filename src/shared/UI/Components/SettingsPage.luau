-- Description: The settings screen: every applicable setting for the current place, grouped by category and rendered as reusable rows from the shared registry. Presentation only -- it reads current values from SettingsStore and writes changes back through it, never owning gameplay behavior itself.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")
local SettingsRegistry = require(Game:WaitForChild("Settings"):WaitForChild("SettingsRegistry"))
local SettingsStore = require(Game:WaitForChild("Settings"):WaitForChild("SettingsStore"))
local CandySurface = require(script.Parent.CandySurface)
local SectionHeader = require(script.Parent.SectionHeader)
local SettingRow = require(script.Parent.Settings.SettingRow)
local CandyPanel = require(script.Parent.CandyPanel)
local CandyTitle = require(script.Parent.CandyTitle)
local Icon = require(script.Parent.Icon)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Tokens = require(script.Parent.Parent.Tokens)

local Well = require(script.Parent.Well)

local c = React.createElement
local C = Tokens.Colors
local SETTINGS = Tokens.Settings

local ROW_HEIGHT = UIConfig.Layout.SettingsControls.RowHeight
-- Mirrors SettingRow: label line above a description, and the face-height threshold that tightens padding.
local LABEL_HEIGHT = Tokens.Type.Body + Tokens.Shape.LipHeight
local ROOMY_FACE = 88
local HEADER_HEIGHT = 38
local SHORT_HEADER_HEIGHT = 30
local COLUMN_GUTTER = 16
local SAVING_TEXT = "SAVING…"
local FAILED_TEXT = "COULDN’T SAVE. TRY AGAIN."

export type Props = {
	Position: any?,
	Size: Vector2?,
	TransitionScale: any?,
	Place: "Lobby" | "Arena",
}

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local panelSize = props.Size
		or ResponsiveLayout.panelSize(
			safeArea.size,
			UIConfig.Layout.Panels.Settings,
			UIConfig.Layout.PortraitMaxAspect,
			UIConfig.Layout.ShortLandscapeMaxHeightPx
		)
	local short = not ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
		and safeArea.size.Y <= UIConfig.Layout.ShortLandscapeMaxHeightPx
	local compact = not short and panelSize.X * 0.93 * 0.95 < UIConfig.Layout.CompactMaxWidthPx
	local inset = if short
		then Tokens.LobbyLandscape.PanelInset
		elseif compact then SETTINGS.CompactInset
		else SETTINGS.Inset
	local contentTop = if short
		then Tokens.LobbyLandscape.PanelHeader
		else if compact then SETTINGS.CompactHeaderHeight else SETTINGS.HeaderHeight
	local revision, setRevision = React.useState(0)
	-- The page title follows the Shop rule: 38 portrait, 30 on short landscape, 52 everywhere else.
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
	local titleSize = if portrait then 38 elseif short then Tokens.Type.Section else Tokens.Type.Title
	local titleHeight = if portrait then 60 elseif short then 48 else Tokens.Layout.TitleHeight
	local titleTop = if portrait then 0 elseif short then 2 else -18
	local titleWidth = if short then SETTINGS.CompactTitleWidth else SETTINGS.TitleWidth
	local titleLeft = inset + Tokens.Layout.CompactGap
	local stickerWidth = math.ceil(
		TextService:GetTextSize("SETTINGS", titleSize, Tokens.Type.Display, Vector2.new(4096, 200)).X
	) + 36
	local decorated = not short and not portrait

	React.useEffect(function()
		return SettingsStore.subscribe(function(_id)
			setRevision(function(current)
				return current + 1
			end)
		end)
	end, {})

	local handleChange = React.useCallback(function(id: string, value: any, committed: boolean)
		SettingsStore.set(id, value)
		if committed then
			SettingsStore.commit(id)
		end
	end, {})

	local definitions = React.useMemo(function()
		return SettingsRegistry.forPlace(props.Place)
	end, { props.Place })

	local categories = React.useMemo(function()
		local order: { string } = {}
		local byCategory: { [string]: { SettingsRegistry.Definition } } = {}
		for _, definition in definitions do
			if byCategory[definition.Category] == nil then
				byCategory[definition.Category] = {}
				table.insert(order, definition.Category)
			end
			table.insert(byCategory[definition.Category], definition)
		end
		return { order = order, byCategory = byCategory }
	end, { definitions })
	local categoryOrder, byCategory = categories.order, categories.byCategory

	local content: { [string]: any } = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0, if short then Tokens.LobbyLandscape.SettingsGap else SETTINGS.SectionGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = c("UIPadding", {
			PaddingBottom = UDim.new(0, SETTINGS.ContentInset),
			PaddingLeft = UDim.new(0, SETTINGS.ContentInset),
			PaddingRight = UDim.new(0, SETTINGS.ContentInset + Tokens.Layout.ScrollBar),
			PaddingTop = UDim.new(0, SETTINGS.ContentInset),
		}),
	}
	local saveStatus = ""
	for _, definition in definitions do
		local status = SettingsStore.status(definition.Id)
		if status == "failed" then
			saveStatus = FAILED_TEXT
			break
		end
		if status == "pending" then
			saveStatus = SAVING_TEXT
		end
	end
	local failed = saveStatus == FAILED_TEXT
	local statusWidth = if saveStatus == ""
		then 0
		else math.ceil(
			TextService:GetTextSize(saveStatus, Tokens.Type.Minimum, Tokens.Type.Display, Vector2.new(100000, 1000)).X
		) + Tokens.Layout.CompactGap * 2
	local layoutOrder = 0
	local columnHeights = { 0, 0 }
	local columns = short and panelSize.X >= 700
	-- Width of one row card: the scroll content area, halved (minus the gutter) when laid out in two columns.
	local contentWidth = panelSize.X
		- inset * 2
		- Tokens.Shape.StrokeCard * 2
		- SETTINGS.ContentInset * 2
		- Tokens.Layout.ScrollBar
	local rowWidth = if columns then contentWidth / 2 - COLUMN_GUTTER else contentWidth
	if columns then
		content.UIListLayout = nil
	end
	for _, category in categoryOrder do
		layoutOrder += 1
		content[`Category{category}`] = c(SectionHeader, {
			Text = category,
			Candy = true,
			HeightPx = if short then SHORT_HEADER_HEIGHT else HEADER_HEIGHT,
			TextSize = if short then Tokens.Type.Body else Tokens.Type.TileLabel,
			LayoutOrder = layoutOrder,
			ZIndex = 5,
		})
		local categoryRows = {
			Layout = c("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, SETTINGS.RowGap),
			}),
		}
		local categoryHeight = 0
		for rowOrder, definition in byCategory[category] do
			local hasDescription = definition.Description ~= nil and definition.Description ~= ""
			local heightTable = if compact then ROW_HEIGHT.Compact else ROW_HEIGHT.Wide
			local rowHeight = if hasDescription then heightTable.Description else heightTable.Plain
			if short then
				rowHeight = UIConfig.Layout.SettingsControls.ShortRowHeightPx
			end
			if hasDescription and (compact or short) then
				-- Measure the wrapped description at the width SettingRow gives it so no line is ever clipped.
				local textShare = if compact then 1 elseif definition.Type == "Slider" then 0.44 else 0.5
				local textWidth = math.max(textShare * rowWidth - SETTINGS.CardInset * 2, 1)
				local measured = math.ceil(
					TextService:GetTextSize(
						definition.Description :: string,
						Tokens.Type.Minimum,
						Tokens.Type.Label,
						Vector2.new(textWidth, 1e4)
					).Y
				)
				local controlReserve = if compact
					then UIConfig.Interaction.MinTargetPx + UIConfig.Layout.SettingsControls.LabelControlGapPx
					else 0
				local function neededHeight(verticalInset: number): number
					return LABEL_HEIGHT + measured + controlReserve + verticalInset * 2 + Tokens.Shape.LipHeight
				end
				-- SettingRow uses the tight inset only while the face stays under ROOMY_FACE, the roomy one otherwise.
				rowHeight = math.max(rowHeight, neededHeight(Tokens.Shape.StrokeCard * 2))
				if rowHeight - Tokens.Shape.LipHeight >= ROOMY_FACE then
					rowHeight = math.max(rowHeight, neededHeight(Tokens.Layout.CompactGap))
				end
			end
			categoryHeight += rowHeight
			if rowOrder > 1 then
				categoryHeight += SETTINGS.RowGap
			end
			categoryRows[definition.Id] = c(SettingRow, {
				Definition = definition,
				Value = SettingsStore.get(definition.Id),
				Compact = compact,
				Height = rowHeight,
				LayoutOrder = rowOrder,
				OnChange = handleChange,
			})
		end
		layoutOrder += 1
		content[`Rows{category}`] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = layoutOrder,
			Size = UDim2.new(1, 0, 0, categoryHeight),
		}, categoryRows)
		if columns then
			local column = if columnHeights[1] <= columnHeights[2] then 1 else 2
			local headerKey, rowsKey = `Category{category}`, `Rows{category}`
			local blockHeight = HEADER_HEIGHT + categoryHeight
			content[`Column{category}`] = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(
					(column - 1) * 0.5,
					if column == 2 then COLUMN_GUTTER / 2 else 0,
					0,
					columnHeights[column]
				),
				Size = UDim2.new(0.5, -COLUMN_GUTTER, 0, blockHeight),
			}, {
				Header = content[headerKey],
				Rows = c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, HEADER_HEIGHT),
					Size = UDim2.new(1, 0, 0, categoryHeight),
				}, categoryRows),
			})
			content[headerKey], content[rowsKey] = nil, nil
			columnHeights[column] += blockHeight + SETTINGS.RowGap
		end
	end

	return c(CandyPanel, {
		Tilt = if short then 0 else nil,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = props.Position or UIConfig.Layout.PagePosition,
			Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
			LayoutOrder = 5,
		},
	}, {
		EntranceScale = if props.TransitionScale then c("UIScale", { Scale = props.TransitionScale }) else nil,
		Title = c(CandyTitle, {
			Tilt = if short then 0 else nil,
			Text = "SETTINGS",
			TextSize = titleSize,
			Native = {
				Position = UDim2.fromOffset(titleLeft, titleTop),
				Size = UDim2.fromOffset(titleWidth, titleHeight),
				ZIndex = 8,
			},
		}),
		TitleStar = if decorated
			then c(Icon, {
				Name = "Star",
				Color = C.Yellow,
				Native = {
					Position = UDim2.fromOffset(titleLeft + stickerWidth - 10, titleTop - Tokens.Layout.CompactGap),
					Size = UDim2.fromOffset(titleHeight * 0.7, titleHeight * 0.7),
					ZIndex = 10,
				},
			})
			else nil,
		TitleSparkle = if decorated
			then c(Icon, {
				Name = "Sparkle",
				Color = C.Cyan,
				Native = {
					Position = UDim2.fromOffset(titleLeft - titleHeight * 0.55, titleTop + titleHeight * 0.3),
					Size = UDim2.fromOffset(titleHeight * 0.45, titleHeight * 0.45),
					ZIndex = 10,
				},
			})
			else nil,
		Main = c(Well, {
			Candy = true,
			Native = {
				Position = UDim2.fromOffset(inset, contentTop),
				Size = UDim2.new(1, -inset * 2, 1, -contentTop - inset),
				ZIndex = 3,
			},
		}, {
			Content = c("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
				Position = UDim2.fromOffset(Tokens.Shape.StrokeCard, Tokens.Shape.StrokeCard),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarImageColor3 = C.Pink,
				ScrollBarImageTransparency = 0,
				ScrollBarThickness = Tokens.Layout.ScrollBar,
				Size = UDim2.new(
					1,
					-Tokens.Shape.StrokeCard * 2,
					1,
					-Tokens.Shape.StrokeCard * 2 - (if saveStatus ~= "" then SETTINGS.StatusHeight else 0)
				),
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				ZIndex = 4,
			}, content),
			SaveStatus = if saveStatus ~= ""
				then c("Frame", {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					Position = UDim2.new(0.5, 0, 1, -Tokens.Shape.StrokeCard),
					Size = UDim2.fromOffset(
						math.min(statusWidth, panelSize.X - inset * 2 - SETTINGS.ContentInset * 2),
						SETTINGS.StatusHeight
					),
					ZIndex = 5,
				}, {
					Pill = c(CandySurface, {
						Color = if failed then C.Pink else C.Yellow,
						LipColor = if failed then C.PinkLip else C.YellowLip,
						Shadow = false,
						ZIndex = 5,
					}),
					Text = c("TextLabel", {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(Tokens.Layout.CompactGap / 2, 0),
						Size = UDim2.new(1, -Tokens.Layout.CompactGap, 1, -Tokens.Shape.LipHeight),
						Font = Tokens.Type.Display,
						Text = saveStatus,
						TextColor3 = if failed then C.Surface else C.Ink,
						TextSize = Tokens.Type.Minimum,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 8,
					}, {
						Outline = if failed
							then c("UIStroke", { Color = C.Ink, Thickness = Tokens.Type.Outline })
							else nil,
					}),
				})
				else nil,
		}),
	})
end
