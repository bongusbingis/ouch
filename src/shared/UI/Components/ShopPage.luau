--!strict
-- Measured featured band plus a packed catalog; the season never enters overflow.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(RS.Packages.react)
local UI = require(RS.Config.Interface.UI)
local T = require(script.Parent.Parent.Tokens)
local Config = require(script.Parent.Parent.Models.CandyShopConfig)
local Composition = require(script.Parent.Parent.Models.ShopComposition)
local Layout = require(script.Parent.Parent.Models.ShopLayout)
local Responsive = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local Panel = require(script.Parent.CandyPanel)
local Title = require(script.Parent.CandyTitle)
local Well = require(script.Parent.Well)
local Button = require(script.Parent.PuffyButton)
local BonksChip = require(script.Parent.BonksChip)
local Icon = require(script.Parent.Icon)
local TextService = game:GetService("TextService")
local Section = require(script.Parent.Shop.ShopSection)
local c, C, L = React.createElement, T.Colors, T.Shop
local function blocks(entries, width, offset, props)
	local unit = Layout.trackUnit(width, Config.Tracks, Config.GapPx)
	for _, entry in entries do
		entry.class = Config.CardClasses[entry.style.Class]
		entry.priority = entry.style.Priority
		if props.Short then
			entry.class = Composition.shortClass(entry.class, L.PromoMin, T.LobbyLandscape.CardHeight)
		end
		entry.span = Composition.span(width, entry.style.Span, entry.class.MinPx, Config.GapPx, L.WideMin, L.MediumMin)
		entry.width = Layout.spanWidth(unit, entry.span, Config.GapPx)
		if #entry.cards == 1 and (entry.class.Layout == "Split" or entry.cards[1].kind == "SeasonPass") then
			entry.class = table.clone(entry.class)
			entry.class.MaxPx = entry.width
		end
		entry.grid = Layout.grid(entry.width, #entry.cards, entry.class, Config.CardGapPx, entry.style.MaxColumns)
		local adapted = Composition.adaptiveClass(
			entry.class,
			entry.grid.cardWidth,
			L.CatalogSplitMin,
			L.CatalogSplitHeight,
			L.PromoMin,
			L.CardHeight
		)
		if adapted ~= entry.class then
			entry.class = adapted
			entry.grid = Layout.grid(entry.width, #entry.cards, adapted, Config.CardGapPx, entry.style.MaxColumns)
		end
		entry.headerHeight = Config.HeaderHeight(entry.width, entry.countdownAt, props.Short)
		entry.height = Layout.sectionHeight(entry.grid, entry.headerHeight, Config.EmptyHeightPx)
	end
	local placements, bottom = Layout.compact(entries, Config.Tracks, Config.GapPx)
	local children, anchors = {}, {}
	for index, p in placements do
		local e = p.block
		anchors[e.id] = p.y + offset
		children[e.id] = c(Section, {
			Section = e,
			Class = e.class,
			Grid = e.grid,
			Position = UDim2.fromOffset(Layout.trackOffset(unit, p.index), p.y + offset),
			Width = e.width,
			Height = e.height,
			HeaderHeight = e.headerHeight,
			LayoutOrder = index,
			VisibleTop = props.VisibleTop,
			VisibleBottom = props.VisibleBottom,
			OnCardActivated = props.OnCardActivated,
			OnExpired = props.OnRefresh,
			SeasonState = props.SeasonState,
		})
	end
	return children, bottom + offset, anchors
end
return function(props)
	local safe = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local portrait = Responsive.isPortrait(safe.size, UI.Layout.PortraitMaxAspect)
	local size = props.Size
		or Responsive.panelSize(
			safe.size,
			UI.Layout.Panels.Shop,
			UI.Layout.PortraitMaxAspect,
			UI.Layout.ShortLandscapeMaxHeightPx
		)
	local short = not portrait and safe.size.Y <= UI.Layout.ShortLandscapeMaxHeightPx
	local inset = if short then T.LobbyLandscape.PanelInset elseif portrait then L.CompactInset else L.Inset
	local header = if portrait
		then L.PortraitHeaderHeight
		elseif short then T.LobbyLandscape.PanelHeader
		else L.HeaderHeight
	local scrollInset = if short then T.LobbyLandscape.ScrollInset else UI.Well.InsetPx
	local scrollPadding = if short then T.LobbyLandscape.ScrollPadding else Config.PaddingXPx
	local reduced = useReducedMotion()
	local scroller = React.useRef(nil)
	local width, setWidth =
		React.useState(math.max(1, size.X - inset * 2 - scrollInset * 2 - scrollPadding * 2 - Config.ScrollBarPx))
	local band, setBand = React.useState(0)
	local renderProps = table.clone(props)
	renderProps.Short = short
	-- Which slice of the canvas the sections should actually build. The band is
	-- quantised so an ordinary scroll re-renders a few times rather than every
	-- frame, and the margin builds the next cards before they are reached.
	local viewHeight = math.max(size.Y - header - inset - scrollInset * 2, 1)
	renderProps.VisibleTop = band * L.CullBand - L.CullMargin
	renderProps.VisibleBottom = band * L.CullBand + viewHeight + L.CullBand + L.CullMargin
	local featured, catalog = Composition.groups(props.Model, Config)
	local content, featureBottom = blocks(featured, width, 0, renderProps)
	local rest, bottom, anchors =
		blocks(catalog, width, if featureBottom > 0 then featureBottom + Config.GapPx else 0, renderProps)
	for id, child in rest do
		content[id] = child
	end
	content.Padding =
		c("UIPadding", { PaddingLeft = UDim.new(0, scrollPadding), PaddingRight = UDim.new(0, scrollPadding) })
	local status = props.Model.status
	if status == "Loading" or status == "Idle" or status == "Error" then
		content.Status = c("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, bottom + 12),
			Size = UDim2.new(1, 0, 0, 60),
			Font = T.Type.Display,
			Text = if status == "Error" then "SHOP UNAVAILABLE" else "LOADING SHOP…",
			TextSize = T.Type.Section,
			TextColor3 = C.Ink,
			TextWrapped = true,
			ZIndex = 8,
		})
		if status == "Error" then
			content.Retry = c(Button, {
				Text = "RETRY",
				Color = C.Pink,
				Shadow = false,
				OnActivated = props.OnRefresh,
				Native = { Position = UDim2.new(0.25, 0, 0, bottom + 80), Size = UDim2.new(0.5, 0, 0, 48), ZIndex = 8 },
			})
		end
		bottom += 150
	end
	local walletY = if portrait then 91 else header / 2
	local getWidth = if short then T.Layout.MinTarget else 156
	local titleSize = if portrait then 38 elseif short then T.Type.Section else T.Type.Title
	local titleHeight = if portrait then 60 elseif short then 48 else 76
	local titleTop = if portrait then 0 elseif short then 2 else -18
	local stickerWidth = math.ceil(TextService:GetTextSize("SHOP", titleSize, T.Type.Display, Vector2.new(4096, 200)).X)
		+ 36
	local decorated = not short and not portrait
	return c(Panel, {
		Tilt = if short then 0 else nil,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = props.Position or UI.Layout.PagePosition,
			Size = UDim2.fromOffset(size.X, size.Y),
			LayoutOrder = 5,
		},
	}, {
		EntranceScale = if props.TransitionScale then c("UIScale", { Scale = props.TransitionScale }) else nil,
		Title = c(Title, {
			Tilt = if short then 0 else nil,
			Text = "SHOP",
			TextSize = titleSize,
			Native = {
				Position = UDim2.fromOffset(inset, titleTop),
				Size = UDim2.fromOffset(if short then 150 else 226, titleHeight),
				ZIndex = 8,
			},
		}),
		TitleStar = if decorated
			then c(Icon, {
				Name = "Star",
				Color = C.Yellow,
				Native = {
					Position = UDim2.fromOffset(inset + stickerWidth - 10, titleTop - T.Layout.CompactGap),
					Size = UDim2.fromOffset(titleHeight * 0.7, titleHeight * 0.7),
					ZIndex = 10,
				},
			})
			else nil,
		TitleSparkle = if decorated
			then c(Icon, {
				Name = "Sparkle",
				Color = C.Cyan,
				Native = {
					Position = UDim2.fromOffset(inset - titleHeight * 0.55, titleTop + titleHeight * 0.3),
					Size = UDim2.fromOffset(titleHeight * 0.45, titleHeight * 0.45),
					ZIndex = 10,
				},
			})
			else nil,
		Bonks = c(BonksChip, {
			Candy = true,
			Amount = props.Model.bonks,
			HeightPx = 44,
			TextSize = T.Type.TileLabel,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -inset - getWidth - 12, 0, walletY),
			ZIndex = 8,
		}),
		GetBonks = c(Button, {
			Text = if short then "+" else "+ GET BONKS",
			TextSize = T.Type.Minimum,
			Color = C.Pink,
			Shadow = false,
			OnActivated = function()
				if scroller.current and anchors.Bonks then
					local target = Vector2.new(0, math.max(0, anchors.Bonks - 4))
					if reduced then
						scroller.current.CanvasPosition = target
					else
						TweenService:Create(
							scroller.current,
							TweenInfo.new(T.Motion.Open, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ CanvasPosition = target }
						):Play()
					end
				end
			end,
			Native = {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -inset, 0, walletY),
				Size = UDim2.fromOffset(getWidth, 44),
				ZIndex = 8,
			},
		}),
		Main = c(Well, {
			Candy = true,
			Native = {
				Position = UDim2.fromOffset(inset, header),
				Size = UDim2.new(1, -inset * 2, 1, -header - inset),
				ZIndex = 3,
			},
		}, {
			Content = c("ScrollingFrame", {
				ref = scroller,
				Active = true,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, bottom + Config.PaddingBottomPx),
				ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
				Position = UDim2.fromOffset(scrollInset, scrollInset),
				Size = UDim2.new(1, -scrollInset * 2, 1, -scrollInset * 2),
				ScrollBarImageColor3 = C.Pink,
				ScrollBarThickness = Config.ScrollBarPx,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Selectable = false,
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				ZIndex = 4,
				[React.Change.AbsoluteSize] = function(instance)
					setWidth(math.max(1, instance.AbsoluteSize.X - Config.ScrollBarPx - scrollPadding * 2))
				end,
				[React.Change.CanvasPosition] = function(instance)
					local reached = math.max(math.floor(instance.CanvasPosition.Y / L.CullBand), 0)
					setBand(function(current)
						return if current == reached then current else reached
					end)
				end,
			}, content),
		}),
	})
end
