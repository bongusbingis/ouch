--!strict
-- Content-sized item inspection: art beside details, then one footer row that keeps the wallet with its actions.
local I = require(script.Parent.Parent.Tokens).Inspection

export type Frame = {
	portrait: boolean,
	short: boolean,
	compact: boolean,
	edge: number,
	width: number,
	inset: number,
	contentInset: number,
	gap: number,
	headerHeight: number,
	titleTop: number,
	titleHeight: number,
	closeTop: number,
	innerWidth: number,
	stacked: boolean,
	art: number,
	detailsWidth: number,
	maxHeight: number,
	buttonHeight: number,
	chipHeight: number,
	listRowHeight: number,
	auditionHeight: number,
	footerGap: number,
	footerWidth: number,
}

export type Content = {
	detailsHeight: number,
	listRows: number,
	actionCount: number,
	hasWallet: boolean,
	hasStatus: boolean,
}

export type Result = {
	height: number,
	wellTop: number,
	wellHeight: number,
	wellCanvas: number,
	scroll: boolean,
	art: number,
	rowHeight: number,
	detailsBlock: number,
	listHeight: number,
	listBlock: number,
	listScrolls: boolean,
	listTop: number,
	footerTop: number,
	footerHeight: number,
	walletRowOnTop: boolean,
	columns: number,
	actionWidth: number,
	buttonRows: number,
	buttonsTop: number,
	buttonsHeight: number,
}

local Layout = {}

function Layout.frame(size: Vector2): Frame
	local portrait = size.X <= size.Y
	local short = not portrait and size.Y <= I.ShortMaxHeight
	local compact = short or size.X < I.CompactMaxWidth
	local edge = if compact then I.CompactEdge else I.Edge
	local width = math.max(math.min(I.MaxWidth, size.X - edge * 2), 1)
	local inset = if compact then I.CompactInset else I.Inset
	local contentInset = if compact then I.CompactContentInset else I.ContentInset
	local gap = if compact then I.CompactGap else I.Gap
	local innerWidth = width - inset * 2 - contentInset * 2
	local stacked = innerWidth < I.StackedMaxWidth
	local art = if short then I.ShortArt else math.clamp(math.floor(innerWidth * I.ArtFraction), I.ArtMin, I.Art)
	return {
		portrait = portrait,
		short = short,
		compact = compact,
		edge = edge,
		width = width,
		inset = inset,
		contentInset = contentInset,
		gap = gap,
		headerHeight = if short then I.ShortHeaderHeight elseif compact then I.CompactHeaderHeight else I.HeaderHeight,
		titleTop = if compact then I.CompactTitleTop else I.TitleTop,
		titleHeight = if compact then I.CompactTitleHeight else I.TitleHeight,
		closeTop = if compact then I.CompactCloseTop else I.CloseTop,
		innerWidth = innerWidth,
		stacked = stacked,
		art = art,
		detailsWidth = innerWidth - art - gap,
		maxHeight = math.max(size.Y - edge * 2, 1),
		buttonHeight = if short then I.ShortButtonHeight elseif compact then I.CompactButtonHeight else I.ButtonHeight,
		chipHeight = if short then I.CompactChipHeight else I.ChipHeight,
		listRowHeight = if compact then I.CompactListRowHeight else I.ListRowHeight,
		auditionHeight = if compact then I.CompactAuditionHeight else I.AuditionHeight,
		footerGap = if compact then I.CompactFooterGap else I.FooterGap,
		footerWidth = width - inset * 2,
	}
end

local function listBlockFor(frame: Frame, listRows: number): (number, number)
	local visible = math.min(listRows, I.ListMaxRows)
	if visible <= 0 then
		return 0, 0
	end
	local listHeight = visible * frame.listRowHeight + (visible - 1) * I.ListGap
	return listHeight, I.ListCaptionHeight + I.ListGap + listHeight
end

local function wellFor(frame: Frame, content: Content, art: number, listBlock: number): (number, number, number)
	local hasList = content.listRows > 0
	local detailsBlock = content.detailsHeight + (if hasList and not frame.stacked then frame.gap + listBlock else 0)
	local rowHeight = math.max(art, detailsBlock)
	local canvas = frame.contentInset * 2 + rowHeight + (if hasList and frame.stacked then frame.gap + listBlock else 0)
	return canvas, rowHeight, detailsBlock
end

function Layout.resolve(frame: Frame, content: Content): Result
	local listHeight, listBlock = listBlockFor(frame, content.listRows)
	local actions = content.actionCount
	local hasWalletRow = content.hasWallet or content.hasStatus
	local columns, actionWidth, walletRowOnTop = 0, 0, false
	if actions > 0 then
		local reserved = (if content.hasWallet then I.ChipReserve + frame.footerGap else 0)
			+ (if content.hasStatus then I.StatusMinWidth + frame.footerGap else 0)
		local shared = math.floor((frame.footerWidth - reserved - (actions - 1) * frame.footerGap) / actions)
		if frame.portrait or (hasWalletRow and shared < I.ActionMinWidth) then
			walletRowOnTop = hasWalletRow
			columns = math.clamp(
				math.floor((frame.footerWidth + frame.footerGap) / (I.ActionMinWidth + frame.footerGap)),
				1,
				actions
			)
			actionWidth = math.floor((frame.footerWidth - (columns - 1) * frame.footerGap) / columns)
		else
			columns = actions
			actionWidth = math.min(I.ActionWidth, shared)
		end
	end
	local buttonRows = if actions > 0 then math.ceil(actions / columns) else 0
	local buttonsHeight = buttonRows * frame.buttonHeight + math.max(buttonRows - 1, 0) * frame.footerGap
	local footerHeight = if walletRowOnTop
		then frame.chipHeight + frame.footerGap + buttonsHeight
		elseif actions > 0 then math.max(buttonsHeight, if hasWalletRow then frame.chipHeight else 0)
		elseif hasWalletRow then frame.chipHeight
		else 0
	local fixed = frame.headerHeight + (if footerHeight > 0 then frame.footerGap + footerHeight else 0) + frame.inset
	local art = frame.art
	local canvas, rowHeight, detailsBlock = wellFor(frame, content, art, listBlock)
	local wellHeight, scroll = canvas, false
	if fixed + canvas > frame.maxHeight then
		scroll = true
		wellHeight = math.max(frame.maxHeight - fixed, frame.contentInset * 2 + I.ArtFloor)
		art = math.max(math.min(art, wellHeight - frame.contentInset * 2), I.ArtFloor)
		canvas, rowHeight, detailsBlock = wellFor(frame, content, art, listBlock)
		canvas = math.max(canvas, wellHeight)
	end
	local footerTop = frame.headerHeight + wellHeight + frame.footerGap
	return {
		height = fixed + wellHeight,
		wellTop = frame.headerHeight,
		wellHeight = wellHeight,
		wellCanvas = canvas,
		scroll = scroll,
		art = art,
		rowHeight = rowHeight,
		detailsBlock = detailsBlock,
		listHeight = listHeight,
		listBlock = listBlock,
		listScrolls = content.listRows > I.ListMaxRows,
		listTop = if frame.stacked
			then frame.contentInset + rowHeight + frame.gap
			else frame.contentInset + content.detailsHeight + frame.gap,
		footerTop = footerTop,
		footerHeight = footerHeight,
		walletRowOnTop = walletRowOnTop,
		columns = columns,
		actionWidth = actionWidth,
		buttonRows = buttonRows,
		buttonsTop = if walletRowOnTop then frame.chipHeight + frame.footerGap else 0,
		buttonsHeight = buttonsHeight,
	}
end

return Layout
