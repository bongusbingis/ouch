-- Name: EmoteWheel.luau
-- Author: Jack C.
-- Description: Renders the radial emote selector from the controller's snapshot as a solid segmented ring with a hollow centre that keeps the character visible, the hovered wedge lit in cyan, the emote's name in display type below the ring, a release hint, and on touch devices the small wheel button that opens it.
-- Created: 2026-09-09
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local Motion = require(script.Parent.Parent.Motion)
local EmoteWheelModel = require(script.Parent.Parent.Models.EmoteWheelModel)
local EmoteWheelController = require(script.Parent.Parent.Services.EmoteWheelController)
local ModalSurface = require(script.Parent.ModalSurface)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local useViewportSize = require(script.Parent.Parent.Hooks.useViewportSize)
local T = require(script.Parent.Parent.Tokens)
local PuffyButton = require(script.Parent.PuffyButton)
local Badge = require(script.Parent.Badge)
local useArenaHUDLayout = require(script.Parent.Parent.Hooks.useArenaHUDLayout)
local usePreferredTextSize = require(script.Parent.Parent.Hooks.usePreferredTextSize)
local Config = ReplicatedStorage:WaitForChild("Config")
local UI = require(Config:WaitForChild("Interface"):WaitForChild("UI"))
local Input = require(Config:WaitForChild("Interface"):WaitForChild("Input"))
local WheelConfig = require(Config:WaitForChild("Interface"):WaitForChild("EmoteWheel"))
local Cosmetics = require(Config:WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))

local c = React.createElement
local C, S = T.Colors, T.Shape

export type TouchRect = { minX: number, minY: number, maxX: number, maxY: number }
type RegisterTouchExclusion = (TouchRect?) -> (boolean, string?)

-- Only the currently mounted touch button may clear the shared Combat key.
local activeTouchOwner: {}? = nil

local function thumbnailFor(emoteId: string?): string?
	local item = if emoteId then Cosmetics.Items[emoteId] else nil
	local thumbnail = if item then item.Thumbnail else nil
	return if type(thumbnail) == "string" and thumbnail ~= "" then thumbnail else nil
end

local function polar(angleDeg: number, radius: number): (number, number)
	local radians = math.rad(angleDeg)
	return math.round(math.sin(radians) * radius), math.round(-math.cos(radians) * radius)
end

type Geometry = {
	radius: number,
	inner: number,
	thickness: number,
	mid: number,
	segments: number,
	step: number,
	chord: number,
}

local function geometry(layout: EmoteWheelModel.Layout): Geometry
	local radius = layout.radius
	local inner = radius * WheelConfig.HoleFraction
	local mid = (radius + inner) / 2
	local step = 360 / WheelConfig.RingSegments
	return {
		radius = radius,
		inner = inner,
		thickness = radius - inner,
		mid = mid,
		segments = WheelConfig.RingSegments,
		step = step,
		chord = 2 * mid * math.sin(math.rad(step / 2)) + 6,
	}
end

-- The annulus is built from thin rotated rectangles so the wedges are real
-- arcs without any image asset. Each rectangle takes the colour of the sector
-- its centre angle falls in.
local function ringSegments(
	geo: Geometry,
	layout: EmoteWheelModel.Layout,
	sectors: { EmoteWheelModel.Sector },
	capacity: number,
	selected: number?,
	z: number
)
	local children = {}
	for index = 0, geo.segments - 1 do
		local angle = index * geo.step + geo.step / 2
		local x, y = polar(angle, layout.radius)
		local sectorIndex = EmoteWheelModel.hitTest(Vector2.new(x, y), layout, capacity)
		local sector = if sectorIndex then sectors[sectorIndex] else nil
		local isSelected = sectorIndex ~= nil and sectorIndex == selected
		local filled = sector ~= nil and sector.filled
		local mx, my = polar(angle, geo.mid)
		local fill = if isSelected then C.Pink elseif filled then C.Cyan else C.Surface
		local size = UDim2.fromOffset(math.round(geo.chord), math.round(geo.thickness))
		-- Ink (or yellow when lit) rim under the candy fill, as on the Backpack wheel.
		children["Rim" .. index] = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if isSelected then C.Yellow else C.Ink,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, mx, 0.5, my),
			Rotation = angle,
			Size = UDim2.fromOffset(math.round(geo.chord), math.round(geo.thickness) + S.StrokeCard * 2),
			ZIndex = z,
		})
		children["Seg" .. index] = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = fill,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, mx, 0.5, my),
			Rotation = angle,
			Size = size,
			ZIndex = z + 1,
		})
	end
	return children
end

local function dividers(geo: Geometry, sectors: { EmoteWheelModel.Sector }, z: number)
	local children = {}
	for _, sector in sectors do
		local angle = sector.startAngleDeg
		local x, y = polar(angle, geo.mid)
		children["Divider" .. sector.index] = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, x, 0.5, y),
			Rotation = angle,
			Size = UDim2.fromOffset(S.StrokeInner, math.round(geo.thickness) + S.StrokeCard * 2),
			ZIndex = z + 1,
		})
	end
	return children
end

local function Wedge(props: {
	Sector: EmoteWheelModel.Sector,
	Geometry: Geometry,
	Capacity: number,
	TextPx: number,
	Selected: boolean,
	ShowPlus: boolean,
	ZIndex: number,
})
	local sector = props.Sector
	local geo = props.Geometry
	local x, y = polar(sector.centerAngleDeg, geo.mid)
	local bx, by = polar(sector.centerAngleDeg, geo.radius + 4)
	local arc = 360 / math.max(props.Capacity, 1)
	local boxWidth = math.round(math.min(2 * geo.mid * math.sin(math.rad(arc / 2)) * 0.82, geo.thickness * 1.9))
	local boxHeight = math.round(geo.thickness * 0.86)
	local thumbnail = if sector.filled then thumbnailFor(sector.emoteId) else nil
	return c(React.Fragment, nil, {
		Content = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, x, 0.5, y),
			Size = UDim2.fromOffset(boxWidth, boxHeight),
			ZIndex = props.ZIndex,
		}, {
			Thumbnail = if thumbnail
				then c("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = thumbnail,
					ImageColor3 = C.Surface,
					Position = UDim2.fromScale(0.5, 0.5),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.9, 0.9),
					ZIndex = props.ZIndex,
				})
				else c("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Font = T.Type.Display,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					Text = if sector.filled then sector.displayName else "",
					TextColor3 = C.Ink,
					TextSize = props.TextPx,
					TextWrapped = true,
					ZIndex = props.ZIndex,
				}),
			EmptyMark = if sector.filled
				then nil
				else c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					-- Assignable wheels show a "+" well; read-only (arena) wheels show a
					-- hollow ring so a vacant slot never reads as a stray dot.
					BackgroundColor3 = if props.Selected then C.Surface else C.Well,
					BackgroundTransparency = if props.ShowPlus then 0 else 1,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(math.round(geo.thickness * 0.5), math.round(geo.thickness * 0.5)),
					ZIndex = props.ZIndex,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Ring = if props.ShowPlus
						then nil
						else c("UIStroke", {
							Color = if props.Selected then C.Surface else C.WellLine,
							Thickness = S.StrokeCard,
						}),
					Plus = if not props.ShowPlus
						then nil
						else c("TextLabel", {
							BackgroundTransparency = 1,
							Font = T.Type.Display,
							Size = UDim2.fromScale(1, 1),
							Text = "+",
							TextColor3 = C.Ink,
							TextSize = T.Type.Body,
							ZIndex = props.ZIndex + 1,
						}),
				}),
		}),
		Number = c(Badge, {
			Text = tostring(sector.index),
			TextSize = T.Type.HudMinimum,
			Color = if props.Selected then C.Yellow else C.Surface,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, bx, 0.5, by),
				Size = UDim2.fromOffset(T.Layout.SmallBadgeSize, T.Layout.SmallBadgeSize),
				ZIndex = props.ZIndex + 1,
			},
		}),
	})
end

local function TouchButton(props: {
	SizePx: number?,
	BottomPx: number,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number,
	RegisterTouchExclusion: RegisterTouchExclusion?,
})
	local ref = React.useRef(nil)
	local owner = React.useRef({})
	local registered = React.useRef(false)
	local available, setAvailable = React.useState(false)
	React.useEffect(function()
		local positionConnection: RBXScriptConnection? = nil
		local sizeConnection: RBXScriptConnection? = nil
		local cancelled = false
		local faulted = false
		local callback = props.RegisterTouchExclusion
		local function clear()
			if activeTouchOwner ~= owner.current then
				return
			end
			activeTouchOwner = nil
			if callback then
				local ok, success, reason = pcall(callback, nil)
				if not ok or not success then
					faulted = true
					warn(
						`[EmoteWheel] ArenaEmoteRoot.EmoteWheel.RegisterTouchExclusion: failed to clear EmoteButton touch exclusion: {if ok
							then tostring(reason)
							else tostring(success)}; restore the Arena Combat registration`
					)
				end
			end
		end
		local function fail(reason: string)
			if faulted or cancelled then
				return
			end
			faulted = true
			registered.current = false
			setAvailable(false)
			warn(
				`[EmoteWheel] ArenaEmoteRoot.EmoteWheel.RegisterTouchExclusion: required EmoteButton touch exclusion failed: {reason}; restore the Arena Combat registration`
			)
			clear()
		end
		local function register(button: GuiButton)
			if cancelled or faulted then
				return
			end
			local p, s = button.AbsolutePosition, button.AbsoluteSize
			if callback == nil then
				fail("visible touch button has no required callback")
				return
			end
			if s.X <= 0 or s.Y <= 0 then
				registered.current = false
				setAvailable(false)
				clear()
				return
			end
			registered.current = false
			local rect: TouchRect = { minX = p.X, minY = p.Y, maxX = p.X + s.X, maxY = p.Y + s.Y }
			activeTouchOwner = owner.current
			local ok, success, reason = pcall(callback, rect)
			if not ok or not success then
				fail(if ok then tostring(reason) else tostring(success))
				return
			end
			registered.current = true
			setAvailable(true)
		end
		local function attach(deferred: boolean)
			if cancelled or faulted then
				return
			end
			local button = ref.current
			if button == nil then
				if deferred then
					fail("touch button ref was unavailable after mount")
				else
					task.defer(function()
						attach(true)
					end)
				end
				return
			end
			register(button)
			positionConnection = button:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
				register(button)
			end)
			sizeConnection = button:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				register(button)
			end)
		end
		attach(false)
		return function()
			cancelled = true
			registered.current = false
			if positionConnection then
				positionConnection:Disconnect()
			end
			if sizeConnection then
				sizeConnection:Disconnect()
			end
			clear()
		end
	end, { props.RegisterTouchExclusion })
	local px = props.SizePx or WheelConfig.TouchButtonPx
	local dots = {}
	for index = 1, 4 do
		local x, y = polar((index - 1) * 90, px * 0.19)
		dots["Dot" .. index] = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = T.Colors.Ink,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, x, 0.5, y - 3),
			Size = UDim2.fromOffset(6, 6),
			ZIndex = props.ZIndex + 6,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	return c(PuffyButton, {
		ButtonRef = ref,
		Color = T.Colors.SurfaceWarm,
		LipColor = T.Colors.WellLine,
		Shadow = false,
		Native = {
			AnchorPoint = props.AnchorPoint or Vector2.new(1, 1),
			Position = props.Position or UDim2.new(1, -16, 1, -props.BottomPx),
			Size = UDim2.fromOffset(px, px),
			Visible = available,
			Selectable = false,
			ZIndex = props.ZIndex,
		},
		Enabled = available,
		OnActivated = function()
			if registered.current and activeTouchOwner == owner.current then
				EmoteWheelController.openTouch()
			end
		end,
	}, dots)
end

export type Props = {
	ShowTouchButton: boolean?,
	RegisterTouchExclusion: RegisterTouchExclusion?,
	TouchButtonPosition: UDim2?,
	TouchButtonAnchor: Vector2?,
	-- "BesideToolbar" parks the button just left of the combat toolbar, in the
	-- utility row at the bottom centre where neither thumb is steering or aiming.
	TouchButtonPlacement: ("Default" | "BesideToolbar")?,
	EmptySlotsAssignable: boolean?,
	Snapshot: any?,
	ZIndex: number?,
}

return function(props: Props)
	local hudLayout, rootOrigin = useArenaHUDLayout(Enum.ScreenInsets.CoreUISafeInsets)
	local controllerSnapshot = EmoteWheelController.useSnapshot()
	local snapshot = props.Snapshot or controllerSnapshot
	local viewport = useViewportSize()
	local reducedMotion = useReducedMotion()
	local preferred = usePreferredTextSize()
	local textScale = UI.Text.PreferredScale[preferred.Name] or 1
	local z = props.ZIndex or 900
	local short = viewport.Y <= WheelConfig.ShortViewportMaxPx
	local layout = EmoteWheelModel.layout(viewport, snapshot.capacity, EmoteWheelModel.captionReserve(viewport))
	local geo = geometry(layout)
	local sectors = EmoteWheelModel.sectors(snapshot.slots, snapshot.capacity)
	local styles = ReactSpring.useSpring({
		Alpha = if snapshot.open then 1 else 0,
		Scale = if snapshot.open then 1 else WheelConfig.OpenScaleFrom,
		config = Motion.Modal,
		immediate = reducedMotion,
	})
	local caption = EmoteWheelModel.caption(sectors, snapshot.selected)
	local nameText = caption.name
	local nameColor = if caption.kind == "filled"
		then C.Yellow
		elseif caption.kind == "empty" or caption.kind == "none" then C.Well
		else C.Surface
	-- Only promise "play" when releasing would actually play an emote.
	local hint = if caption.kind == "none"
		then "EQUIP EMOTES IN BACKPACK"
		elseif caption.kind == "empty" then "EQUIP ONE IN BACKPACK"
		elseif snapshot.deviceClass == "Gamepad" then "RELEASE "
			.. string.upper(Input.EmoteWheel.GamepadLabel)
			.. " TO PLAY"
		elseif snapshot.deviceClass == "Keyboard" then "RELEASE " .. Input.EmoteWheel.KeyboardLabel .. " TO PLAY"
		else "DRAG AND RELEASE TO PLAY"
	local wedges = {}
	for _, sector in sectors do
		wedges["Wedge" .. sector.index] = c(Wedge, {
			Sector = sector,
			Geometry = geo,
			Capacity = snapshot.capacity,
			TextPx = math.max(math.round(layout.labelTextPx * textScale), T.Type.HudMinimum),
			Selected = snapshot.selected == sector.index,
			ShowPlus = props.EmptySlotsAssignable ~= false,
			ZIndex = z + 5,
		})
	end
	local blocked = EmoteWheelController.useBlocked()
	local touchVisible = props.ShowTouchButton ~= false
		and snapshot.deviceClass == "Touch"
		and not snapshot.open
		and not blocked
	local touchPosition, touchAnchor = props.TouchButtonPosition, props.TouchButtonAnchor
	if props.TouchButtonPlacement == "BesideToolbar" then
		local position = hudLayout.emote.position - rootOrigin
		touchPosition, touchAnchor = UDim2.fromOffset(position.X, position.Y), Vector2.zero
	end
	return c(React.Fragment, nil, {
		Button = if touchVisible
			then c(TouchButton, {
				SizePx = if props.TouchButtonPlacement == "BesideToolbar" then T.ArenaHUD.EmoteSize else nil,
				BottomPx = WheelConfig.TouchButtonBottomPx,
				Position = touchPosition,
				AnchorPoint = touchAnchor,
				ZIndex = z,
				RegisterTouchExclusion = props.RegisterTouchExclusion,
			})
			else nil,
		Surface = if snapshot.open
			then ModalSurface({
				ClassName = "TextButton",
				AutoButtonColor = false,
				BackgroundColor3 = C.Ink,
				BackgroundTransparency = styles.Alpha:map(function(alpha: number)
					return 1 - alpha * 0.38
				end),
				BorderSizePixel = 0,
				Text = "",
				ZIndex = z + 1,
				[React.Event.Activated] = function()
					if snapshot.deviceClass == "Touch" and snapshot.selected == nil then
						EmoteWheelController.cancel()
					end
				end,
			}, {
				Wheel = c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = styles.Scale:map(function(scale: number)
						local side = math.round(layout.diameter * scale)
						return UDim2.fromOffset(side, side)
					end),
					ZIndex = z + 2,
				}, {
					Shadow = c("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = C.Ink,
						BackgroundTransparency = 0.55,
						BorderSizePixel = 0,
						Position = UDim2.new(0.5, 0, 0.5, 6),
						Size = UDim2.new(1, 8, 1, 8),
						ZIndex = z + 2,
					}, {
						Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					}),
					Hole = c("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.new(0.5, 0, 0.5, 6),
						Size = UDim2.fromOffset(math.round(geo.inner * 2 - 2), math.round(geo.inner * 2 - 2)),
						ZIndex = z + 3,
					}),
					Ring = c(
						"Frame",
						{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 3 },
						ringSegments(geo, layout, sectors, snapshot.capacity, snapshot.selected, z + 3)
					),
					Dividers = c(
						"Frame",
						{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 4 },
						dividers(geo, sectors, z + 4)
					),
					Wedges = c(
						"Frame",
						{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 5 },
						wedges
					),
					Name = c("TextLabel", {
						AnchorPoint = if short then Vector2.new(0.5, 1) else Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Font = T.Type.Display,
						Position = if short then UDim2.new(0.5, 0, 0.5, 4) else UDim2.new(0.5, 0, 1, 14),
						Size = if short
							then UDim2.fromOffset(math.round(geo.inner * 2) - 16, 52)
							else UDim2.new(1.8, 0, 0, 44),
						Text = nameText,
						TextColor3 = nameColor,
						TextSize = math.round((if short then 22 else WheelConfig.NameTextPx) * textScale),
						TextWrapped = short,
						ZIndex = z + 6,
					}, {
						Stroke = c("UIStroke", { Color = C.Ink, Thickness = T.Type.Outline }),
					}),
					Hint = c("TextLabel", {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Font = T.Type.Label,
						Position = if short then UDim2.new(0.5, 0, 0.5, 8) else UDim2.new(0.5, 0, 1, 60),
						Size = if short
							then UDim2.fromOffset(math.round(geo.inner * 2) - 24, 40)
							else UDim2.new(1.8, 0, 0, 22),
						Text = hint,
						TextColor3 = C.Surface,
						TextSize = math.max(math.round((layout.labelTextPx - 3) * textScale), T.Type.HudMinimum),
						TextWrapped = short,
						ZIndex = z + 6,
					}, {
						Stroke = c("UIStroke", { Color = C.Ink, Thickness = T.Type.Outline }),
					}),
				}),
			})
			else nil,
	})
end
