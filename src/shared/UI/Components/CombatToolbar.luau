--!strict
-- Two compact candy weapon targets; their hitboxes stay fixed while the faces respond.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local Spring = require(RS.Packages["react-spring"])
local T = require(script.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Motion)
local ViewModel = require(script.Parent.Parent.Models.CombatToolbarViewModel)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local useViewportSize = require(script.Parent.Parent.Hooks.useViewportSize)
local useArenaHUDLayout = require(script.Parent.Parent.Hooks.useArenaHUDLayout)
local CandySurface = require(script.Parent.CandySurface)
local WeaponViewport = require(script.Parent.WeaponViewport)
local Label = require(script.Parent.Arena.HUDLabel)
local UIFeedback = require(script.Parent.Parent.Services.UIFeedback)
local c, C = React.createElement, T.Colors

local function ActionSlot(props)
	local slot = props.Slot
	local kind = slot.state.kind
	local touch = props.Touch
	local pressing, setPressing = React.useState(false)
	local reduced = useReducedMotion()
	local progressVisible = kind == "Cooldown" or kind == "Charging"
	local muted = kind == "Locked" or kind == "Unavailable" or kind == "Disabled"
	local styles = Spring.useSpring({
		Scale = if pressing then 0.94 else 1,
		Progress = if progressVisible then math.clamp(slot.state.progress, 0, 1) else 0,
		config = Motion.Control,
		immediate = reduced,
	})
	return c("ImageButton", {
		Active = slot.interactive,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		Selectable = false,
		LayoutOrder = props.Order,
		Size = UDim2.new(0.5, -10, 1, -12),
		ZIndex = 54,
		[React.Event.Activated] = if slot.interactive
			then function()
				UIFeedback.click()
				props.OnEquip(slot.weapon)
			end
			else nil,
		[React.Event.InputBegan] = function(_, input)
			if slot.interactive and input.UserInputType == Enum.UserInputType.Touch then
				setPressing(true)
			end
		end,
		[React.Event.InputEnded] = function()
			setPressing(false)
		end,
	}, {
		Face = c("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
		}, {
			Scale = c("UIScale", { Scale = styles.Scale }),
			Surface = c(CandySurface, {
				Color = if muted then C.Well else if slot.selected then C.Pink else C.SurfaceWarm,
				LipColor = if slot.selected and not muted then C.PinkLip else C.WellLine,
				Radius = T.ArenaHUD.ControlRadius,
				Shadow = false,
				ZIndex = 0,
			}),
			Icon = c("CanvasGroup", {
				BackgroundTransparency = 1,
				GroupTransparency = if muted then 0.45 else 0,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.02),
				Size = UDim2.new(0.8, 0, 1, -24),
				ZIndex = 5,
			}, {
				Preview = c(WeaponViewport, {
					Weapon = slot.weapon,
					ItemId = props.ItemId,
					Zoom = if slot.weapon == "Hammer" then 1.5 else 1.15,
					ZIndex = 5,
				}),
			}),
			Title = c(Label, {
				Text = if kind == "Locked" then "LOCKED" elseif kind == "Unavailable" then "NO BALL" else slot.title,
				Size = if touch then 16 else 18,
				Minimum = 14,
				Color = if muted then C.InkSoft else C.Ink,
				Native = { Position = UDim2.new(0, 4, 1, -24), Size = UDim2.new(1, -8, 0, 18), ZIndex = 7 },
			}),
			Key = if not touch and slot.inputLabel
				then c(Label, {
					Text = slot.inputLabel,
					Size = 13,
					Native = { Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(32, 18), ZIndex = 7 },
				})
				else nil,
			Selected = if slot.selected
				then c("Frame", {
					BackgroundColor3 = C.Yellow,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 4),
					Size = UDim2.fromOffset(22, 3),
					ZIndex = 7,
				}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) })
				else nil,
			Progress = if progressVisible
				then c("Frame", {
					BackgroundColor3 = C.InkSoft,
					BorderSizePixel = 0,
					Position = UDim2.new(0, 10, 1, -8),
					Size = UDim2.new(1, -20, 0, 3),
					ZIndex = 7,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Fill = c("Frame", {
						BackgroundColor3 = C.Yellow,
						BorderSizePixel = 0,
						Size = styles.Progress:map(function(value)
							return UDim2.fromScale(math.clamp(value, 0, 1), 1)
						end),
						ZIndex = 8,
					}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
				})
				else nil,
		}),
	})
end

export type Props = {
	Model: ViewModel.Model,
	BallItemId: string?,
	HammerItemId: string?,
	OnEquip: (string) -> (),
	RegisterExclusion: (string, any?) -> (),
}

return function(props: Props)
	local ref = React.useRef(nil)
	local viewport = useViewportSize()
	local geometry = useArenaHUDLayout()
	local model = props.Model
	local touch = model.deviceClass == "Touch"
	local layout = ViewModel.layout(viewport, model.deviceClass)
	local position = if touch
		then geometry.toolbar.position
		else Vector2.new(
			(viewport.X - layout.width) / 2,
			geometry.toolbar.position.Y
				+ geometry.toolbar.size.Y
				+ T.ArenaHUD.ToolbarBottom
				- layout.bottomGap
				- layout.height
		)
	local size = if touch then geometry.toolbar.size else Vector2.new(layout.width, layout.height)

	React.useEffect(function()
		local holder = ref.current
		if not model.visible or not touch or not holder then
			props.RegisterExclusion("CombatToolbar", nil)
			return
		end
		local function register()
			local p, s = holder.AbsolutePosition, holder.AbsoluteSize
			props.RegisterExclusion("CombatToolbar", { minX = p.X, minY = p.Y, maxX = p.X + s.X, maxY = p.Y + s.Y })
		end
		register()
		local p = holder:GetPropertyChangedSignal("AbsolutePosition"):Connect(register)
		local s = holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(register)
		return function()
			p:Disconnect()
			s:Disconnect()
			props.RegisterExclusion("CombatToolbar", nil)
		end
	end, { model.visible, touch, props.RegisterExclusion })

	React.useEffect(function()
		if model.visible and ref.current then
			for _, child in ref.current:GetDescendants() do
				if child:IsA("ViewportFrame") and child.CurrentCamera then
					local camera = child.CurrentCamera
					child.CurrentCamera = nil
					child.CurrentCamera = camera
				end
			end
		end
	end, { model.visible })

	local children = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, slot in model.slots do
		children[slot.weapon] = c(ActionSlot, {
			Slot = slot,
			Order = index,
			Touch = touch,
			Width = size.X,
			OnEquip = props.OnEquip,
			ItemId = if slot.weapon == "Hammer" then props.HammerItemId else props.BallItemId,
		})
	end
	return c("Frame", {
		ref = ref,
		BackgroundTransparency = 1,
		Active = model.visible and touch,
		Visible = model.visible,
		Position = UDim2.fromOffset(position.X, position.Y),
		Size = UDim2.fromOffset(size.X, size.Y),
		ZIndex = 50,
	}, children)
end
