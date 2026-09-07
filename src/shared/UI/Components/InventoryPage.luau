-- Name: InventoryPage.luau
-- Author: Jack C.
-- Description: The locker page: renders every cosmetic category as scrollable cards with ownership and equip state and drives the live item preview.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local InventoryConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory"))
local InventoryModel = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("InventoryModel")
)
local AnimatedButton = require(script.Parent.AnimatedButton)
local ActivityDots = require(script.Parent.ActivityDots)
local InventoryPreview = require(script.Parent.InventoryPreview)
local ResponsiveText = require(script.Parent.ResponsiveText)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Selection = require(script.Parent.Parent.Services.Selection)

local c = React.createElement

export type Props = {
	Data: any?,
	Position: any?,
	OnEquip: (InventoryModel.Entry) -> (),
	OnInspect: ((InventoryModel.Entry) -> ())?,
	SelectedTab: string,
	OnTabChanged: (string) -> (),
}

local function ownershipKey(data: any?): string
	if data == nil then
		return ""
	end
	local ids = {}
	for itemId, owned in data.Cosmetics.Owned do
		if owned == true then
			table.insert(ids, itemId)
		end
	end
	table.sort(ids)
	return table.concat(ids, "\0")
end

local function shortName(entry: InventoryModel.Entry): string
	local name = string.gsub(entry.displayName, "^Default%s+", "")
	local suffix = if entry.category == "BallAssets"
		then " Ball"
		elseif entry.category == "HammerAssets" then " Hammer"
		else nil
	if suffix ~= nil and string.sub(name, -#suffix) == suffix and #name > #suffix then
		return string.sub(name, 1, #name - #suffix)
	end
	return name
end

local function cardColor(entry: InventoryModel.Entry): Color3
	local color = entry.definition.PreviewColor or InventoryConfig.RarityColors[entry.rarity]
	assert(color ~= nil, `[InventoryPage] unknown rarity {entry.rarity}`)
	return color
end

local function Card(props)
	local entry: InventoryModel.Entry = props.Entry
	return c(AnimatedButton, {
		Style = "Card",
		Native = {
			BackgroundTransparency = 1,
			Image = "rbxassetid://123285423801571",
			LayoutOrder = props.LayoutOrder,
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromOffset(props.CardSize, props.CardHeight),
			SliceCenter = Rect.new(107, 27, 126, 128),
			TileSize = UDim2.fromScale(0.4, 0.35),
		},
		OnActivated = props.OnActivated,
		OnSelectionGained = props.OnSelectionGained,
	}, {
		Checkmark = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://168702841",
			ImageColor3 = Color3.fromRGB(0, 255, 42),
			Position = UDim2.fromScale(0.82, 0.16),
			Size = UDim2.fromScale(0.2, 0.2),
			Visible = props.Equipped,
			ZIndex = 6,
		}),
		Background = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderColor3 = Color3.new(),
			BorderSizePixel = 0,
			Image = "rbxassetid://80477338860845",
			ImageColor3 = cardColor(entry),
			Position = UDim2.fromScale(0.49, 0.496),
			Size = UDim2.fromScale(0.96, 0.955),
		}, {
			Texture = c("ImageLabel", {
				BackgroundTransparency = 1,
				Image = "rbxassetid://6794188517",
				ImageTransparency = 0.92,
				Size = UDim2.fromScale(1, 1),
			}),
		}),
		NameBand = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = UIConfig.ProgressionStyle.Ink,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 1, -5),
			Size = UDim2.new(1, -12, 0, 36),
			ZIndex = 6,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			ItemName = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 17,
				MinTextSize = 12,
				Wrapped = true,
				Native = {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(4, 2),
					Size = UDim2.new(1, -8, 1, -4),
					Font = Enum.Font.LuckiestGuy,
					Text = string.upper(shortName(entry)),
					TextWrapped = true,
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 7,
				},
			}),
		}),
		Preview = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -36),
			ZIndex = 5,
		}, {
			Content = c(InventoryPreview, {
				ItemId = entry.itemId,
				Category = entry.category,
				Definition = entry.definition,
				ColorId = props.ColorId,
				CostumeId = props.CostumeId,
				ZIndex = 5,
			}),
		}),
	})
end

local function Section(props)
	local cardChildren = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 7),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}),
		UIPadding = c("UIPadding", { PaddingBottom = UDim.new(0.05, 0) }),
	}
	for index, entry in props.Entries do
		cardChildren[entry.id] = c(Card, {
			Entry = entry,
			CardSize = props.CardSize,
			CardHeight = props.CardHeight,
			LayoutOrder = index,
			Equipped = InventoryModel.isEquipped(entry, props.Equipped),
			ColorId = props.Equipped.CharacterColor,
			CostumeId = props.Equipped.CostumeAssets,
			OnActivated = function()
				(props.OnInspect or props.OnEquip)(entry)
			end,
			OnSelectionGained = props.OnSelectionGained,
		})
	end

	return {
		Header = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.new(1, 0, 0, props.HeaderHeight),
		}, {
			Frame = c("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderColor3 = Color3.new(),
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 1, -4),
				Size = UDim2.new(1, 0, 0, 3),
				ZIndex = 4,
			}),
			Title = c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 32,
				Truncate = true,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Size = UDim2.new(1, 0, 1, -8),
					Text = props.Title,
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			}),
		}),
		Content = c("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder + 1,
			Position = UDim2.fromScale(0.225777, 0.0863153),
			Size = UDim2.fromScale(1, 0),
		}, cardChildren),
		Spacer = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder + 2,
			Size = UDim2.new(1, 0, 0, UIConfig.Layout.Inventory.SpacerHeightPx),
		}),
	}
end

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local panelSize = ResponsiveLayout.panelSize(
		safeArea.size,
		UIConfig.Layout.Panels.Inventory,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local inventoryLayout = UIConfig.Layout.Inventory
	local short = not ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
		and safeArea.size.Y <= UIConfig.Layout.ShortLandscapeMaxHeightPx
	local contentTop = math.max(
		panelSize.Y * 0.2902715,
		panelSize.Y * 0.198 + UIConfig.Interaction.MinTargetPx + UIConfig.Layout.InventoryContentGapPx
	)
	local contentBottom = panelSize.Y * 0.9684105
	local cardWidth = panelSize.X * 0.930013 * 0.94076 * 0.94
	local _, cardSize = ResponsiveLayout.gridCellSize(
		cardWidth,
		if short then inventoryLayout.ShortCardSizePx else inventoryLayout.CardMinPx,
		if short then inventoryLayout.ShortCardSizePx else inventoryLayout.CardMaxPx,
		inventoryLayout.CardGapPx,
		inventoryLayout.MaxColumns
	)
	local selectedTab = props.SelectedTab
	local ownedKey = ownershipKey(props.Data)
	local sections = React.useMemo(function()
		local result = {}
		if props.Data == nil then
			return result
		end
		local owned = if props.Data then props.Data.Cosmetics.Owned else {}
		for _, tab in InventoryConfig.Tabs do
			if tab.Id == selectedTab then
				for _, section in tab.Sections do
					local entries = InventoryModel.entries(Cosmetics, owned, section.Category)
					if #entries > 0 then
						table.insert(result, { Title = section.Id, Entries = entries })
					end
				end
				break
			end
		end
		return result
	end, { selectedTab, ownedKey })
	local equipped = if props.Data then props.Data.Cosmetics.Equipped else {}

	local categoryChildren = {
		UIListLayout = c("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		UIPadding = c("UIPadding", {
			PaddingLeft = UDim.new(0.01, 0),
			PaddingRight = UDim.new(0.035, 0),
		}),
	}
	for index, section in sections do
		local elements = Section({
			Title = section.Title,
			Entries = section.Entries,
			Equipped = equipped,
			CardSize = cardSize,
			CardHeight = if short
				then math.min(
					cardSize,
					math.max(
						76,
						math.floor((contentBottom - contentTop) * 0.907841) - inventoryLayout.ShortHeaderHeightPx - 5
					)
				)
				else cardSize,
			HeaderHeight = if short then inventoryLayout.ShortHeaderHeightPx else inventoryLayout.HeaderHeightPx,
			LayoutOrder = (index - 1) * 3,
			OnEquip = props.OnEquip,
			OnInspect = props.OnInspect,
			OnSelectionGained = Selection.scrollIntoView,
		})
		categoryChildren[`CategoryHeader_{section.Title}`] = elements.Header
		categoryChildren[`CategoryContent_{section.Title}`] = elements.Content
		categoryChildren[`Spacer_{section.Title}`] = elements.Spacer
	end

	local tabs = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0.015, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for layoutOrder, definition in InventoryConfig.Tabs do
		local active = selectedTab == definition.Id
		tabs[definition.Id] = c(AnimatedButton, {
			Enabled = props.Data ~= nil,
			Native = {
				BackgroundTransparency = 1,
				Image = if active then "rbxassetid://94748581468730" else "rbxassetid://136021539696619",
				LayoutOrder = layoutOrder,
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(0.181575, 1),
				SliceCenter = Rect.new(198, 228, 841, 468),
				SliceScale = 0.1,
			},
			OnActivated = function()
				props.OnTabChanged(definition.Id)
			end,
		}, {
			TextLabel = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 24,
				Truncate = false,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -12, 0.75, 0),
					Text = definition.Id,
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 2,
				},
			}),
		})
	end

	return c("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://101245842230886",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position or UIConfig.Layout.PagePosition,
		Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
		SliceCenter = Rect.new(0, 278, 885, 655),
	}, {
		Title = c(ResponsiveText, {
			HostName = "Title",
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 62,
			Truncate = true,
			Native = {
				BackgroundColor3 = Color3.fromRGB(63, 63, 63),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.new(),
				BorderSizePixel = 0,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				LayoutOrder = 3,
				Position = UDim2.fromScale(0.12, 0.0540634),
				Size = UDim2.fromScale(0.76, 0.0898091),
				Text = "BACKPACK",
				TextColor3 = Color3.new(1, 1, 1),
			},
		}),
		Main = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://124751224634629",
			LayoutOrder = 3,
			Position = UDim2.new(0.498913, 0, 0, (contentTop + contentBottom) / 2),
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.new(0.930013, 0, 0, math.max(contentBottom - contentTop, 0)),
			SliceCenter = Rect.new(31, 41, 978, 620),
			SliceScale = 0.5,
		}, {
			CategoriesHolder = if props.Data and #sections > 0
				then c("ScrollingFrame", {
					Active = true,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					CanvasSize = UDim2.fromOffset(0, 0),
					Position = UDim2.fromScale(0.0341613, 0.0426996),
					ScrollBarImageColor3 = Color3.new(),
					Size = UDim2.fromScale(0.94076, 0.907841),
				}, categoryChildren)
				else c("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
				}, {
					Status = c(ResponsiveText, {
						MeasurementFont = Enum.Font.LuckiestGuy,
						Native = {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
							Position = UDim2.fromScale(0.5, 0.44),
							Size = UDim2.fromScale(0.75, 0.12),
							Text = if props.Data then "NOTHING HERE YET" else "LOADING BACKPACK…",
							TextColor3 = Color3.new(1, 1, 1),
						},
					}),
					Activity = c(ActivityDots, {
						Active = props.Data == nil,
						Native = {
							Position = UDim2.fromScale(0.5, 0.58),
							Size = UDim2.fromScale(0.12, 0.055),
						},
					}),
				}),
		}),
		Frame = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderColor3 = Color3.new(),
			BorderSizePixel = 0,
			Position = UDim2.new(0.499408, 0, 0, contentTop - 4),
			Size = UDim2.fromScale(0.888649, 0.003),
			ZIndex = 4,
		}),
		Tabs = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.499792, 0.198),
			Size = UDim2.new(0.866389, 0, 0, UIConfig.Interaction.MinTargetPx),
		}, tabs),
	})
end
