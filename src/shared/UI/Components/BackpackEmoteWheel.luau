--!strict
-- Editable eight-sector wheel. The gameplay EmoteWheel controller remains authoritative.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(RS.Packages.react)
local Emotes = require(RS.Config.Cosmetics.Emotes)
local T = require(script.Parent.Parent.Tokens)
local PuffyButton = require(script.Parent.PuffyButton)
local Badge = require(script.Parent.Badge)
local CelebrationAvatar = require(script.Parent.Arena.CelebrationAvatar)
local Controller = require(script.Parent.Parent.Services.EmoteWheelController)
local Drag = require(script.Parent.Parent.Services.EmoteAssignmentDrag)
local SectionHeader = require(script.Parent.SectionHeader)
local EmoteWheelModel = require(script.Parent.Parent.Models.EmoteWheelModel)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local c, C, S = React.createElement, T.Colors, T.Shape

-- Largest ring the Backpack draws; wider panels keep this size and centre it.
local WheelMax = 304

local function polar(degrees, radius)
	local angle = math.rad(degrees)
	return Vector2.new(math.sin(angle), -math.cos(angle)) * radius
end

-- Pulsing yellow target ring that tells the player "this slot is waiting for the emote you picked".
-- Reduced motion keeps it as a still ring.
local function Halo(props)
	local reduced = useReducedMotion()
	local strokeRef, scaleRef = React.useRef(nil), React.useRef(nil)
	React.useEffect(function()
		local stroke, scale = strokeRef.current, scaleRef.current
		if stroke == nil or scale == nil then
			return nil
		end
		if reduced then
			stroke.Transparency = 0.1
			scale.Scale = 1
			return nil
		end
		local info = TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		local strokeTween = TweenService:Create(stroke, info, { Transparency = 0.75 })
		local scaleTween = TweenService:Create(scale, info, { Scale = 1.07 })
		strokeTween:Play()
		scaleTween:Play()
		return function()
			strokeTween:Cancel()
			scaleTween:Cancel()
		end
	end, { reduced })
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, props.Grow, 1, props.Grow),
		ZIndex = props.ZIndex,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, props.Radius) }),
		Stroke = c("UIStroke", { Color = C.Yellow, Thickness = S.StrokeCard, ref = strokeRef }),
		Scale = c("UIScale", { ref = scaleRef }),
	})
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
	local label = if props.Locked then "LOCKED" elseif clip then string.upper(clip.DisplayName) else "EMPTY"
	local fill = if props.Selected then C.Pink elseif props.Locked then C.WellLine elseif clip then C.Cyan else C.Surface
	local wheelRadius = props.WheelRadius
	-- Slot 1..8 sit where the gameplay wheel puts them, so the numbers match in the arena.
	local angle = EmoteWheelModel.centerAngle(props.Index, Emotes.MaxSlots)
	local center = polar(angle, wheelRadius * 0.7)
	local slotPx = math.round(wheelRadius * 0.52)
	local native = {
		LayoutOrder = props.Index,
		BackgroundTransparency = 1,
		AnchorPoint = if props.Radial then Vector2.new(0.5, 0.5) else Vector2.zero,
		Position = if props.Radial then UDim2.new(0.5, center.X, 0.5, center.Y) else nil,
		Size = if props.Radial
			then UDim2.fromOffset(slotPx, slotPx)
			else UDim2.new(0.5, -T.Layout.CompactGap / 2 - 1, 0, 64),
		ZIndex = if hover then 8 else 5,
	}
	local content = {}
	if props.Radial then
		-- A true annular sector, assembled from overlapping native strips. Fill is
		-- inset inside the ink silhouette, with a lower candy lip and rounded ends.
		local arc = {}
		local step = 39 / T.Layout.WheelSegments
		local mid = wheelRadius * 0.69
		local thick = wheelRadius * 0.56
		local chord = 2 * wheelRadius * math.sin(math.rad(step / 2)) + 2
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
		-- The figure is framed larger than the hitbox (it is mostly head-room) and bobs only on hover or
		-- while its slot is lit; every emote shares the rig, so the name and hover motion tell them apart.
		content.Preview = if clip
			then c(CelebrationAvatar, {
				EmoteId = props.EmoteId,
				ColorId = props.ColorId,
				CostumeId = props.CostumeId,
				Playing = hover or props.Selected,
				Static = not (hover or props.Selected),
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0.5, -S.LipHeight / 2),
					Size = UDim2.fromScale(1.3, 1.3),
				},
				ZIndex = 6,
			})
			else nil
		content.Empty = if props.Locked
			then c(Badge, {
				Lock = true,
				Color = C.Surface,
				Tilt = 0,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0.5, -S.LipHeight / 2),
					Size = UDim2.fromOffset(T.Layout.SmallBadgeSize + 4, T.Layout.SmallBadgeSize + 4),
					ZIndex = 6,
				},
			})
			elseif not clip then c("TextLabel", {
				BackgroundTransparency = 1,
				Font = T.Type.Display,
				Text = "+",
				TextSize = T.Type.Section,
				TextColor3 = C.Ink,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 6,
			})
			else nil
		content.Halo = if props.Wanted
			then c(Halo, { Grow = 14, Radius = math.round(slotPx / 2) + 7, ZIndex = 7 })
			else nil
		local number = polar(angle, wheelRadius + 1) - center
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
	local z = native.ZIndex + 7
	return c(PuffyButton, {
		Native = native,
		ButtonRef = ref,
		Color = fill,
		Shadow = false,
		Radius = S.RadiusCard,
		OnActivated = props.OnActivated,
		OnHoverChanged = setHover,
	}, {
		Number = c(Badge, {
			Text = tostring(props.Index),
			TextSize = T.Type.Minimum,
			Color = if props.Selected then C.Yellow else C.Surface,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(6, 8),
				Size = UDim2.fromOffset(T.Layout.SmallBadgeSize, T.Layout.SmallBadgeSize),
				ZIndex = z + 1,
			},
		}),
		Name = c("TextLabel", {
			BackgroundTransparency = 1,
			Font = T.Type.Display,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -16, 1, -S.LipHeight),
			Text = label,
			TextColor3 = C.Ink,
			TextSize = T.Type.Minimum,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = z,
		}),
		Halo = if props.Wanted then c(Halo, { Grow = 8, Radius = S.RadiusCard + 4, ZIndex = z + 1 }) else nil,
	})
end

-- Scrolls the nearest ScrollingFrame so the whole rail (heading included) is on screen.
local function revealRail(frame: GuiObject, headerPx: number)
	local scroller: Instance? = frame.Parent
	while scroller and not scroller:IsA("ScrollingFrame") do
		scroller = scroller.Parent
	end
	if scroller == nil or not scroller:IsA("ScrollingFrame") or scroller.AbsoluteWindowSize.Y <= 0 then
		return
	end
	local position = scroller.CanvasPosition
	local window = scroller.AbsoluteWindowSize.Y
	local top = frame.AbsolutePosition.Y - scroller.AbsolutePosition.Y + position.Y - headerPx
	local bottom = top + headerPx + frame.AbsoluteSize.Y
	local target = position.Y
	if top < position.Y or bottom - top > window then
		target = top
	elseif bottom > position.Y + window then
		target = bottom - window
	end
	scroller.CanvasPosition =
		Vector2.new(position.X, math.clamp(target, 0, math.max(0, scroller.AbsoluteCanvasSize.Y - window)))
end

return function(props)
	local controllerWheel = Controller.useSnapshot()
	local wheel = props.WheelSnapshot or controllerWheel
	local radial = props.ContentWidth >= T.Layout.WheelMinWidth and not props.Compact
	-- The ring grows with the panel (up to WheelMax) so wide Backpacks do not leave it floating in dead space.
	local wheelSize = if radial
		then math.clamp(2 * math.floor(props.ContentWidth * 0.23), T.Layout.WheelSize, WheelMax)
		else 0
	local wheelRadius = wheelSize / 2
	local edge = T.Layout.SmallBadgeSize / 2 + 2 -- number stickers sit on the rim and overhang it
	local rows = math.ceil(Emotes.MaxSlots / 2)
	local height = if radial then wheelSize + edge * 2 else rows * 64 + (rows - 1) * T.Layout.CompactGap
	local pending = props.PendingEmote ~= nil
	local railRef = React.useRef(nil)
	-- Picking an emote means "now choose a slot": bring the wheel on screen, since the cards are far below it.
	React.useEffect(function()
		local frame = railRef.current
		if not pending or frame == nil then
			return nil
		end
		local cancelled = false
		task.defer(function()
			if not cancelled and frame.Parent then
				revealRail(frame, props.HeaderHeight or 0)
			end
		end)
		return function()
			cancelled = true
		end
	end, { pending })
	local children = {}
	if not radial then
		children.Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
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
			Wanted = pending and not locked,
			Radial = radial,
			WheelRadius = wheelRadius,
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
		local hub = math.round(wheelRadius * 0.62)
		children.Hub = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.Pink,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(hub, hub),
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
			}, { Outline = c("UIStroke", { Color = C.Ink, Thickness = T.Type.Outline }) }),
		})
	end
	local hint = props.ErrorText
		or (
			if props.PendingEmote
				then props.PendingEmote.displayName .. " → choose a slot"
				elseif props.SelectedSlot then "Slot " .. props.SelectedSlot .. " → choose an emote"
				else "Pick an emote, then a slot. Drag to assign on desktop."
		)
	local top = if radial then edge else T.Layout.CompactGap
	local contentHeight = if radial then height else top + height + T.Layout.CompactGap + T.Layout.MinTarget
	return c(React.Fragment, nil, {
		Header = c(
			SectionHeader,
			{ Text = "YOUR WHEEL", Candy = true, HeightPx = props.HeaderHeight, LayoutOrder = props.LayoutOrder }
		),
		Content = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, contentHeight),
			LayoutOrder = props.LayoutOrder + 1,
			ref = railRef,
		}, {
			Wheel = c("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(if radial then 0.3 else 0.5, 0, 0, top),
				Size = if radial then UDim2.fromOffset(wheelSize, wheelSize) else UDim2.new(1, 0, 0, height),
			}, children),
			Hint = c("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = if radial then Vector2.new(0, 0.5) else Vector2.zero,
				Position = if radial
					then UDim2.fromScale(0.58, 0.5)
					else UDim2.fromOffset(0, top + height + T.Layout.CompactGap),
				Size = if radial then UDim2.fromScale(0.38, 0.5) else UDim2.new(1, 0, 0, T.Layout.MinTarget),
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
