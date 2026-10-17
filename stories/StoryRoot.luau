--[[
    The one stage every Ouch! story is drawn on. A story hands StoryRoot.story a spec -- a title, a
    one-line summary and its states -- and gets back the function(target) UI Labs mounts. The stage
    is the lobby's candy backdrop (Tokens sky -> lilac -> pink gradient plus the swirl tile, the
    same recipe as LoadingBackdrop, redrawn here so no story depends on a component under test) with
    a scrolling sheet of labelled frames, one per state:

      * A component state is a fixed frame at the component's real pixel size (Size), drawn 1:1
        unless the widget is narrower, in which case it is scaled down and the label says so.
      * A Screen state is a frame the size of the live camera viewport, because every full-screen
        Ouch component lays itself out from Workspace.CurrentCamera.ViewportSize (useViewportSize /
        useSafeArea), not from its parent. Showing it in a frame of any other size would lie about
        its layout. Screen frames are scaled to fit (Fit = share of the stage width) and the label
        prints the viewport they were laid out for; to see the phone layout, switch Studio's Device
        emulator to a phone and the frames re-lay themselves.
      * Mode = "Switch" draws one state at a time with a chip row to pick it, for sets of heavy
        full-screen states (post-match has ~25) that would be unreadable side by side.

    Each frame sits inside an error boundary, so one component that throws (a renamed prop, a
    removed module) shows its error in its own frame instead of blanking the whole story. The frame
    outline, labels and chips are story chrome, not Ouch tokens-as-design.

    The host LayerCollector is put in ZIndexBehavior.Sibling for the story's life (every Ouch
    ScreenGui is Sibling and the components lean on it) and restored on unmount.
]]

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local T = require(UI:WaitForChild("Tokens"))

local c = React.createElement
local C = T.Colors

local PAD = 24
local GAP = 24
local LABEL_HEIGHT = 46
local HEADER_TITLE = 40
local FALLBACK_VIEWPORT = Vector2.new(1280, 720)

export type State = {
	Name: string,
	Note: string?,
	Size: Vector2?,
	Screen: boolean?,
	Fit: number?,
	Element: any,
}

export type Spec = {
	Title: string,
	Summary: string?,
	Mode: string?,
	States: { State },
}

local StoryRoot = {}

StoryRoot.React = React
StoryRoot.UI = UI
StoryRoot.Components = UI:WaitForChild("Components")
StoryRoot.Models = UI:WaitForChild("Models")
StoryRoot.Tokens = T

--> Common component frame sizes (logical px). Desktop/Phone match the widths the lobby layouts are
--> authored against; components that take Width/Compact props are shown at both.
StoryRoot.Sizes = table.freeze({
	Desktop = Vector2.new(1280, 720),
	Phone = Vector2.new(844, 390),
	Panel = Vector2.new(760, 520),
	PanelCompact = Vector2.new(420, 520),
	Strip = Vector2.new(960, 140),
	Chip = Vector2.new(360, 120),
})

local function viewportSize(): Vector2
	local camera = Workspace.CurrentCamera
	if camera and camera.ViewportSize.X > 1 and camera.ViewportSize.Y > 1 then
		return camera.ViewportSize
	end
	return FALLBACK_VIEWPORT
end

--> The live viewport, tracked so Screen frames follow the Device emulator.
local function useViewport(): Vector2
	local size, setSize = React.useState(viewportSize())
	React.useEffect(function()
		local connection: RBXScriptConnection? = nil
		local function watch()
			if connection then
				connection:Disconnect()
			end
			local camera = Workspace.CurrentCamera
			if camera then
				connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
					setSize(viewportSize())
				end)
			end
			setSize(viewportSize())
		end
		watch()
		local cameraChanged = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
		return function()
			cameraChanged:Disconnect()
			if connection then
				connection:Disconnect()
			end
		end
	end, {})
	return size
end

local function text(props: { [string]: any }, children: { [string]: any }?): any
	local native = {
		BackgroundTransparency = 1,
		Font = T.Type.Label,
		TextColor3 = C.Ink,
		TextSize = T.Type.Minimum,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for key, value in props do
		native[key] = value
	end
	return c("TextLabel", native, children)
end

--> Error boundary: a throwing component reports inside its own frame.
local Boundary = React.Component:extend("StoryBoundary")

function Boundary:init()
	self.state = { message = false }
end

function Boundary.getDerivedStateFromError(err: any)
	return { message = tostring(err) }
end

function Boundary:componentDidCatch(err: any)
	warn(`[Ouch! UI] {self.props.Label} threw: {tostring(err)}`)
end

function Boundary:render()
	if self.state.message then
		return c("Frame", { BackgroundColor3 = C.Surface, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, {
			Padding = c("UIPadding", {
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
				PaddingTop = UDim.new(0, 16),
			}),
			Message = text({
				Size = UDim2.fromScale(1, 1),
				Text = `STORY ERROR — {self.props.Label}\n\n{self.state.message}`,
				TextColor3 = C.PinkLip,
				TextTruncate = Enum.TextTruncate.None,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
		})
	end
	return c(React.Fragment, nil, self.props.children)
end

--> A centred note card, for states that cannot render in this context (place-only modules,
--> components that need Players.LocalPlayer). Size it like the state it replaces.
function StoryRoot.Notice(message: string): any
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Card = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.SurfaceWarm,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.8, 0, 0, 140),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }),
			Stroke = c("UIStroke", { Color = C.Ink, Thickness = T.Shape.StrokeCard }),
			Padding = c("UIPadding", {
				PaddingLeft = UDim.new(0, 18),
				PaddingRight = UDim.new(0, 18),
			}),
			Message = text({
				Size = UDim2.fromScale(1, 1),
				Text = message,
				TextSize = T.Type.Body,
				TextTruncate = Enum.TextTruncate.None,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		}),
	})
end

--> Players.LocalPlayer is nil in Studio edit mode; a few components read it during render.
function StoryRoot.hasLocalPlayer(): boolean
	return Players.LocalPlayer ~= nil
end

--> A place-only client module (e.g. the lobby's LobbyApp) under StarterPlayerScripts.Client, or
--> nil in the other place. Path is relative to Client, e.g. { "UI", "LobbyApp" }.
function StoryRoot.placeModule(path: { string }): ModuleScript?
	local node: Instance? = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	node = node and node:FindFirstChild("Client")
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return if node and node:IsA("ModuleScript") then node else nil
end

local function Cell(props: {
	State: State,
	Viewport: Vector2,
	StageWidth: number,
	LayoutOrder: number,
})
	local state = props.State
	local logical = if state.Screen then props.Viewport else (state.Size or StoryRoot.Sizes.Panel)
	local fit = state.Fit or 1
	local room = math.max(props.StageWidth * fit - (if fit < 1 then GAP else 0), 120)
	local scale = math.min(1, room / logical.X)
	local shown = Vector2.new(math.floor(logical.X * scale), math.floor(logical.Y * scale))
	local meta = `{if state.Screen then "VIEWPORT " else ""}{logical.X}×{logical.Y}`
	if scale < 0.999 then
		meta ..= ` · {math.round(scale * 100)}%`
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(math.max(shown.X, 220), LABEL_HEIGHT + shown.Y),
	}, {
		Name = text({
			Font = T.Type.Display,
			Size = UDim2.new(1, -150, 0, 24),
			Text = string.upper(state.Name),
			TextColor3 = C.Surface,
			TextSize = 20,
		}, {
			Stroke = c("UIStroke", { Color = C.Ink, Thickness = 2 }),
		}),
		Meta = text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(150, 24),
			Text = meta,
			TextColor3 = C.InkSoft,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Note = text({
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, 0, 0, 20),
			Text = state.Note or "",
			TextColor3 = C.Ink,
			TextSize = 14,
		}),
		Frame = c("Frame", {
			BackgroundColor3 = C.Surface,
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(0, LABEL_HEIGHT),
			Size = UDim2.fromOffset(shown.X, shown.Y),
		}, {
			Outline = c("UIStroke", { Color = C.Ink, Thickness = 2, Transparency = 0.35 }),
			Content = c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(logical.X, logical.Y),
			}, {
				Scale = if scale < 0.999 then c("UIScale", { Scale = scale }) else nil,
				Boundary = c(Boundary, { Label = state.Name }, { Element = state.Element }),
			}),
		}),
	})
end

local function Chip(props: { Text: string, Active: boolean, LayoutOrder: number, OnActivated: () -> () })
	return c("TextButton", {
		AutoButtonColor = false,
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = if props.Active then C.Pink else C.Surface,
		BorderSizePixel = 0,
		Font = T.Type.Label,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(0, 34),
		Text = string.upper(props.Text),
		TextColor3 = if props.Active then C.Surface else C.Ink,
		TextSize = 16,
		[React.Event.Activated] = props.OnActivated,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Stroke = c("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = C.Ink,
			Thickness = 2,
		}),
		Padding = c("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
	})
end

local function Backdrop()
	return c("Frame", {
		BackgroundColor3 = C.Surface,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
	}, {
		Gradient = c("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, C.BackdropTop),
				ColorSequenceKeypoint.new(0.5, C.BackdropMid),
				ColorSequenceKeypoint.new(1, C.BackdropBottom),
			}),
		}),
		Swirl = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = T.Texture.Swirl,
			ImageColor3 = C.Surface,
			ImageTransparency = 1 - T.Texture.SwirlOpacity,
			ScaleType = Enum.ScaleType.Tile,
			Size = UDim2.fromScale(1, 1),
			TileSize = UDim2.fromOffset(360, 360),
		}),
	})
end

local function Stage(props: { Spec: Spec })
	local spec = props.Spec
	local viewport = useViewport()
	local width, setWidth = React.useState(0)
	local selected, setSelected = React.useState(1)
	local switch = spec.Mode == "Switch"
	local stageWidth = math.max(width - PAD * 2, 240)

	local sheet: { [string]: any } = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}),
	}
	if switch then
		local index = math.clamp(selected, 1, #spec.States)
		local state = table.clone(spec.States[index])
		state.Fit = 1
		sheet.Selected = c(Cell, {
			State = state,
			Viewport = viewport,
			StageWidth = stageWidth,
			LayoutOrder = 1,
			key = state.Name,
		})
	else
		for index, state in spec.States do
			sheet[`State{index}`] = c(Cell, {
				State = state,
				Viewport = viewport,
				StageWidth = stageWidth,
				LayoutOrder = index,
			})
		end
	end

	local chips: { [string]: any }? = nil
	if switch then
		local row: { [string]: any } = {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Wraps = true,
			}),
		}
		for index, state in spec.States do
			row[`Chip{index}`] = c(Chip, {
				Text = state.Name,
				Active = index == selected,
				LayoutOrder = index,
				OnActivated = function()
					setSelected(index)
				end,
			})
		end
		chips = row
	end

	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Backdrop = c(Backdrop),
		Scroller = c("ScrollingFrame", {
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			ScrollBarImageColor3 = C.Ink,
			ScrollBarThickness = T.Layout.ScrollBar,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			[React.Change.AbsoluteSize] = function(instance: ScrollingFrame)
				setWidth(instance.AbsoluteSize.X)
			end,
			ref = function(instance: ScrollingFrame?)
				if instance and width == 0 then
					task.defer(setWidth, instance.AbsoluteSize.X)
				end
			end,
		}, {
			Padding = c("UIPadding", {
				PaddingBottom = UDim.new(0, PAD),
				PaddingLeft = UDim.new(0, PAD),
				PaddingRight = UDim.new(0, PAD),
				PaddingTop = UDim.new(0, PAD),
			}),
			Layout = c("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }),
			Title = c("TextLabel", {
				BackgroundTransparency = 1,
				Font = T.Type.Display,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, HEADER_TITLE),
				Text = string.upper(spec.Title),
				TextColor3 = C.Surface,
				TextSize = 34,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				Stroke = c("UIStroke", { Color = C.Ink, Thickness = T.Type.Outline }),
			}),
			Summary = if spec.Summary
				then text({
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 2,
					Size = UDim2.fromScale(1, 0),
					Text = spec.Summary,
					TextSize = 16,
					TextTruncate = Enum.TextTruncate.None,
					TextWrapped = true,
				})
				else nil,
			Chips = if chips
				then c("Frame", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 3,
					Size = UDim2.fromScale(1, 0),
				}, chips)
				else nil,
			Sheet = c("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 4,
				Size = UDim2.fromScale(1, 0),
			}, sheet),
		}),
	})
end

--> Mount any element on the stage chrome-free (used by Index/Stubs, which draw their own sheet).
function StoryRoot.mount(target: Instance, element: any): () -> ()
	local host = target:FindFirstAncestorWhichIsA("LayerCollector")
	local previous = if host then host.ZIndexBehavior else nil
	if host then
		host.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	end
	local root = ReactRoblox.createRoot(target)
	root:render(element)
	return function()
		root:unmount()
		if host and previous then
			host.ZIndexBehavior = previous
		end
	end
end

--> The usual entry point: `return StoryRoot.story({ Title = ..., Summary = ..., States = {...} })`.
function StoryRoot.story(spec: Spec): (Instance) -> () -> ()
	assert(#spec.States > 0, `[StoryRoot] {spec.Title} has no states`)
	return function(target: Instance)
		return StoryRoot.mount(target, c(Stage, { Spec = spec }))
	end
end

--> Backdrop alone, for stories that compose their own sheet on the candy stage.
StoryRoot.Backdrop = Backdrop
StoryRoot.Text = text

return StoryRoot
