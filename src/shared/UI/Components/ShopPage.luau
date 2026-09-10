-- Description: The storefront page, arranging the view model's sections and limited-time offers into the responsive dashboard rows the shop layout resolves for the measured content width.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local ActivityDots = require(script.Parent.ActivityDots)
local BonksChip = require(script.Parent.BonksChip)
local PageTitle = require(script.Parent.PageTitle)
local ResponsiveText = require(script.Parent.ResponsiveText)
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local ShopSection = require(script.Parent.Shop.ShopSection)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local ShopLayout = require(script.Parent.Parent.Models.ShopLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)

local c = React.createElement

local ShopUI = UIConfig.Layout.Shop

local function styleFor(sectionId: string): any
	return ShopUI.Sections[sectionId] or ShopUI.DefaultSection
end

local function classFor(entry, unit: number, shortHeight: number?): any
	local class = ShopUI.CardClasses[entry.style.Class]
	if shortHeight then
		class = table.clone(class)
		class.Layout = "Split"
		class.ArtScale = 0.32
		class.MinPx = math.max(class.MinPx, ShopUI.ShortCardWidthPx)
		class.MaxPx = ShopLayout.spanWidth(unit, entry.span or entry.style.Span, ShopUI.GapPx)
		class.MinHeightPx = shortHeight
		class.MaxHeightPx = shortHeight
	end
	return class
end

-- A limited-time offer becomes a one-card block so the promotional row shares
-- the storefront's header, countdown and card plumbing rather than a parallel
-- set of its own. Its badge is already the name of the offer.
local function promoEntry(model, card): any
	return {
		id = card.id,
		title = card.badge or string.upper(card.kind),
		countdownAt = if card.kind == "Bundle" then model.bundleExpireAt else model.featuredExpireAt,
		cards = { card },
		style = ShopUI.PromoSection,
	}
end

-- A block with more cards than one row of its span can hold keeps that row where
-- the composition wants it and hands the remainder to a second block further
-- down, so the cards stay full size instead of being flattened to fit.
local function withOverflow(entry, unit: number, shortHeight: number?): (any, any?)
	local overflow = entry.style.Overflow
	if overflow == nil then
		return entry, nil
	end
	local class = classFor(entry, unit, shortHeight)
	local width = ShopLayout.spanWidth(unit, entry.style.Span, ShopUI.GapPx)
	local grid = ShopLayout.grid(width, #entry.cards, class, ShopUI.CardGapPx, entry.style.MaxColumns)
	local featured, rest = ShopLayout.splitFirstRow(entry.cards, grid.columns)
	if #rest == 0 then
		return entry, nil
	end
	local kept = table.clone(entry)
	kept.cards = featured
	return kept,
		{
			id = overflow.Id,
			title = overflow.Title,
			countdownAt = nil,
			cards = rest,
			style = table.clone(entry.style),
			span = overflow.Span,
		}
end

-- Blocks come from the configured reading order, not from the view model's own,
-- so a section it gains later still lands somewhere (the trailing "Rest" entry)
-- and one it stops emitting simply disappears.
local function orderedEntries(model, unit: number, shortHeight: number?): { any }
	local order = {}
	local byId = {}
	for _, section in model.sections do
		local style = styleFor(section.id)
		local entry, overflow = withOverflow({
			id = section.id,
			title = style.Title or section.title,
			countdownAt = section.countdownAt,
			cards = section.cards,
			style = style,
		}, unit, shortHeight)
		table.insert(order, entry)
		byId[entry.id] = entry
		if overflow then
			table.insert(order, overflow)
			byId[overflow.id] = overflow
		end
	end

	local entries = {}
	for _, token in ShopUI.Order do
		if token == "Promo" then
			for _, card in model.hero do
				table.insert(entries, promoEntry(model, card))
			end
		elseif token == "Rest" then
			for _, entry in order do
				if not entry.taken then
					entry.taken = true
					table.insert(entries, entry)
				end
			end
		else
			local entry = byId[token]
			if entry ~= nil and not entry.taken then
				entry.taken = true
				table.insert(entries, entry)
			end
		end
	end
	return entries
end

-- Every block keeps its configured span while one card of its class is still
-- legible at that width. The moment any block would have to be widened, the
-- dashboard cannot tile any more, so the whole storefront becomes a single
-- column rather than a grid with a permanently empty lane down one side.
local function resolveSpans(entries, unit: number): ()
	local full = false
	for _, entry in entries do
		local class = ShopUI.CardClasses[entry.style.Class]
		local wanted = entry.span or entry.style.Span or ShopUI.Tracks
		entry.span = ShopLayout.resolveSpan(wanted, ShopUI.SpanSteps, ShopUI.Tracks, unit, ShopUI.GapPx, class.MinPx)
		full = full or entry.span > wanted
	end
	if full then
		for _, entry in entries do
			entry.span = ShopUI.Tracks
		end
	end
end

local function measure(entry, unit: number, shortHeight: number?): ()
	entry.class = classFor(entry, unit, shortHeight)
	entry.width = ShopLayout.spanWidth(unit, entry.span, ShopUI.GapPx)
	entry.grid = ShopLayout.grid(entry.width, #entry.cards, entry.class, ShopUI.CardGapPx, entry.style.MaxColumns)
	entry.height = ShopLayout.sectionHeight(entry.grid, ShopUI.HeaderHeightPx, ShopUI.EmptyHeightPx)
	local occupied = math.min(entry.grid.columns, #entry.cards)
	entry.unusedWidth = if occupied == 0
		then 0
		else entry.width - occupied * entry.grid.cardWidth - (occupied - 1) * ShopUI.CardGapPx
end

local function renderBlocks(model, contentWidth: number, handlers, shortHeight: number?): ({ [string]: any }, number)
	local unit = ShopLayout.trackUnit(contentWidth, ShopUI.Tracks, ShopUI.GapPx)
	local entries = orderedEntries(model, unit, shortHeight)
	resolveSpans(entries, unit)
	for _, entry in entries do
		measure(entry, unit, shortHeight)
		-- Full-width sections retain the pass row and the phone composition.
		-- Secondary sections can use a narrower configured track span when it
		-- avoids the empty space beneath a shorter neighbouring offer.
		if entry.span < ShopUI.Tracks then
			local alternatives = {}
			for _, span in ShopUI.SpanSteps do
				if span < entry.span and ShopLayout.spanWidth(unit, span, ShopUI.GapPx) >= entry.class.MinPx then
					local alternative = table.clone(entry)
					alternative.span = span
					measure(alternative, unit, shortHeight)
					table.insert(alternatives, alternative)
				end
			end
			entry.alternatives = alternatives
		end
	end
	local placements, bottom = ShopLayout.compact(entries, ShopUI.Tracks, ShopUI.GapPx)
	local children = {}
	for order, placement in placements do
		local entry = placement.block
		children[entry.id] = c(ShopSection, {
			Section = entry,
			Class = entry.class,
			Grid = entry.grid,
			Position = UDim2.fromOffset(ShopLayout.trackOffset(unit, placement.index), placement.y),
			Width = entry.width,
			Height = entry.height,
			LayoutOrder = order,
			OnCardActivated = handlers.OnCardActivated,
			OnExpired = handlers.OnRefresh,
		})
	end
	return children, bottom
end

local STATUS_HEIGHT_PX = 130

local function statusRow(model, top: number, onRefresh): any
	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 0, STATUS_HEIGHT_PX),
	}, {
		Text = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 36,
			Native = {
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.1, 0.08),
				Size = UDim2.fromScale(0.8, 0.42),
				Text = if model.status == "Error" then "SHOP UNAVAILABLE" else "LOADING SHOP",
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 6,
			},
		}),
		Retry = if model.status == "Error"
			then c(ShopPriceButton, {
				Enabled = true,
				Position = UDim2.fromScale(0.5, 0.94),
				Size = UDim2.new(0.3, 0, 0, 44),
				Text = "RETRY",
				OnActivated = onRefresh,
			})
			else nil,
		Activity = if model.status ~= "Error"
			then c(ActivityDots, {
				Active = true,
				Native = {
					Position = UDim2.fromScale(0.5, 0.68),
					Size = UDim2.fromScale(0.1, 0.2),
					ZIndex = 6,
				},
			})
			else nil,
	})
end

-- The width the rows are laid out against, before the scroller has been
-- measured: the panel is already known on the first frame, so the dashboard
-- renders at its final proportions instead of reflowing once.
local function estimateContentWidth(panelWidth: number): number
	local scrollerWidth = panelWidth * ShopUI.MainSizeScale.X * ShopUI.ContentSizeScale.X
	return math.max(math.floor(scrollerWidth) - ShopUI.ScrollBarPx - ShopUI.PaddingXPx * 2, 1)
end

export type Props = {
	Model: any,
	Position: UDim2?,
	OnCardActivated: (any) -> (),
	OnRefresh: () -> (),
}

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local panelSize = ResponsiveLayout.panelSize(
		safeArea.size,
		UIConfig.Layout.Panels.Shop,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local model = props.Model
	local contentWidth, setContentWidth = React.useState(estimateContentWidth(panelSize.X))

	local short = not ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
		and safeArea.size.Y <= UIConfig.Layout.ShortLandscapeMaxHeightPx
	local headerBand = if short then 44 else 72
	local bottomPad = if short then 8 else 18
	local shortHeight = if short
		then math.clamp(
			math.floor((panelSize.Y - headerBand - bottomPad) * ShopUI.ContentSizeScale.Y) - ShopUI.HeaderHeightPx - 6,
			128,
			ShopUI.ShortCardHeightPx
		)
		else nil
	local content, bottom = renderBlocks(model, contentWidth, props, shortHeight)
	content.UIPadding = c("UIPadding", {
		PaddingLeft = UDim.new(0, ShopUI.PaddingXPx),
		PaddingRight = UDim.new(0, ShopUI.PaddingXPx),
	})
	-- Blocks are positioned absolutely, so the status strip is placed after them
	-- rather than relying on a list layout to keep it clear of the storefront.
	if model.status == "Loading" or model.status == "Idle" or model.status == "Error" then
		content.Status = statusRow(model, if bottom > 0 then bottom + ShopUI.GapPx else 0, props.OnRefresh)
		bottom += (if bottom > 0 then ShopUI.GapPx else 0) + STATUS_HEIGHT_PX
	end

	return c("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = UIConfig.Layout.PageSurface.Image,
		LayoutOrder = 5,
		Position = props.Position or UIConfig.Layout.PagePosition,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = UIConfig.Layout.PageSurface.SliceCenter,
		SliceScale = UIConfig.Layout.PageSurface.SliceScale,
		Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
	}, {
		Title = c(PageTitle, {
			Text = "SHOP",
			TextSize = if short then 26 else 42,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, if short then 8 else 14),
				Size = UDim2.new(0.48, 0, 0, if short then 30 else 48),
				ZIndex = 5,
			},
		}),
		Refreshing = if model.status == "Refreshing"
			then c(ActivityDots, {
				Active = true,
				Native = {
					Position = UDim2.fromScale(0.18, 0.09),
					Size = UDim2.fromScale(0.08, 0.025),
					ZIndex = 6,
				},
			})
			else nil,
		Bonks = c(BonksChip, {
			Amount = model.bonks,
			HeightPx = if short then 32 else 40,
			TextSize = if short then 18 else 22,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1 - (1 - ShopUI.MainSizeScale.X) / 2, 0, 0, headerBand / 2),
			ZIndex = 5,
		}),
		Main = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, headerBand),
			Size = UDim2.new(ShopUI.MainSizeScale.X, 0, 1, -headerBand - bottomPad),
		}, {
			Content = c("ScrollingFrame", {
				Active = true,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				-- The packer already knows the exact extent of what it placed, so
				-- the canvas is set from that rather than measured back off the
				-- absolutely positioned blocks.
				CanvasSize = UDim2.fromOffset(0, bottom + ShopUI.PaddingBottomPx),
				ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
				Position = UDim2.fromScale(0.025, 0.05),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarImageColor3 = Color3.new(1, 1, 1),
				ScrollBarImageTransparency = 0.1,
				ScrollBarThickness = ShopUI.ScrollBarPx,
				Selectable = false,
				Size = UDim2.fromScale(ShopUI.ContentSizeScale.X, ShopUI.ContentSizeScale.Y),
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				-- The scroll bar is inset out of the canvas, so the usable width is
				-- the frame less the bar and the content padding. Deriving it from
				-- AbsoluteSize rather than AbsoluteWindowSize keeps the measurement
				-- independent of whether the bar is currently showing, which the
				-- laid-out height would otherwise feed back into.
				[React.Change.AbsoluteSize] = function(instance)
					setContentWidth(math.max(instance.AbsoluteSize.X - ShopUI.ScrollBarPx - ShopUI.PaddingXPx * 2, 1))
				end,
			}, content),
		}),
	})
end
