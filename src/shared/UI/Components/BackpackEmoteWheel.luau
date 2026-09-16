--!strict
-- Editable eight-sector wheel. The gameplay EmoteWheel controller remains authoritative.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local Emotes = require(RS.Config.Cosmetics.Emotes)
local T = require(script.Parent.Parent.Tokens)
local PuffyButton = require(script.Parent.PuffyButton)
local Badge = require(script.Parent.Badge)
local CelebrationAvatar = require(script.Parent.Arena.CelebrationAvatar)
local Controller = require(script.Parent.Parent.Services.EmoteWheelController)
local Drag = require(script.Parent.Parent.Services.EmoteAssignmentDrag)
local SectionHeader = require(script.Parent.SectionHeader)
local c, C, S = React.createElement, T.Colors, T.Shape

local function polar(degrees, radius)
	local angle = math.rad(degrees)
	return Vector2.new(math.sin(angle), -math.cos(angle)) * radius
end

local function Slot(props)
	local ref = React.useRef(nil)
	local hover, setHover = React.useState(false)
	React.useEffect(function()
		if ref.current and not props.Locked then
			return Drag.register(ref.current, props.OnDrop)
		end
		return nil
	end, { props.Locked, props.OnDrop })
	local clip = props.EmoteId and Emotes.Clips[props.EmoteId]
	local label = if props.Locked then "Locked" elseif clip then clip.DisplayName else "Empty"
	local fill = if props.Selected then C.Pink elseif props.Locked then C.WellLine elseif clip then C.Cyan else C.Surface
	local radius = T.Layout.WheelSize / 2
	local angle = (props.Index - 1) * 45
	local center = polar(angle, radius * 0.7)
	local native = {
		LayoutOrder = props.Index,
		BackgroundTransparency = 1,
		AnchorPoint = if props.Radial then Vector2.new(0.5, 0.5) else Vector2.zero,
		Position = if props.Radial then UDim2.new(0.5, center.X, 0.5, center.Y) else nil,
		Size = if props.Radial then UDim2.fromOffset(58, 58) else UDim2.new(0.48, 0, 0, 64),
		ZIndex = if hover then 8 else 5,
	}
	local content = {}
	if props.Radial then
		-- A true annular sector, assembled from overlapping native strips. Fill is
		-- inset inside the ink silhouette, with a lower candy lip and rounded ends.
		local arc = {}
		local step = 39 / T.Layout.WheelSegments
		local mid = radius * 0.69
		local thick = radius * 0.56
		local chord = 2 * radius * math.sin(math.rad(step / 2)) + 2
		for index = 0, T.Layout.WheelSegments - 1 do
			local a = angle - 19.5 + step * (index + 0.5)
			local pos = polar(a, mid) - center
			for layer = 1, 3 do
				local inset = if layer == 1 then 0 else S.StrokeCard * 2
				arc["Arc" .. index .. "_" .. layer] = c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BorderSizePixel = 0,
					BackgroundColor3 = if layer == 1
						then (if props.Selected or hover then C.Yellow else C.Ink)
						elseif layer == 2 then fill:Lerp(C.Ink, 0.2)
						else fill,
					Position = UDim2.new(0.5, pos.X, 0.5, pos.Y - (if layer == 3 then S.LipHeight / 2 else 0)),
					Rotation = a,
					Size = UDim2.fromOffset(chord, thick - inset - (if layer == 3 then S.LipHeight else 0)),
					ZIndex = layer,
				}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, S.StrokeInner) }) })
			end
		end
		content.Sector = c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, arc)
		content.Preview = if clip
			then c(CelebrationAvatar, {
				EmoteId = props.EmoteId,
				ColorId = props.ColorId,
				CostumeId = props.CostumeId,
				Playing = hover,
				Static = not hover,
				Native = { Position = UDim2.fromScale(0.1, 0.05), Size = UDim2.fromScale(0.8, 0.9) },
				ZIndex = 6,
			})
			else nil
		content.Empty = if not clip
			then c("TextLabel", {
				BackgroundTransparency = 1,
				Font = T.Type.Display,
				Text = if props.Locked then "▣" else "+",
				TextSize = T.Type.Section,
				TextColor3 = C.Ink,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 6,
			})
			else nil
		local number = polar(angle, radius + 1) - center
		content.Number = c(Badge, {
			Text = tostring(props.Index),
			TextSize = T.Type.Minimum,
			Color = if props.Selected then C.Yellow else C.Surface,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, number.X, 0.5, number.Y),
				Size = UDim2.fromOffset(T.Layout.SmallBadgeSize, T.Layout.SmallBadgeSize),
				ZIndex = 9,
			},
		})
		local AnimatedButton = require(script.Parent.AnimatedButton)
		return c(AnimatedButton, {
			Native = native,
			ButtonRef = ref,
			Style = "Card",
			OnActivated = props.OnActivated,
			OnHoverChanged = setHover,
		}, content)
	end
	return c(PuffyButton, {
		Native = native,
		ButtonRef = ref,
		Color = fill,
		Shadow = false,
		Radius = S.RadiusCard,
		Text = tostring(props.Index) .. "  " .. label,
		TextColor = C.Ink,
		TextSize = T.Type.Minimum,
		Wrapped = true,
		OnActivated = props.OnActivated,
		OnHoverChanged = setHover,
	})
end

return function(props)
	local controllerWheel = Controller.useSnapshot()
	local wheel = props.WheelSnapshot or controllerWheel
	local radial = props.ContentWidth >= T.Layout.WheelMinWidth and not props.Compact
	local height = if radial then T.Layout.WheelSize + T.Layout.WheelRowGap else 4 * (64 + T.Layout.CompactGap)
	local children = {}
	if not radial then
		children.Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, T.Layout.CompactGap),
		})
	end
	for index = 1, Emotes.MaxSlots do
		local locked = index > wheel.capacity
		children["Slot" .. index] = c(Slot, {
			Index = index,
			EmoteId = wheel.slots[index],
			ColorId = props.ColorId,
			CostumeId = props.CostumeId,
			Locked = locked,
			Selected = props.SelectedSlot == index,
			Radial = radial,
			OnActivated = function()
				if locked then
					if props.OnLockedSlot then
						props.OnLockedSlot()
					end
					return
				end
				props.OnSelectSlot(if props.SelectedSlot == index then nil else index)
			end,
			OnDrop = function(itemId)
				if props.OnAssign then
					props.OnAssign(index, itemId)
				end
			end,
		})
	end
	if radial then
		children.Hub = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.Pink,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(62, 62),
			ZIndex = 7,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Outline = c("UIStroke", { Color = C.Ink, Thickness = S.StrokeCard }),
			Label = c("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = if props.PendingEmote then "PICK A\nSLOT" else "YOUR\nMOVES",
				Font = T.Type.Display,
				TextSize = T.Type.Minimum,
				TextColor3 = C.Surface,
				ZIndex = 8,
			}),
		})
	end
	local hint = props.ErrorText
		or (
			if props.PendingEmote
				then props.PendingEmote.displayName .. " → choose a slot"
				elseif props.SelectedSlot then "Slot " .. props.SelectedSlot .. " → choose an emote"
				else "Pick an emote, then a slot. Drag to assign on desktop."
		)
	return c(React.Fragment, nil, {
		Header = c(
			SectionHeader,
			{ Text = "YOUR WHEEL", Candy = true, HeightPx = props.HeaderHeight, LayoutOrder = props.LayoutOrder }
		),
		Content = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, height + (if radial then 0 else 58)),
			LayoutOrder = props.LayoutOrder + 1,
		}, {
			Wheel = c("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(if radial then 0.3 else 0.5, 0, 0, T.Layout.CompactGap),
				Size = UDim2.new(if radial then 0.6 else 1, 0, 0, height),
			}, children),
			Hint = c("TextLabel", {
				BackgroundTransparency = 1,
				Position = if radial
					then UDim2.fromScale(0.63, 0.25)
					else UDim2.fromOffset(0, height + T.Layout.CompactGap),
				Size = if radial then UDim2.fromScale(0.35, 0.5) else UDim2.new(1, 0, 0, T.Layout.MinTarget),
				Text = hint,
				Font = T.Type.Label,
				TextSize = T.Type.Minimum,
				TextColor3 = if props.ErrorText then C.PinkLip else C.InkSoft,
				TextWrapped = true,
			}),
		}),
		Spacer = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, T.Layout.CompactGap),
			LayoutOrder = props.LayoutOrder + 2,
		}),
	})
end
