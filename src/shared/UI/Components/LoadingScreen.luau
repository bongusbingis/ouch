-- Description: The full loading screen in the candy system: the OUCH! logo over a cream status panel carrying a kicker pill, the status title and detail, striped progress or bouncing candy dots, puffy retry and continue actions, and a tip sticker below, all rendered purely from the props its adapter supplies.

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Loading = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Loading"))
local CandyPanel = require(script.Parent.CandyPanel)
local CandyProgressBar = require(script.Parent.CandyProgressBar)
local CandySurface = require(script.Parent.CandySurface)
local LoadingBackdrop = require(script.Parent.LoadingBackdrop)
local PuffyButton = require(script.Parent.PuffyButton)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local T = require(script.Parent.Parent.Tokens)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Selection = require(script.Parent.Parent.Services.Selection)

local c, C = React.createElement, T.Colors
local L = Loading.Layout
local logoArt = UIConfig.LobbyArtwork.Logo
local LOGO_ASPECT = logoArt.Size.X / logoArt.Size.Y
local DOT_COLORS = { C.Pink, C.Yellow, C.Cyan }

export type LoadingAction = {
	Text: string,
	Style: ("Primary" | "Secondary")?,
	OnActivated: () -> (),
}

export type Props = {
	Visible: boolean,
	Title: string,
	Detail: string?,
	Kicker: string?,
	Tip: string?,
	Progress: number?,
	PrimaryAction: LoadingAction?,
	SecondaryAction: LoadingAction?,
	OnPresented: (() -> ())?,
	Static: boolean?,
	ParentScreenInsets: Enum.ScreenInsets?,
}

type Metrics = {
	compact: boolean,
	edge: number,
	inset: number,
	gap: number,
	panelWidth: number,
	panelHeight: number,
	panelTop: number,
	titleTop: number,
	titleHeight: number,
	detailTop: number?,
	meterTop: number?,
	meterHeight: number,
	actionsTop: number?,
	actionHeight: number,
	logoHeight: number,
	logoTop: number,
	tipTop: number?,
	tipHeight: number,
}

local function measure(
	safe: { position: Vector2, size: Vector2 },
	hasKicker: boolean,
	hasDetail: boolean,
	meter: "Bar" | "Dots" | "None",
	hasActions: boolean,
	hasTip: boolean
): Metrics
	local compact = safe.size.X < L.CompactWidth or safe.size.Y < L.CompactHeight
	local portrait = safe.size.Y > safe.size.X
	local edge = if compact then L.CompactEdge else L.Edge
	local inset = if compact then L.CompactInset else L.Inset
	local gap = if compact then L.CompactGap else L.Gap
	local fraction = if portrait
		then L.PortraitWidthFraction
		elseif compact then L.CompactWidthFraction
		else L.LandscapeWidthFraction
	local panelWidth = math.floor(math.min(L.PanelMaxWidth, safe.size.X * fraction, safe.size.X - edge * 2))

	local titleHeight = if compact then L.CompactTitleHeight else L.TitleHeight
	local meterHeight = if meter == "Bar"
		then (if compact then L.CompactProgressHeight else L.ProgressHeight)
		elseif meter == "Dots" then (if compact then L.CompactDotsHeight else L.DotsHeight)
		else 0
	local actionHeight = if compact then L.CompactActionHeight else L.ActionHeight
	local tipHeight = if compact then L.CompactTipHeight else L.TipHeight

	local cursor = inset + (if hasKicker then L.KickerHeight / 2 else 0)
	local titleTop = cursor
	cursor += titleHeight
	local detailTop: number? = nil
	if hasDetail then
		cursor += gap
		detailTop = cursor
		cursor += if compact then L.CompactDetailHeight else L.DetailHeight
	end
	local meterTop: number? = nil
	if meter ~= "None" then
		cursor += gap
		meterTop = cursor
		cursor += meterHeight
	end
	local actionsTop: number? = nil
	if hasActions then
		cursor += gap + L.ActionGap / 2
		actionsTop = cursor
		cursor += actionHeight
	end
	local panelHeight = cursor + inset

	local centerY = safe.size.Y * (if compact then L.CompactPanelCenterY else L.PanelCenterY)
	local panelTop = math.floor(centerY - panelHeight / 2)
	local logoHeight = math.clamp(safe.size.Y * L.LogoHeightFraction, L.LogoMinHeightPx, L.LogoMaxHeight)
	local roomAbove = panelTop - L.LogoGap - edge
	if roomAbove < logoHeight then
		panelTop = math.max(panelTop, edge + L.KickerHeight)
		roomAbove = panelTop - L.LogoGap - edge
		logoHeight = math.min(logoHeight, roomAbove)
	end
	if logoHeight < L.LogoMinHeightPx or (hasActions and safe.size.Y < L.LogoMinHeight) then
		logoHeight = 0
	end
	local logoTop = panelTop - L.LogoGap - logoHeight

	local tipTop: number? = nil
	if hasTip then
		local candidate = safe.size.Y - L.TipBottomGap - tipHeight
		if candidate >= panelTop + panelHeight + gap then
			tipTop = candidate
		end
	end

	return {
		compact = compact,
		edge = edge,
		inset = inset,
		gap = gap,
		panelWidth = panelWidth,
		panelHeight = panelHeight,
		panelTop = panelTop,
		titleTop = titleTop,
		titleHeight = titleHeight,
		detailTop = detailTop,
		meterTop = meterTop,
		meterHeight = meterHeight,
		actionsTop = actionsTop,
		actionHeight = actionHeight,
		logoHeight = logoHeight,
		logoTop = logoTop,
		tipTop = tipTop,
		tipHeight = tipHeight,
	}
end

local function pillWidth(text: string, size: number, font: Enum.Font, padding: number, maximum: number): number
	local wanted = TextService:GetTextSize(text, size, font, Vector2.new(100000, 1000)).X + padding * 2
	return math.floor(math.min(wanted, maximum))
end

-- Three candy dots at rest, or hopping in turn while the screen waits on
-- something it cannot measure; the phase binding is nil for a static screen.
local function candyDots(m: Metrics, contentWidth: number, phase: any?)
	local dot = if m.compact then L.CompactDotSize else L.DotSize
	local rest = m.meterHeight / 2 + L.DotBounceAmplitude / 2
	local children = {}
	for index, color in DOT_COLORS do
		local x = contentWidth / 2 + (index - 2) * (dot + L.DotGap)
		children[`Dot{index}`] = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = if phase
				then phase:map(function(value: number)
					local wave = math.sin((value - (index - 1) * L.DotBounceStagger) * 2 * math.pi)
					return UDim2.fromOffset(x, rest - math.max(wave, 0) * L.DotBounceAmplitude)
				end)
				else UDim2.fromOffset(x, rest),
			Size = UDim2.fromOffset(dot, dot),
			ZIndex = 16,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Outline = c("UIStroke", { Color = C.Ink, Thickness = T.Shape.StrokeInner }),
		})
	end
	return children
end

local function actionButton(
	action: LoadingAction,
	index: number,
	width: number,
	height: number,
	primary: boolean,
	buttonRef: any?
)
	return c(PuffyButton, {
		ButtonRef = buttonRef,
		Color = if primary then C.Pink else C.Well,
		TextColor = if primary then C.Surface else C.Ink,
		Text = action.Text,
		TextSize = T.Type.Tab,
		Style = if primary then "Primary" else "Standard",
		Radius = T.Shape.RadiusPill,
		OnActivated = action.OnActivated,
		Native = {
			LayoutOrder = index,
			Size = UDim2.fromOffset(width, height),
			ZIndex = 16,
		},
	})
end

return function(props: Props)
	local safeArea = useSafeArea(props.ParentScreenInsets or Enum.ScreenInsets.CoreUISafeInsets)
	local reducedMotion = useReducedMotion()
	local isStatic = props.Static == true
	local hasActions = props.PrimaryAction ~= nil or props.SecondaryAction ~= nil
	local meter: "Bar" | "Dots" | "None" = if hasActions
		then "None"
		elseif props.Progress ~= nil and not isStatic then "Bar"
		else "Dots"
	local hasTip = props.Tip ~= nil and not isStatic
	local m = measure(safeArea, props.Kicker ~= nil, props.Detail ~= nil, meter, hasActions, hasTip)

	local present, setPresent = React.useState(props.Visible)
	local rootRef = React.useRef(nil)
	local panelRef = React.useRef(nil)
	local transitionRevision = React.useRef(0)
	local focusRevision = React.useRef(0)
	local firstActionRef = React.useRef(nil)
	local previousSelection = React.useRef(nil)
	local onPresentedRef = React.useRef(props.OnPresented)
	onPresentedRef.current = props.OnPresented
	local logoLift, setLogoLift = React.useBinding(0)
	local dotPhase, setDotPhase = React.useBinding(0)
	local styles, api = ReactSpring.useSpring(function()
		return {
			Transparency = if props.Visible then 0 else 1,
		}
	end)
	local progressStyles = ReactSpring.useSpring({
		Progress = math.clamp(props.Progress or 0, 0, 1),
		config = Motion.Modal,
		immediate = reducedMotion or isStatic,
	})

	React.useEffect(function()
		transitionRevision.current += 1
		local revision = transitionRevision.current
		local immediate = reducedMotion or isStatic
		if props.Visible then
			setPresent(true)
			api.start({
				Transparency = 0,
				config = Motion.Modal,
				immediate = immediate,
			})
		else
			api.start({
				Transparency = 1,
				config = Motion.Modal,
				immediate = immediate,
			}):andThen(function()
				if transitionRevision.current == revision then
					setPresent(false)
				end
			end)
		end
		return function()
			transitionRevision.current += 1
		end
	end, { props.Visible, isStatic, reducedMotion })

	React.useEffect(function()
		if not props.Visible or not present then
			return
		end
		local cancelled = false
		task.defer(function()
			if cancelled or rootRef.current == nil then
				return
			end
			local onPresented = onPresentedRef.current
			if onPresented then
				onPresented()
			end
		end)
		return function()
			cancelled = true
		end
	end, { props.Visible, present })

	React.useEffect(function()
		if not props.Visible or not present or isStatic then
			return
		end
		local cleanup = if panelRef.current then Motion.popIn(panelRef.current) else nil
		return function()
			if cleanup then
				cleanup()
			end
		end
	end, { props.Visible, present, isStatic })

	local bobbing = props.Visible and present and not isStatic and not reducedMotion and m.logoHeight > 0
	React.useEffect(function()
		if not bobbing then
			setLogoLift(0)
			return
		end
		local elapsed = 0
		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed += deltaTime
			setLogoLift(math.sin(elapsed * 2 * math.pi / L.LogoBobPeriod) * L.LogoBobAmplitude)
		end)
		return function()
			connection:Disconnect()
		end
	end, { bobbing })

	local bouncing = props.Visible and present and meter == "Dots" and not isStatic and not reducedMotion
	React.useEffect(function()
		if not bouncing then
			setDotPhase(0)
			return
		end
		local elapsed = 0
		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed = (elapsed + deltaTime) % L.DotBouncePeriod
			setDotPhase(elapsed / L.DotBouncePeriod)
		end)
		return function()
			connection:Disconnect()
		end
	end, { bouncing })

	React.useEffect(function()
		return function()
			transitionRevision.current += 1
			api.stop()
		end
	end, {})

	React.useEffect(function()
		if not props.Visible or isStatic then
			return
		end
		previousSelection.current = GuiService.SelectedObject
		GuiService.SelectedObject = nil
		return function()
			local selection = previousSelection.current
			previousSelection.current = nil
			if Selection.isSelectable(selection) then
				GuiService.SelectedObject = selection
			end
		end
	end, { props.Visible, isStatic })

	React.useEffect(function()
		focusRevision.current += 1
		local revision = focusRevision.current
		if props.Visible and not isStatic and hasActions then
			task.defer(function()
				local button = firstActionRef.current
				if focusRevision.current == revision and Selection.isSelectable(button) then
					GuiService.SelectedObject = button
				end
			end)
		end
		return function()
			focusRevision.current += 1
		end
	end, { props.Visible, isStatic, hasActions })

	if not present then
		return nil
	end

	local actions: { LoadingAction } = {}
	if props.PrimaryAction then
		table.insert(actions, props.PrimaryAction)
	end
	if props.SecondaryAction then
		table.insert(actions, props.SecondaryAction)
	end
	local contentWidth = m.panelWidth - m.inset * 2
	local actionWidth = if #actions > 1
		then math.min(L.ActionMaxWidth, math.floor((contentWidth - L.ActionGap) / 2))
		else math.min(L.ActionMaxWidth, contentWidth)
	local actionChildren = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, L.ActionGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index, action in actions do
		local primary = if action.Style then action.Style == "Primary" else index == 1
		actionChildren[`Action{index}`] = actionButton(
			action,
			index,
			actionWidth,
			m.actionHeight,
			primary,
			if index == 1 then firstActionRef else nil
		)
	end

	local kicker = props.Kicker
	local kickerWidth = if kicker
		then pillWidth(kicker, T.Type.Minimum, T.Type.CompactLabel, T.Layout.CompactGap, L.KickerMaxWidth)
		else 0
	local tip = props.Tip
	local tipWidth = math.min(L.TipMaxWidth, safeArea.size.X - m.edge * 2)
	local logoWidth = math.floor(m.logoHeight * LOGO_ASPECT)
	local centerX = safeArea.size.X / 2

	return c(LoadingBackdrop, {
		Native = {
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			SelectionGroup = hasActions,
		},
		RootRef = rootRef,
		Static = isStatic,
		Transparency = styles.Transparency,
	}, {
		SafeArea = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(safeArea.position.X, safeArea.position.Y),
			Size = UDim2.fromOffset(safeArea.size.X, safeArea.size.Y),
			ZIndex = 10,
		}, {
			Logo = if m.logoHeight > 0
				then c("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Image = logoArt.Image,
					ImageRectOffset = logoArt.Offset,
					ImageRectSize = logoArt.Size,
					Position = logoLift:map(function(lift: number)
						return UDim2.fromOffset(centerX, m.logoTop + lift)
					end),
					Size = UDim2.fromOffset(logoWidth, m.logoHeight),
					ZIndex = 11,
				})
				else nil,
			Panel = c(CandyPanel, {
				Native = {
					ref = panelRef,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromOffset(centerX, m.panelTop),
					Size = UDim2.fromOffset(m.panelWidth, m.panelHeight),
					ZIndex = 12,
				},
			}, {
				Kicker = if kicker
					then c("Frame", {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(m.panelWidth / 2, -L.KickerHeight / 2),
						Size = UDim2.fromOffset(kickerWidth, L.KickerHeight),
						ZIndex = 20,
					}, {
						Surface = c(CandySurface, { Color = C.Yellow, Shadow = false, ZIndex = 20 }),
						Text = c("TextLabel", {
							BackgroundTransparency = 1,
							Font = T.Type.CompactLabel,
							Position = UDim2.fromOffset(T.Layout.CompactGap / 2, 0),
							Size = UDim2.new(1, -T.Layout.CompactGap, 1, -T.Shape.LipHeight),
							Text = kicker,
							TextColor3 = C.Ink,
							TextSize = T.Type.Minimum,
							TextTruncate = Enum.TextTruncate.AtEnd,
							ZIndex = 26,
						}),
					})
					else nil,
				Title = c(ResponsiveText, {
					HostName = "Title",
					MeasurementFont = T.Type.Display,
					MaxTextSize = if m.compact then L.CompactTitleSize else L.TitleSize,
					MinTextSize = L.TitleMinSize,
					Native = {
						BackgroundTransparency = 1,
						Font = T.Type.Display,
						Position = UDim2.fromOffset(m.inset, m.titleTop),
						Size = UDim2.fromOffset(contentWidth, m.titleHeight),
						Text = props.Title,
						TextColor3 = C.Ink,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 16,
					},
				}),
				Detail = if props.Detail and m.detailTop
					then c(ResponsiveText, {
						HostName = "Detail",
						MeasurementFont = T.Type.Label,
						MaxTextSize = if m.compact then L.CompactDetailSize else L.DetailSize,
						MinTextSize = L.DetailMinSize,
						Native = {
							BackgroundTransparency = 1,
							Font = T.Type.Label,
							Position = UDim2.fromOffset(m.inset, m.detailTop),
							Size = UDim2.fromOffset(
								contentWidth,
								if m.compact then L.CompactDetailHeight else L.DetailHeight
							),
							Text = props.Detail,
							TextColor3 = C.InkSoft,
							TextXAlignment = Enum.TextXAlignment.Center,
							ZIndex = 16,
						},
					})
					else nil,
				Progress = if meter == "Bar" and m.meterTop
					then c(CandyProgressBar, {
						Progress = progressStyles.Progress,
						Animated = true,
						Native = {
							Position = UDim2.fromOffset(m.inset, m.meterTop),
							Size = UDim2.fromOffset(contentWidth, m.meterHeight),
							ZIndex = 16,
						},
					})
					else nil,
				Dots = if meter == "Dots" and m.meterTop
					then c("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(m.inset, m.meterTop),
						Size = UDim2.fromOffset(contentWidth, m.meterHeight),
						ZIndex = 16,
					}, candyDots(m, contentWidth, if isStatic then nil else dotPhase))
					else nil,
				Actions = if hasActions and m.actionsTop
					then c("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(m.inset, m.actionsTop),
						Size = UDim2.fromOffset(contentWidth, m.actionHeight),
						ZIndex = 16,
					}, actionChildren)
					else nil,
			}),
			Tip = if tip and m.tipTop
				then c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(centerX, m.tipTop),
					Size = UDim2.fromOffset(tipWidth, m.tipHeight),
					ZIndex = 12,
				}, {
					Surface = c(CandySurface, { Color = C.SurfaceWarm, ZIndex = 12 }),
					Chip = c("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(T.Shape.LipHeight, T.Shape.LipHeight),
						Size = UDim2.new(0, L.TipChipWidth, 1, -T.Shape.LipHeight * 3),
						ZIndex = 18,
					}, {
						Surface = c(CandySurface, { Color = C.Yellow, Shadow = false, ZIndex = 18 }),
						Text = c("TextLabel", {
							BackgroundTransparency = 1,
							Font = T.Type.Display,
							Size = UDim2.new(1, 0, 1, -T.Shape.LipHeight),
							Text = "TIP",
							TextColor3 = C.Ink,
							TextSize = T.Type.Minimum,
							ZIndex = 24,
						}),
					}),
					Text = c(ResponsiveText, {
						HostName = "Tip",
						MeasurementFont = T.Type.Label,
						MaxTextSize = L.TipSize,
						MinTextSize = L.TipMinSize,
						Native = {
							BackgroundTransparency = 1,
							Font = T.Type.Label,
							Position = UDim2.fromOffset(L.TipChipWidth + T.Layout.CompactGap * 2, 0),
							Size = UDim2.new(1, -(L.TipChipWidth + T.Layout.CompactGap * 3), 1, -T.Shape.LipHeight),
							Text = tip,
							TextColor3 = C.Ink,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 18,
						},
					}),
				})
				else nil,
		}),
	})
end
