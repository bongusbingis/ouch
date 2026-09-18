-- Name: EmoteWheel.luau
-- Author: Jack C.
-- Description: Renders the radial emote selector from the controller's snapshot as a solid segmented ring with a hollow centre that keeps the character visible, the hovered wedge lit in cyan, the emote's name in display type below the ring, a release hint, and on touch devices the small wheel button that opens it.
-- Created: 2026-09-09
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

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
local useArenaHUDLayout = require(script.Parent.Parent.Hooks.useArenaHUDLayout)
local usePreferredTextSize = require(script.Parent.Parent.Hooks.usePreferredTextSize)
local Config = ReplicatedStorage:WaitForChild("Config")
local UI = require(Config:WaitForChild("Interface"):WaitForChild("UI"))
local Input = require(Config:WaitForChild("Interface"):WaitForChild("Input"))
local WheelConfig = require(Config:WaitForChild("Interface"):WaitForChild("EmoteWheel"))
local Cosmetics = require(Config:WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))

local c = React.createElement
local Palette = UI.ProgressionStyle
local WHITE = Color3.new(1, 1, 1)
local DISPLAY_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")

local function registerExclusion(name: string, rect: any)
	local ok, module = pcall(require, StarterPlayer:WaitForChild("PlayerModule"))
	local combat = if ok and type(module) == "table" then module.Combat else nil
	if combat and type(combat.registerHudExclusion) == "function" then
		pcall(combat.registerHudExclusion, name, rect)
	end
end

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
		children["Seg" .. index] = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if isSelected then Palette.Cyan elseif filled then Palette.Surface else Palette.Ink,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, mx, 0.5, my),
			Rotation = angle,
			Size = UDim2.fromOffset(math.round(geo.chord), math.round(geo.thickness)),
			ZIndex = z,
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
			BackgroundColor3 = Palette.Raised,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, x, 0.5, y),
			Rotation = angle,
			Size = UDim2.fromOffset(2, math.round(geo.thickness) + 2),
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
	local ink = if props.Selected then Palette.Ink elseif sector.filled then WHITE else Palette.Muted
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
					ImageColor3 = if props.Selected then WHITE else Color3.fromRGB(235, 238, 242),
					Position = UDim2.fromScale(0.5, 0.5),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.9, 0.9),
					ZIndex = props.ZIndex,
				})
				else c("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = DISPLAY_FONT,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					Text = if sector.filled then sector.displayName else "",
					TextColor3 = ink,
					TextSize = props.TextPx,
					TextWrapped = true,
					ZIndex = props.ZIndex,
				}, {
					Stroke = if sector.filled and not props.Selected
						then c("UIStroke", { Color = Palette.Ink, Thickness = 1.5, Transparency = 0.3 })
						else nil,
				}),
			EmptyMark = if sector.filled
				then nil
				else c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = WHITE,
					BackgroundTransparency = 0.72,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(math.round(geo.thickness * 0.34), math.round(geo.thickness * 0.34)),
					ZIndex = props.ZIndex,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Plus = if not props.ShowPlus
						then nil
						else c("TextLabel", {
							BackgroundTransparency = 1,
							FontFace = DISPLAY_FONT,
							Size = UDim2.fromScale(1, 1),
							Text = "+",
							TextColor3 = WHITE,
							TextScaled = true,
							TextTransparency = 0.25,
							ZIndex = props.ZIndex + 1,
						}),
				}),
		}),
		Badge = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if props.Selected then Palette.Yellow else Palette.Ink,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, bx, 0.5, by),
			Size = UDim2.fromOffset(22, 22),
			ZIndex = props.ZIndex + 1,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Outline = c(
				"UIStroke",
				{ Color = WHITE, Thickness = 1.5, Transparency = if props.Selected then 0 else 0.5 }
			),
			Text = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Size = UDim2.fromScale(1, 1),
				Text = tostring(sector.index),
				TextColor3 = if props.Selected then Palette.Ink else WHITE,
				TextSize = 13,
				TextTransparency = if props.Selected or sector.filled then 0 else 0.35,
				ZIndex = props.ZIndex + 2,
			}),
		}),
	})
end

local function TouchButton(props)
	local ref = React.useRef(nil)
	React.useEffect(function()
		local button = ref.current
		if button == nil or not props.Visible then
			registerExclusion("EmoteButton", nil)
			return
		end
		local function register()
			local p, s = button.AbsolutePosition, button.AbsoluteSize
			registerExclusion("EmoteButton", { minX = p.X, minY = p.Y, maxX = p.X + s.X, maxY = p.Y + s.Y })
		end
		register()
		local p = button:GetPropertyChangedSignal("AbsolutePosition"):Connect(register)
		local s = button:GetPropertyChangedSignal("AbsoluteSize"):Connect(register)
		return function()
			p:Disconnect()
			s:Disconnect()
			registerExclusion("EmoteButton", nil)
		end
	end, { props.Visible })
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
			Visible = props.Visible,
			Selectable = false,
			ZIndex = props.ZIndex,
		},
		OnActivated = EmoteWheelController.openTouch,
	}, dots)
end

export type Props = {
	ShowTouchButton: boolean?,
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
	local selectedSector = if snapshot.selected then sectors[snapshot.selected] else nil
	local nameText = if selectedSector and selectedSector.filled
		then selectedSector.displayName
		elseif selectedSector then "EMPTY SLOT"
		else "EMOTES"
	local nameColor = if selectedSector and selectedSector.filled
		then Palette.Yellow
		elseif selectedSector then Palette.Muted
		else WHITE
	local hint = if snapshot.deviceClass == "Gamepad"
		then "RELEASE " .. string.upper(Input.EmoteWheel.GamepadLabel) .. " TO PLAY"
		elseif snapshot.deviceClass == "Keyboard" then "RELEASE " .. Input.EmoteWheel.KeyboardLabel .. " TO PLAY"
		else "DRAG AND RELEASE TO PLAY"
	local wedges = {}
	for _, sector in sectors do
		wedges["Wedge" .. sector.index] = c(Wedge, {
			Sector = sector,
			Geometry = geo,
			Capacity = snapshot.capacity,
			TextPx = math.round(layout.labelTextPx * textScale),
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
		Button = c(TouchButton, {
			SizePx = if props.TouchButtonPlacement == "BesideToolbar" then T.ArenaHUD.EmoteSize else nil,
			Visible = touchVisible,
			BottomPx = WheelConfig.TouchButtonBottomPx,
			Position = touchPosition,
			AnchorPoint = touchAnchor,
			ZIndex = z,
		}),
		Surface = if snapshot.open
			then ModalSurface({
				ClassName = "TextButton",
				AutoButtonColor = false,
				BackgroundColor3 = Palette.Ink,
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
						BackgroundColor3 = Palette.Ink,
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
						FontFace = DISPLAY_FONT,
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
						Stroke = c("UIStroke", { Color = Palette.Ink, Thickness = 3, Transparency = 0.1 }),
					}),
					Hint = c("TextLabel", {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = UI.Text.DefaultFont,
						Position = if short then UDim2.new(0.5, 0, 0.5, 8) else UDim2.new(0.5, 0, 1, 60),
						Size = if short
							then UDim2.fromOffset(math.round(geo.inner * 2) - 24, 40)
							else UDim2.new(1.8, 0, 0, 22),
						Text = hint,
						TextColor3 = WHITE,
						TextSize = math.max(math.round((layout.labelTextPx - 3) * textScale), UI.Text.CaptionMinPx),
						TextWrapped = short,
						TextTransparency = 0.2,
						ZIndex = z + 6,
					}, {
						Stroke = c("UIStroke", { Color = Palette.Ink, Thickness = 1.5, Transparency = 0.25 }),
					}),
				}),
			})
			else nil,
	})
end
