--!strict
-- Reserve header and actions before allocating the season browser and preview.
local T = require(script.Parent.Parent.Tokens)
local S, K = T.SeasonRewards, T.Collectible
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

export type ShortPreviewMeasure = {
	track: number, -- track chip width ("PREMIUM • TIER 12")
	requirement: number, -- requirement chip width
	kind: number, -- item kind caption text width
}

-- Landscape-phone preview: a square card on the left and the copy stacked beside
-- it (Back + track chip, CAPS name, item kind, requirement chip). The stack always
-- fits the body well: when the roomy stack (two-line name, requirement on its own
-- row) is too tall, the name drops to one line and the requirement chip joins the
-- Back/track row, else the kind row; only when neither row has room does the chip
-- take the kind caption's row.
function Layout.shortPreview(bodyHeight: number, previewWidth: number, measure: ShortPreviewMeasure)
	local edge, pad, target = S.BrowserInset, K.Pad, T.Layout.MinTarget
	local faceSide = math.max(target, math.min(bodyHeight - (edge - pad) * 2, math.floor(previewWidth * 0.4)))
	local faceX = edge - pad
	local columnX = faceX + faceSide + edge - pad
	local columnWidth = math.max(1, previewWidth - columnX - edge)
	local trackX = columnX + target + K.TagInset
	local trackMax = math.max(1, columnWidth - target - K.TagInset)
	local trackWidth = math.min(measure.track, trackMax)
	local rowGap = K.TagInset
	local requirementHeight = if measure.requirement <= columnWidth then K.TagHeight else target
	local backRow = target + K.NameGap * 3
	local roomyName = K.NameHeight + K.NameGap * 2
	local roomy = backRow + roomyName + K.FooterHeight + K.NameGap + requirementHeight
	local mode: string, nameHeight: number, total: number
	if roomy <= bodyHeight - edge * 2 then
		mode, nameHeight, total = "Stacked", roomyName, roomy
	else
		-- One line of the largest name size plus breathing room.
		nameHeight = T.Type.TileLabel + pad
		local head = target + K.NameGap + nameHeight
		if trackWidth + rowGap + measure.requirement <= trackMax then
			mode, total = "TrackRow", head + K.FooterHeight
		elseif measure.kind + rowGap + measure.requirement <= columnWidth then
			mode, total = "KindRow", head + K.TagHeight
		else
			mode, total = "NoKind", head + K.NameGap + requirementHeight
		end
	end
	local top = math.max(0, math.floor((bodyHeight - total) / 2))
	local nameTop = top + (if mode == "Stacked" then backRow else target + K.NameGap)
	local detailsTop = nameTop + nameHeight
	local kindHeight = if mode == "KindRow" then K.TagHeight else K.FooterHeight
	local requirementX, requirementY, requirementWidth = columnX, detailsTop + K.FooterHeight + K.NameGap, columnWidth
	if mode == "TrackRow" then
		requirementX, requirementY = trackX + trackWidth + rowGap, top + (target - K.TagHeight) / 2
		requirementWidth = measure.requirement
	elseif mode == "KindRow" then
		requirementX, requirementY = columnX + measure.kind + rowGap, detailsTop
		requirementWidth = measure.requirement
	elseif mode == "NoKind" then
		requirementY = detailsTop + K.NameGap
	end
	return {
		mode = mode,
		top = top,
		total = total,
		face = { x = faceX, y = math.floor((bodyHeight - faceSide) / 2), side = faceSide },
		columnX = columnX,
		columnWidth = columnWidth,
		back = { x = columnX, y = top, size = target },
		track = { x = trackX, y = top + (target - K.TagHeight) / 2, maxWidth = trackMax },
		name = { y = nameTop, height = nameHeight },
		kind = if mode == "NoKind"
			then nil
			else {
				y = detailsTop,
				width = if mode == "KindRow" then measure.kind else columnWidth,
				height = kindHeight,
			},
		requirement = {
			x = requirementX,
			y = requirementY,
			width = requirementWidth,
			height = if requirementWidth >= measure.requirement then K.TagHeight else target,
		},
	}
end

return table.freeze(Layout)
