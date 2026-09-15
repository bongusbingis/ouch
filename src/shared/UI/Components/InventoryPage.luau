-- Description: The locker page: renders every cosmetic category as scrollable cards with ownership and equip state and drives the live item preview.

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
local TabPill = require(script.Parent.TabPill)
local Card = require(script.Parent.ItemTile)
local PanelFrame = require(script.Parent.PanelFrame)
local T = require(script.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Motion)
local ActivityDots = require(script.Parent.ActivityDots)
local InventoryPreview = require(script.Parent.InventoryPreview)
local ResponsiveText = require(script.Parent.ResponsiveText)
local BackpackTitle = require(script.Parent.BackpackTitle)
local SectionHeader = require(script.Parent.SectionHeader)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Selection = require(script.Parent.Parent.Services.Selection)
local EmoteSlotRail = require(script.Parent.EmoteSlotRail)
local EmoteWheelController = require(script.Parent.Parent.Services.EmoteWheelController)
local Network = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Network"))

local Well = require(script.Parent.Well)

local ClientRequest = require(ReplicatedStorage.Shared.Game.Data.ClientRequest)
local c = React.createElement

export type Props = {
	Data: any?,
	Position: any?,
	WorldWindowRef: any?,
	HeaderHeight: number?,
	OnEquip: (InventoryModel.Entry) -> (),
	OnInspect: ((InventoryModel.Entry) -> ())?,
	SelectedTab: string,
	OnTabChanged: (string) -> (),
	OnLockedSlot: (() -> ())?,
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

local function Section(props)
	local cardChildren = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, if props.Compact then T.LobbyLandscape.ScrollInset else T.Layout.Gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}),
		UIPadding = c("UIPadding", {
			PaddingBottom = UDim.new(0, T.Layout.Gap),
			PaddingTop = UDim.new(0, if props.Compact then T.LobbyLandscape.ScrollInset else T.Layout.CompactGap),
			PaddingLeft = UDim.new(0, T.Shape.StrokeCard),
		}),
	}
	for index, entry in props.Entries do
		cardChildren[entry.id] = c(Card, {
			Compact = props.Compact,
			Entry = entry,
			Selected = props.SelectedItemId == entry.itemId,
			CardSize = props.CardSize,
			CardHeight = props.CardHeight,
			LayoutOrder = index,
			Equipped = if props.SlotOf
				then props.SlotOf(entry.itemId) ~= nil
				else InventoryModel.isEquipped(entry, props.Equipped),
			SlotIndex = if props.SlotOf then props.SlotOf(entry.itemId) else nil,
			ColorId = props.Equipped.CharacterColor,
			CostumeId = props.Equipped.CostumeAssets,
			OnActivated = function()
				(props.OnInspect or props.OnEquip)(entry)
			end,
			OnSelectionGained = props.OnSelectionGained,
		})
	end

	return {
		Header = c(SectionHeader, {
			Text = props.Title,
			Candy = true,
			HeightPx = props.HeaderHeight,
			LayoutOrder = props.LayoutOrder,
		}),
		Content = c("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder + 1,
			Size = UDim2.fromScale(1, 0),
		}, cardChildren),
		Spacer = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder + 2,
			Size = UDim2.new(1, 0, 0, T.Layout.CompactGap),
		}),
	}
end

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local composition = if props.WorldWindowRef
		then ResponsiveLayout.inventoryComposition(safeArea.size, UIConfig.Layout, props.HeaderHeight)
		else nil
	local panelSize = if composition
		then composition.panel.size
		else ResponsiveLayout.panelSize(
			safeArea.size,
			UIConfig.Layout.Panels.Inventory,
			UIConfig.Layout.PortraitMaxAspect,
			UIConfig.Layout.ShortLandscapeMaxHeightPx
		)
	local inventoryLayout = UIConfig.Layout.Inventory
	local short = not ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
		and safeArea.size.Y <= UIConfig.Layout.ShortLandscapeMaxHeightPx
	local contentTop = if short
		then T.LobbyLandscape.PanelHeader
		else if panelSize.X < T.Layout.WheelMinWidth then T.Layout.CompactWellTop else T.Layout.WellTop
	local contentBottom = if short then panelSize.Y - inventoryLayout.ShortContentBottomPx else panelSize.Y * 0.9684105
	local railGap = inventoryLayout.ShortRailGapPx
	local railPadding = railGap
	local railHeight = math.max(contentBottom - contentTop, 0)
	local tabHeight = #InventoryConfig.Tabs * UIConfig.Interaction.MinTargetPx
	if short and railHeight >= tabHeight then
		local gaps = math.max(#InventoryConfig.Tabs - 1, 0)
		railGap = math.min(railGap, math.floor((railHeight - tabHeight) / math.max(gaps, 1)))
		railPadding = math.min(railPadding, math.floor((railHeight - tabHeight - railGap * gaps) / 2))
	end
	local contentWidth = if short
		then math.max(panelSize.X - inventoryLayout.ShortContentLeftPx - inventoryLayout.ShortContentBottomPx, 1)
		else panelSize.X * 0.930013
	local cardWidth = if short
		then math.max(contentWidth - UIConfig.Layout.InventoryContentGapPx * 2, 1) * 0.955
		else contentWidth * 0.94076 * 0.94
	local _, cardSize = ResponsiveLayout.gridCellSize(
		cardWidth,
		if short
			then T.LobbyLandscape.InventoryCardMin
			elseif panelSize.X < T.Layout.WheelMinWidth then 124
			else T.Layout.CardMin,
		if short then T.LobbyLandscape.InventoryCard else T.Layout.CardMax,
		if short then T.LobbyLandscape.ScrollInset else T.Layout.Gap,
		T.Layout.MaxColumns
	)
	local selectedTab = props.SelectedTab
	local emoteTab = selectedTab == "EMOTES"
	local wheel = EmoteWheelController.useSnapshot()
	local selectedSlot, setSelectedSlot = React.useState(nil :: number?)
	local function slotOf(itemId: string?): number?
		if itemId == nil then
			return nil
		end
		for index = 1, wheel.capacity do
			if wheel.slots[index] == itemId then
				return index
			end
		end
		return nil
	end
	local pendingEmote, setPendingEmote = React.useState(nil)
	local assignmentBusy = React.useRef(false)
	local mounted = React.useRef(true)
	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})
	local assignmentError, setAssignmentError = React.useState(nil)
	local function assignToSlot(index: number, itemId: string?)
		if assignmentBusy.current or index > wheel.capacity then
			return
		end
		assignmentBusy.current = true
		setAssignmentError(nil)
		task.spawn(function()
			local ok, accepted = ClientRequest(Network.call, "SetEmoteSlot", index, itemId)
			assignmentBusy.current = false
			if not mounted.current then
				return
			end
			if ok and accepted then
				setPendingEmote(nil)
				setSelectedSlot(nil)
				Motion.celebrate("EmoteAssets", itemId)
			else
				setAssignmentError("Could not update wheel. Try again.")
			end
		end)
	end
	local function selectSlot(index: number?)
		if index and pendingEmote then
			assignToSlot(index, if wheel.slots[index] == pendingEmote.itemId then nil else pendingEmote.itemId)
		else
			setSelectedSlot(index)
		end
	end
	local function assignEmote(entry: InventoryModel.Entry)
		if selectedSlot then
			assignToSlot(selectedSlot, if wheel.slots[selectedSlot] == entry.itemId then nil else entry.itemId)
		else
			setPendingEmote(entry)
		end
	end
	local onEquip = if emoteTab then assignEmote else props.OnEquip
	local onInspect = if emoteTab then nil else props.OnInspect
	local categoriesRef = React.useRef(nil :: ScrollingFrame?)
	React.useEffect(function()
		local scroller = categoriesRef.current
		if scroller then
			return Motion.tabSwitch(scroller)
		end
		return nil
	end, { selectedTab })
	React.useLayoutEffect(function()
		local scroller = categoriesRef.current
		if scroller then
			scroller.CanvasPosition = Vector2.zero
		end
	end, { selectedTab })
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
					if tab.Id == "EMOTES" then
						local filtered = {}
						for _, entry in entries do
							if not entry.isDefault then
								table.insert(filtered, entry)
							end
						end
						entries = filtered
					end
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
			PaddingTop = UDim.new(
				0,
				if short then T.LobbyLandscape.ScrollPadding else UIConfig.Layout.InventoryContentGapPx
			),
			PaddingBottom = UDim.new(0, UIConfig.Layout.InventoryContentGapPx),
		}),
	}
	if emoteTab then
		categoryChildren.EmoteSlotRail = c(EmoteSlotRail, {
			LayoutOrder = -3,
			Compact = short,
			ContentWidth = cardWidth,
			ColorId = equipped.CharacterColor,
			CostumeId = equipped.CostumeAssets,
			HeaderHeight = if short then T.LobbyLandscape.InventoryHeader else inventoryLayout.HeaderHeightPx,
			SelectedSlot = selectedSlot,
			OnSelectSlot = selectSlot,
			PendingEmote = pendingEmote,
			ErrorText = assignmentError,
			OnAssign = assignToSlot,
			OnLockedSlot = props.OnLockedSlot,
		})
	end
	for index, section in sections do
		local elements = Section({
			Title = section.Title,
			Compact = short,
			Entries = section.Entries,
			Equipped = equipped,
			CardSize = if emoteTab
				then math.min(cardSize, T.Layout.EmoteCardMax)
				elseif selectedTab == "EFFECTS" then math.min(cardSize, T.Layout.EffectCardMax)
				else cardSize,
			CardHeight = if emoteTab
				then math.min(cardSize, T.Layout.EmoteCardMax)
				elseif selectedTab == "EFFECTS" then math.min(cardSize, T.Layout.EffectCardMax)
				else cardSize,
			HeaderHeight = if short then inventoryLayout.ShortHeaderHeightPx else inventoryLayout.HeaderHeightPx,
			LayoutOrder = (index - 1) * 3,
			OnEquip = onEquip,
			OnInspect = onInspect,
			SlotOf = if emoteTab then slotOf else nil,
			SelectedItemId = if pendingEmote then pendingEmote.itemId else nil,
			OnSelectionGained = Selection.scrollIntoView,
		})
		categoryChildren[`CategoryHeader_{section.Title}`] = elements.Header
		categoryChildren[`CategoryContent_{section.Title}`] = elements.Content
		categoryChildren[`Spacer_{section.Title}`] = elements.Spacer
	end

	local tabs = {
		UIListLayout = c("UIListLayout", {
			FillDirection = if short then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			HorizontalFlex = if short then nil else Enum.UIFlexAlignment.Fill,
			Padding = if short then UDim.new(0, railGap) else UDim.new(0.015, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = if short then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Center,
		}),
		Padding = if short
			then c("UIPadding", {
				PaddingTop = UDim.new(0, railPadding),
				PaddingBottom = UDim.new(0, railPadding),
			})
			else nil,
	}
	local narrowTabs = not short and panelSize.X < T.Layout.WheelMinWidth
	if narrowTabs then
		tabs.UIListLayout = nil
	end
	for layoutOrder, definition in InventoryConfig.Tabs do
		tabs[definition.Id] = c(TabPill, {
			Tilt = if short then 0 else nil,
			Enabled = props.Data ~= nil,
			Active = selectedTab == definition.Id,
			Text = definition.Id,
			TextSize = if short or narrowTabs then T.Type.Minimum else T.Type.Tab,
			Native = {
				LayoutOrder = layoutOrder,
				Position = if narrowTabs
					then UDim2.new(
						(layoutOrder - 1) % 2 * 0.51,
						0,
						0,
						math.floor((layoutOrder - 1) / 2) * (T.Layout.MinTarget + T.Layout.CompactGap)
					)
					else nil,
				Size = if short
					then UDim2.new(1, -inventoryLayout.ShortRailGapPx, 0, T.Layout.MinTarget)
					elseif narrowTabs then UDim2.new(0.46, 0, 0, T.Layout.MinTarget)
					else UDim2.fromScale(0.22, 1),
			},
			OnActivated = function()
				props.OnTabChanged(definition.Id)
			end,
			OnSelectionGained = if short then Selection.scrollIntoView else nil,
		})
	end

	return c(PanelFrame, {
		Tilt = if short then 0 else nil,
		Native = {
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = props.Position or (if composition
				then UDim2.fromOffset(
					safeArea.position.X + composition.panel.position.X + panelSize.X / 2,
					safeArea.position.Y + composition.panel.position.Y + panelSize.Y / 2
				)
				else UIConfig.Layout.PagePosition),
			Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
		},
	}, {
		WorldWindow = if composition
			then c("Frame", {
				ref = props.WorldWindowRef,
				Active = false,
				Selectable = false,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(
					composition.world.position.X - composition.panel.position.X,
					composition.world.position.Y - composition.panel.position.Y
				),
				Size = UDim2.fromOffset(composition.world.size.X, composition.world.size.Y),
			})
			else nil,
		Title = c(BackpackTitle, { Compact = short or narrowTabs, Landscape = short }),
		Main = c(Well, {
			Candy = true,
			Native = {
				AnchorPoint = if short then Vector2.zero else Vector2.new(0.5, 0.5),
				LayoutOrder = 3,
				Position = if short
					then UDim2.fromOffset(inventoryLayout.ShortContentLeftPx, contentTop)
					else UDim2.new(0.498913, 0, 0, (contentTop + contentBottom) / 2),
				Size = if short
					then UDim2.fromOffset(contentWidth, math.max(contentBottom - contentTop, 0))
					else UDim2.new(0.930013, 0, 0, math.max(contentBottom - contentTop, 0)),
			},
		}, {
			CategoriesHolder = if props.Data and #sections > 0
				then c("ScrollingFrame", {
					ref = categoriesRef,
					Active = true,
					Selectable = false,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromOffset(0, 0),
					Position = if short
						then UDim2.fromOffset(T.LobbyLandscape.ScrollInset, T.LobbyLandscape.ScrollInset)
						else UDim2.fromScale(0.0341613, 0.0426996),
					ScrollBarImageColor3 = T.Colors.Pink,
					ScrollBarThickness = T.Layout.CompactGap,
					Size = if short
						then UDim2.new(1, -T.LobbyLandscape.ScrollInset * 2, 1, -T.LobbyLandscape.ScrollInset * 2)
						else UDim2.fromScale(0.94076, 0.907841),
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
							TextColor3 = T.Colors.Ink,
							TextStrokeColor3 = UIConfig.ProgressionStyle.Ink,
							TextStrokeTransparency = 0.15,
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
		Tabs = c(if short then "ScrollingFrame" else "Frame", {
			ZIndex = 5,
			Active = short,
			Selectable = false,
			AnchorPoint = if short then Vector2.zero else Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticCanvasSize = if short then Enum.AutomaticSize.Y else nil,
			CanvasSize = if short then UDim2.new() else nil,
			ScrollingDirection = if short then Enum.ScrollingDirection.Y else nil,
			ScrollBarThickness = if short then inventoryLayout.ShortRailGapPx else nil,
			ScrollBarImageColor3 = if short then UIConfig.ProgressionStyle.White else nil,
			Position = if short
				then UDim2.fromOffset(UIConfig.Layout.InventoryContentGapPx, contentTop)
				else UDim2.new(0.5, 0, 0, if narrowTabs then T.Layout.CompactTabsTop else T.Layout.TabsTop),
			Size = if short
				then UDim2.fromOffset(inventoryLayout.ShortRailWidthPx, railHeight)
				else UDim2.new(
					0.866389,
					0,
					0,
					if narrowTabs then T.Layout.MinTarget * 2 + T.Layout.CompactGap else T.Layout.TabHeight
				),
		}, tabs),
	})
end
