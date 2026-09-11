-- Description: The settings screen: every applicable setting for the current place, grouped by category and rendered as reusable rows from the shared registry. Presentation only -- it reads current values from SettingsStore and writes changes back through it, never owning gameplay behavior itself.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")
local SettingsRegistry = require(Game:WaitForChild("Settings"):WaitForChild("SettingsRegistry"))
local SettingsStore = require(Game:WaitForChild("Settings"):WaitForChild("SettingsStore"))
local ResponsiveText = require(script.Parent.ResponsiveText)
local PageTitle = require(script.Parent.PageTitle)
local SectionHeader = require(script.Parent.SectionHeader)
local SettingRow = require(script.Parent.Settings.SettingRow)
local AssetCredits = require(script.Parent.Settings.AssetCredits)
local ActionButton = require(script.Parent.Shop.ShopPriceButton)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)

local Well = require(script.Parent.Well)

local c = React.createElement

local ROW_HEIGHT = UIConfig.Layout.SettingsControls.RowHeight

export type Props = {
	Position: any?,
	Place: "Lobby" | "Arena",
}

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local panelSize = ResponsiveLayout.panelSize(
		safeArea.size,
		UIConfig.Layout.Panels.Settings,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local short = not ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
		and safeArea.size.Y <= UIConfig.Layout.ShortLandscapeMaxHeightPx
	local compact = not short and panelSize.X * 0.93 * 0.95 < UIConfig.Layout.CompactMaxWidthPx
	local contentTop = math.max(panelSize.Y * 0.185, if short then 44 else 0)
	local revision, setRevision = React.useState(0)
	local creditsOpen, setCreditsOpen = React.useState(false)
	local scrollRef = React.useRef(nil)
	local creditsButtonRef = React.useRef(nil)
	local creditsBackRef = React.useRef(nil)
	local settingsScroll = React.useRef(Vector2.zero)
	local restoreFocus = React.useRef(false)

	local function showCredits(open: boolean)
		if open and scrollRef.current then
			settingsScroll.current = scrollRef.current.CanvasPosition
		end
		restoreFocus.current = GuiService.SelectedObject ~= nil
		setCreditsOpen(open)
	end

	React.useEffect(function()
		if scrollRef.current then
			scrollRef.current.CanvasPosition = if creditsOpen then Vector2.zero else settingsScroll.current
		end
		if restoreFocus.current then
			GuiService.SelectedObject = if creditsOpen then creditsBackRef.current else creditsButtonRef.current
			restoreFocus.current = false
		end
	end, { creditsOpen })

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
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = c("UIPadding", {
			PaddingBottom = UDim.new(0, 24),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 4),
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
	for _, category in categoryOrder do
		layoutOrder += 1
		content[`Category{category}`] = c(SectionHeader, {
			Text = category,
			HeightPx = if short then 30 else 38,
			TextSize = if short then 20 else 24,
			LayoutOrder = layoutOrder,
			ZIndex = 5,
		})
		local categoryRows = {
			Layout = c("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
			Padding = c("UIPadding", {
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		}
		local categoryHeight = 16
		for _, definition in byCategory[category] do
			layoutOrder += 1
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
			categoryHeight += rowHeight + 8
			categoryRows[definition.Id] = c(SettingRow, {
				Definition = definition,
				Value = SettingsStore.get(definition.Id),
				Compact = compact,
				Height = rowHeight,
				LayoutOrder = layoutOrder,
				OnChange = handleChange,
			})
		end
		content[`Well{category}`] = c(
			Well,
			{ Native = { LayoutOrder = layoutOrder, Size = UDim2.new(1, 0, 0, categoryHeight - 8) } },
			categoryRows
		)
	end

	content.AssetCredits = c(ActionButton, {
		ButtonRef = creditsButtonRef,
		AnchorPoint = Vector2.zero,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = layoutOrder + 1,
		Text = "ASSET CREDITS",
		TextSize = 22,
		Compact = true,
		OnActivated = function()
			showCredits(true)
		end,
	})
	local creditsContent = {
		Layout = c("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = c("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 24),
		}),
		Credits = c(AssetCredits),
	}

	return c("ImageLabel", {
		BackgroundTransparency = 1,
		Image = UIConfig.Layout.PageSurface.Image,
		LayoutOrder = 5,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position or UIConfig.Layout.PagePosition,
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
		SliceCenter = UIConfig.Layout.PageSurface.SliceCenter,
		SliceScale = UIConfig.Layout.PageSurface.SliceScale,
	}, {
		Title = c(PageTitle, {
			Text = if creditsOpen then "ASSET CREDITS" else "SETTINGS",
			TextSize = if short then 26 else 42,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = if short then UDim2.new(0.5, 0, 0, 8) else UDim2.fromScale(0.5, 0.045),
				Size = UDim2.new(0.76, 0, 0, if short then 30 else 54),
				ZIndex = 5,
			},
		}),
		Main = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, contentTop),
			Size = UDim2.new(0.93, 0, 0, math.max(panelSize.Y * 0.965 - contentTop, 0)),
		}, {
			Content = c("ScrollingFrame", {
				ref = scrollRef,
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
				Position = UDim2.fromScale(0.025, 0),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarImageColor3 = Color3.new(1, 1, 1),
				ScrollBarImageTransparency = 0.1,
				ScrollBarThickness = if compact then 5 else 7,
				Selectable = creditsOpen,
				Size = UDim2.new(0.95, 0, 1, if creditsOpen then -54 elseif saveStatus ~= "" then -38 else 0),
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			}, if creditsOpen then creditsContent else content),
			CreditsBack = if creditsOpen
				then c(ActionButton, {
					ButtonRef = creditsBackRef,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0.025, 1),
					Size = UDim2.new(0.95, 0, 0, 44),
					Text = "BACK TO SETTINGS",
					TextSize = 22,
					Compact = true,
					OnActivated = function()
						showCredits(false)
					end,
				})
				else nil,
			SaveStatus = if not creditsOpen and saveStatus ~= ""
				then c(ResponsiveText, {
					MeasurementFont = UIConfig.Text.BodyFont,
					MaxTextSize = 16,
					MinTextSize = 14,
					Native = {
						BackgroundTransparency = 1,
						Font = UIConfig.Text.BodyFont,
						Position = UDim2.new(0.025, 0, 1, -34),
						Size = UDim2.new(0.95, 0, 0, 30),
						Text = saveStatus,
						TextColor3 = Color3.new(1, 1, 1),
						ZIndex = 5,
					},
				})
				else nil,
		}),
	})
end
