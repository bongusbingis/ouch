-- Description: The settings screen: every applicable setting for the current place, grouped by category and rendered as reusable rows from the shared registry. Presentation only -- it reads current values from SettingsStore and writes changes back through it, never owning gameplay behavior itself.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")
local SettingsRegistry = require(Game:WaitForChild("Settings"):WaitForChild("SettingsRegistry"))
local SettingsStore = require(Game:WaitForChild("Settings"):WaitForChild("SettingsStore"))
local ResponsiveText = require(script.Parent.ResponsiveText)
local SectionHeader = require(script.Parent.SectionHeader)
local SettingRow = require(script.Parent.Settings.SettingRow)
local CandyPanel = require(script.Parent.CandyPanel)
local CandyTitle = require(script.Parent.CandyTitle)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Tokens = require(script.Parent.Parent.Tokens)

local Well = require(script.Parent.Well)

local c = React.createElement
local C = Tokens.Colors
local SETTINGS = Tokens.Settings

local ROW_HEIGHT = UIConfig.Layout.SettingsControls.RowHeight

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
	local titleWidth = if compact or short then SETTINGS.CompactTitleWidth else SETTINGS.TitleWidth

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
			PaddingRight = UDim.new(0, SETTINGS.ContentInset + SETTINGS.ScrollBar),
			PaddingTop = UDim.new(0, SETTINGS.ContentInset),
		}),
	}
	local saveStatus = ""
	for _, definition in definitions do
		local status = SettingsStore.status(definition.Id)
		if status == "failed" then
			saveStatus = "Couldn’t confirm this change. Check the value and try again."
			break
		end
		if status == "pending" then
			saveStatus = "Saving…"
		end
	end
	local layoutOrder = 0
	local columnHeights = { 0, 0 }
	local columns = short and panelSize.X >= 700
	if columns then
		content.UIListLayout = nil
	end
	for _, category in categoryOrder do
		layoutOrder += 1
		content[`Category{category}`] = c(SectionHeader, {
			Text = category,
			Candy = true,
			HeightPx = if short then 30 else 38,
			TextSize = if short then 20 else Tokens.Type.TileLabel,
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
			local rowHeight = (if hasDescription then heightTable.Description else heightTable.Plain)
				+ (
					if compact and definition.Type == "Slider"
						then UIConfig.Layout.SettingsControls.SliderLabelHeightPx
						else 0
				)
			if short then
				rowHeight = UIConfig.Layout.SettingsControls.ShortRowHeightPx
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
			local blockHeight = 38 + categoryHeight
			content[`Column{category}`] = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new((column - 1) * 0.5, if column == 2 then 8 else 0, 0, columnHeights[column]),
				Size = UDim2.new(0.5, -16, 0, blockHeight),
			}, {
				Header = content[headerKey],
				Rows = c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 38),
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
			TextSize = if short then 26 elseif compact then 38 else 46,
			Native = {
				Position = UDim2.fromOffset(inset + 12, if short then 2 else -18),
				Size = UDim2.fromOffset(titleWidth, if short then 48 else 70),
				ZIndex = 8,
			},
		}),
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
				Position = UDim2.fromOffset(4, 4),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarImageColor3 = C.Pink,
				ScrollBarImageTransparency = 0,
				ScrollBarThickness = SETTINGS.ScrollBar,
				Size = UDim2.new(1, -8, 1, if saveStatus ~= "" then -(SETTINGS.StatusHeight + 8) else -8),
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				ZIndex = 4,
			}, content),
			SaveStatus = if saveStatus ~= ""
				then c(ResponsiveText, {
					MeasurementFont = UIConfig.Text.BodyFont,
					MaxTextSize = 16,
					MinTextSize = 14,
					Native = {
						BackgroundTransparency = 1,
						Font = UIConfig.Text.BodyFont,
						Position = UDim2.new(0, SETTINGS.ContentInset, 1, -SETTINGS.StatusHeight - 4),
						Size = UDim2.new(1, -SETTINGS.ContentInset * 2, 0, SETTINGS.StatusHeight),
						Text = saveStatus,
						TextColor3 = C.InkSoft,
						TextWrapped = true,
						ZIndex = 5,
					},
				})
				else nil,
		}),
	})
end
