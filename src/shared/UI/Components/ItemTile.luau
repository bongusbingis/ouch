--!strict
-- All Backpack categories share one surface and state recipe: the collectible
-- card face (art window, seam rarity tag, CAPS name) on a cream body whose
-- outline is ink at rest, yellow on hover/focus/selection and pink when equipped.
-- Equipped always wins: an equipped card keeps its pink ring and only thickens it
-- under hover/focus, so the "this is on you" cue never flips to yellow.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local PuffyButton = require(script.Parent.PuffyButton)
local Badge = require(script.Parent.Badge)
local InventoryPreview = require(script.Parent.InventoryPreview)
local CollectibleFace = require(script.Parent.CollectibleFace)
local Ribbon = require(script.Parent.RarityRibbon)
local T = require(script.Parent.Parent.Tokens)
local Layout = require(script.Parent.Parent.Models.CollectibleLayout)
local Drag = require(script.Parent.Parent.Services.EmoteAssignmentDrag)
local c, C, S = React.createElement, T.Colors, T.Shape
-- Outfit swatch windows: paler than a rarity window so a full-colour (red, pink)
-- character keeps contrast against its own colour.
local SWATCH_TINT = T.Collectible.WellTint + 0.12

return function(props)
	local buttonRef = React.useRef(nil)
	local entry = props.Entry
	local hovering, setHovering = React.useState(false)
	local seen, setSeen = React.useState(false)
	local ringRef = React.useRef(nil)
	local selected = props.Selected == true
	local swatch = entry.category == "CharacterColor"
	local fill = C.SurfaceWarm
	if props.Locked then
		fill = fill:Lerp(C.WellLine, 0.4)
	end
	local label = Layout.label(entry)
	local size = props.CardSize
	local faceHeight = props.CardHeight - S.LipHeight
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
	local equipped = props.Equipped == true
	local ringColor = if equipped then C.Pink elseif hovering or selected then C.Yellow else C.Ink
	local K = T.Collectible
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
				Thickness = if equipped and hovering then S.StrokePanel else S.StrokeCard,
				Transparency = if selected or equipped or hovering then 0 else 1,
			}),
		}),
		Face = c(CollectibleFace, {
			Width = size,
			Height = faceHeight,
			-- Outfit colours are swatches: the window takes a pale tint of the colour (so
			-- the full-colour character still reads against it) and carries no tier tag.
			Rarity = if swatch then nil else entry.rarity,
			WellColor = if swatch then (entry.definition.PreviewColor or C.Cyan):Lerp(C.Surface, SWATCH_TINT) else nil,
			Name = label,
			NameSize = props.NameSize,
			NameHeight = props.NameHeight,
			ZIndex = 6,
			Art = c(InventoryPreview, {
				ItemId = entry.itemId,
				Category = entry.category,
				Definition = entry.definition,
				ColorId = props.ColorId,
				CostumeId = props.CostumeId,
				Playing = hovering,
				Candy = true,
				ZIndex = 7,
			}),
		}),
		Checkmark = c(Badge, {
			Visible = props.Equipped == true,
			Text = if props.SlotIndex then tostring(props.SlotIndex) else "✓",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = if props.Compact
					then UDim2.new(1, -T.Layout.SmallBadgeSize / 2, 0, T.Layout.SmallBadgeSize / 2)
					else UDim2.new(1, -T.Layout.BadgeSize / 4, 0, T.Layout.BadgeSize / 4),
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
		-- Locked price and Shop hint use the same candy chip as the rarity tag.
		Price = if props.Locked and props.Price
			then c(Ribbon, {
				Text = tostring(props.Price),
				Color = C.Yellow,
				Native = {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromOffset(size - K.Pad - K.TagInset, K.Pad + K.TagInset),
					Size = UDim2.fromOffset(
						Layout.tagWidth(tostring(props.Price), T.Type.Minimum, size - (K.Pad + K.TagInset) * 2),
						K.TagHeight
					),
					ZIndex = 12,
				},
			})
			else nil,
		Tooltip = if props.Locked and hovering
			then c(Ribbon, {
				Text = "GET IT IN THE SHOP",
				Color = C.Surface,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 1, S.LipHeight),
					Size = UDim2.fromOffset(Layout.tagWidth("GET IT IN THE SHOP", T.Type.Minimum, size), K.TagHeight),
					ZIndex = 20,
				},
			})
			else nil,
	})
end
