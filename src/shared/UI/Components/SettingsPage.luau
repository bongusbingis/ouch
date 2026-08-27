-- Name: SettingsPage.luau
-- Author: Jack C.
-- Description: The settings screen: every applicable setting for the current place, grouped by category and rendered as reusable rows from the shared registry. Presentation only -- it reads current values from SettingsStore and writes changes back through it, never owning gameplay behavior itself.
-- Created: 2026-08-25

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")
local SettingsRegistry = require(Game:WaitForChild("Settings"):WaitForChild("SettingsRegistry"))
local SettingsStore = require(Game:WaitForChild("Settings"):WaitForChild("SettingsStore"))
local ResponsiveText = require(script.Parent.ResponsiveText)
local SettingRow = require(script.Parent.Settings.SettingRow)

local c = React.createElement

local COMPACT_WIDTH_PIXELS = 820
local ROW_HEIGHT = { Compact = { Plain = 108, Description = 148 }, Wide = { Plain = 64, Description = 88 } }

export type Props = {
	Position: any?,
	Place: "Lobby" | "Arena",
}

return function(props: Props)
	local compact, setCompact = React.useState(false)
	local revision, setRevision = React.useState(0)

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
			Padding = UDim.new(0, if compact then 10 else 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = c("UIPadding", {
			PaddingBottom = UDim.new(0, 24),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 4),
		}),
	}
	local layoutOrder = 0
	for _, category in categoryOrder do
		layoutOrder += 1
		content[`Category{category}`] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = layoutOrder,
			Size = UDim2.new(1, 0, 0, 34),
		}, {
			Label = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 22,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, 1),
					Text = category,
					TextColor3 = Color3.fromRGB(97, 255, 237),
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 5,
				},
			}),
		})
		for _, definition in byCategory[category] do
			layoutOrder += 1
			local hasDescription = definition.Description ~= nil and definition.Description ~= ""
			local heightTable = if compact then ROW_HEIGHT.Compact else ROW_HEIGHT.Wide
			local rowHeight = if hasDescription then heightTable.Description else heightTable.Plain
			content[definition.Id] = c(SettingRow, {
				Definition = definition,
				Value = SettingsStore.get(definition.Id),
				Compact = compact,
				Height = rowHeight,
				LayoutOrder = layoutOrder,
				OnChange = handleChange,
			})
		end
	end

	return c("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://136021539696619",
		LayoutOrder = 5,
		Position = props.Position or UDim2.fromScale(0.0211629, 0.14282),
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(0.602, 0.748),
		SliceCenter = Rect.new(224, 202, 770, 474),
		SliceScale = 0.06,
	}, {
		Title = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 62,
			Native = {
				BackgroundColor3 = Color3.fromRGB(63, 63, 63),
				BorderSizePixel = 0,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.291804, 0.0540634),
				Size = UDim2.fromScale(0.398251, 0.0898091),
				Text = "SETTINGS",
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 5,
			},
		}),
		Main = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.575),
			Size = UDim2.fromScale(0.93, 0.78),
		}, {
			Content = c("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				CanvasSize = UDim2.fromOffset(0, 0),
				ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
				Position = UDim2.fromScale(0.025, 0),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarImageColor3 = Color3.new(1, 1, 1),
				ScrollBarImageTransparency = 0.1,
				ScrollBarThickness = if compact then 5 else 7,
				Size = UDim2.fromScale(0.95, 0.93),
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				[React.Change.AbsoluteSize] = function(instance)
					setCompact(instance.AbsoluteSize.X < COMPACT_WIDTH_PIXELS)
				end,
			}, content),
		}),
	})
end
