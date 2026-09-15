--!strict
-- All Backpack categories share one surface and state recipe. Rarity is a named ribbon.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local PuffyButton = require(script.Parent.PuffyButton)
local Badge = require(script.Parent.Badge)
local InventoryPreview = require(script.Parent.InventoryPreview)
local T = require(script.Parent.Parent.Tokens)
local Drag = require(script.Parent.Parent.Services.EmoteAssignmentDrag)
local c, C, S = React.createElement, T.Colors, T.Shape

local function shortName(entry)
	local name = string.gsub(entry.displayName, "^Default%s+", "")
	local suffix = if entry.category == "BallAssets"
		then " Ball"
		elseif entry.category == "HammerAssets" then " Hammer"
		else nil
	if suffix and string.sub(name, -#suffix) == suffix and #name > #suffix then
		return string.sub(name, 1, #name - #suffix)
	end
	return name
end

return function(props)
	local buttonRef = React.useRef(nil)
	local entry = props.Entry
	local hovering, setHovering = React.useState(false)
	local seen, setSeen = React.useState(false)
	local ringRef = React.useRef(nil)
	local selected = props.Selected == true
	local rarity = T.Rarity[entry.rarity] or T.Rarity.Common
	local fill = if entry.category == "CharacterColor" then entry.definition.PreviewColor or C.Cyan else C.NeutralTile
	if props.Locked then
		fill = fill:Lerp(C.WellLine, 0.4)
	end
	local label = shortName(entry)
	local size = props.CardSize
	local labelHeight = T.Layout.NameHeight
	React.useEffect(function()
		local button = buttonRef.current
		local scroller = if button then button:FindFirstAncestorWhichIsA("ScrollingFrame") else nil
		if not button or not scroller then
			return nil
		end
		local function clip()
			local face = button:FindFirstChild("InteractionVisual")
			if face then
				local top, bottom = scroller.AbsolutePosition.Y, scroller.AbsolutePosition.Y + scroller.AbsoluteSize.Y
				face.Visible = button.AbsolutePosition.Y < bottom
					and button.AbsolutePosition.Y + button.AbsoluteSize.Y > top
			end
		end
		clip()
		local a = button:GetPropertyChangedSignal("AbsolutePosition"):Connect(clip)
		local b = scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(clip)
		return function()
			a:Disconnect()
			b:Disconnect()
		end
	end, {})
	React.useEffect(function()
		local stroke = ringRef.current
		if not stroke or not selected or GuiService.ReducedMotionEnabled then
			return nil
		end
		local tween = TweenService:Create(
			stroke,
			TweenInfo.new(T.Motion.RingPeriod, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Thickness = S.StrokePanel }
		)
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, { selected })
	local ringColor = if hovering or selected then C.Yellow elseif props.Equipped then C.Pink else C.Ink
	return c(PuffyButton, {
		Style = "Card",
		ButtonRef = buttonRef,
		Radius = S.RadiusCard,
		Color = fill,
		Shadow = false,
		StrokeColor = ringColor,
		EntranceDelay = (props.LayoutOrder - 1) * T.Motion.Stagger,
		Native = { Size = UDim2.fromOffset(size, props.CardHeight), LayoutOrder = props.LayoutOrder },
		OnPointerDown = function(input)
			if entry.category == "EmoteAssets" and entry.itemId then
				Drag.begin(entry.itemId, input)
			end
		end,
		OnActivated = function()
			if Drag.suppressClick() then
				return
			end
			if props.Locked then
				if props.OnShop then
					props.OnShop()
				end
				return
			end
			props.OnActivated()
		end,
		OnHoverChanged = function(value)
			setHovering(value)
			if value then
				setSeen(true)
			end
		end,
		OnSelectionGained = props.OnSelectionGained,
	}, {
		Texture = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = T.Texture.Swirl,
			ImageColor3 = C.Surface,
			ImageTransparency = 0.95,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
		}),
		SelectionRing = c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10 }, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, S.RadiusCard) }),
			Outline = c("UIStroke", {
				ref = ringRef,
				Color = ringColor,
				Thickness = S.StrokeCard,
				Transparency = if selected or props.Equipped or hovering then 0 else 1,
			}),
		}),
		Rarity = if entry.category ~= "CharacterColor"
			then c("Frame", {
				BackgroundColor3 = rarity.Color,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(T.Layout.CompactGap, S.StrokeCard),
				Size = UDim2.new(
					1,
					-T.Layout.CompactGap * 2
						- (if props.Equipped and not props.Compact then T.Layout.SmallBadgeSize else 0),
					0,
					T.Layout.RarityHeight
				),
				ZIndex = 8,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, S.RadiusPill) }),
				Text = c("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = string.upper(entry.rarity),
					TextSize = T.Type.Minimum,
					Font = T.Type.Label,
					TextColor3 = C.Ink,
					ZIndex = 9,
				}),
			})
			else nil,
		Preview = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(
				T.Layout.CompactGap,
				if entry.category == "CharacterColor" then S.StrokeCard else T.Layout.RarityHeight + S.StrokeCard
			),
			Size = UDim2.new(
				1,
				-T.Layout.CompactGap * 2,
				1,
				-labelHeight
					- (if entry.category == "CharacterColor" then S.StrokeCard else T.Layout.RarityHeight)
					- S.LipHeight
			),
			ZIndex = 6,
		}, {
			Content = c(InventoryPreview, {
				ItemId = entry.itemId,
				Category = entry.category,
				Definition = entry.definition,
				ColorId = props.ColorId,
				CostumeId = props.CostumeId,
				Playing = hovering,
				Candy = true,
				ZIndex = 6,
			}),
		}),
		NameBand = c("Frame", {
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, S.StrokeCard),
			Size = UDim2.new(1, -T.Layout.CompactGap, 0, labelHeight),
			ZIndex = 9,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, S.RadiusPill) }),
			ItemName = c("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(S.StrokeCard, 0),
				Size = UDim2.new(1, -S.StrokeCard * 2, 1, 0),
				Font = T.Type.Label,
				Text = label,
				TextSize = if size < 190 then T.Type.Minimum else T.Type.TileLabel,
				TextWrapped = true,
				TextColor3 = C.Surface,
				ZIndex = 10,
			}),
		}),
		Checkmark = c(Badge, {
			Visible = props.Equipped == true,
			Text = if props.SlotIndex then tostring(props.SlotIndex) else "✓",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = if props.Compact and entry.category ~= "CharacterColor"
					then UDim2.new(1, -16, 0, 48)
					else UDim2.fromScale(0.96, 0.04),
				Size = if props.Compact
					then UDim2.fromOffset(T.Layout.SmallBadgeSize, T.Layout.SmallBadgeSize)
					else nil,
				ZIndex = 12,
			},
		}),
		NewBadge = if props.New and not seen
			then c(Badge, {
				Text = "NEW!",
				TextSize = T.Type.Minimum,
				Native = {
					Position = UDim2.fromOffset(-S.StrokeCard, -S.StrokeCard),
					Size = UDim2.fromOffset(64, 38),
				},
			})
			else nil,
		Lock = if props.Locked
			then c(Badge, { Lock = true, Native = { Position = UDim2.fromOffset(-S.StrokeCard, -S.StrokeCard) } })
			else nil,
		Price = if props.Locked and props.Price
			then c("TextLabel", {
				BackgroundColor3 = C.Yellow,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -S.StrokeCard, 1, -labelHeight),
				Size = UDim2.new(0.7, 0, 0, T.Layout.SmallBadgeSize),
				Text = tostring(props.Price),
				Font = T.Type.Label,
				TextSize = T.Type.Minimum,
				TextColor3 = C.Ink,
				ZIndex = 12,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Outline = c("UIStroke", { Color = C.Ink, Thickness = S.StrokeInner }),
			})
			else nil,
		Tooltip = if props.Locked and hovering
			then c("TextLabel", {
				BackgroundColor3 = C.Ink,
				BorderSizePixel = 0,
				TextColor3 = C.Surface,
				Font = T.Type.Label,
				TextSize = T.Type.Minimum,
				Text = "Get it in the Shop",
				Size = UDim2.new(1, 0, 0, T.Layout.MinTarget),
				Position = UDim2.new(0, 0, 1, S.LipHeight),
				ZIndex = 20,
			}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, S.RadiusPill) }) })
			else nil,
	})
end
