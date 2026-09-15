--!strict
-- Reserve header and actions before allocating the season browser and preview.
local S = require(script.Parent.Parent.Tokens).SeasonRewards
local Layout = {}

function Layout.resolve(size: Vector2, showPremium: boolean?)
	local short = size.Y < S.ShortHeight
	local edge = if short then S.ShortEdge else S.Edge
	local width = math.min(size.X - edge * 2, S.MaxWidth)
	local height = math.min(size.Y - edge * 2, S.MaxHeight)
	local compact = short or width < 760
	local portrait = width < 540
	local inset = if short then S.ShortInset else if compact then S.CompactInset else S.Inset
	local gap = if short then S.ShortGap else if compact then S.CompactGap else S.Gap
	local titleHeight = if short then S.ShortTitleHeight else if portrait then S.PortraitTitleHeight else S.TitleHeight
	local statusTop = inset + titleHeight + (if short then 4 else S.HeaderGap)
	local statusHeight = if short then S.ShortStatusHeight else S.StatusHeight
	local bodyTop = statusTop + statusHeight + gap
	local footerHeight = if portrait and showPremium
		then S.PortraitPurchaseFooterHeight
		else if short then S.ShortFooterHeight else if compact then S.CompactFooterHeight else S.FooterHeight
	local footerTop = height - inset - footerHeight
	local bodyHeight = footerTop - gap - bodyTop
	local innerWidth = width - inset * 2
	local previewWidth = if compact
		then innerWidth
		else math.min(S.PreviewMaxWidth, math.floor(innerWidth * S.PreviewFraction))
	return {
		width = width,
		height = height,
		inset = inset,
		gap = gap,
		compact = compact,
		short = short,
		portrait = portrait,
		titleHeight = titleHeight,
		statusTop = statusTop,
		statusHeight = statusHeight,
		bodyTop = bodyTop,
		bodyHeight = bodyHeight,
		footerTop = footerTop,
		footerHeight = footerHeight,
		innerWidth = innerWidth,
		previewWidth = previewWidth,
		tracksX = if compact then 0 else previewWidth + gap,
		tracksWidth = if compact then innerWidth else innerWidth - previewWidth - gap,
	}
end

function Layout.browser(width: number, short: boolean?)
	local inset = if short then 0 else S.BrowserInset
	local tabHeight = if short then S.ShortTabHeight else S.TabHeight
	local cardsTop = if short then 0 else inset + tabHeight + S.TabGap
	local usable = width - inset * 2 - S.ScrollPadding * 2 - 6
	local columns = math.clamp(math.floor((usable + S.CardGap) / (S.CardMinWidth + S.CardGap)), 1, 3)
	return {
		inset = inset,
		tabHeight = tabHeight,
		cardsTop = cardsTop,
		cardsX = if short then S.ShortTabWidth + S.TabGap else inset,
		tabWidth = if short then S.ShortTabWidth else math.min(S.TabMaxWidth, (width - inset * 2 - S.TabGap) / 2),
		columns = columns,
		cardWidth = math.floor((usable - (columns - 1) * S.CardGap) / columns),
	}
end

return table.freeze(Layout)
