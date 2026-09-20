-- Name: PostMatchLayout.luau
-- Author: Jack C.
-- Description: Pure geometry for the candy post-match results screen: fits the outcome header, the podium stage or standings, the personal rewards panel and the action dock into the safe area, stacking or compacting the regions on narrow, short and portrait screens while every control keeps a 44-pixel target.
-- Created: 2026-09-15

--!strict

local T = require(script.Parent.Parent.Tokens)
local R = T.Results

local PostMatchLayout = {}

export type Rect = { position: Vector2, size: Vector2 }

export type Layout = {
	compact: boolean,
	stacked: boolean,
	twoRowFooter: boolean,
	showStatus: boolean,
	showStage: boolean,
	showShop: boolean,
	edge: number,
	gap: number,
	inset: number,
	canvas: Rect,
	headerHeight: number,
	kicker: Rect,
	title: Rect,
	detail: Rect,
	scores: Rect,
	shop: Rect?,
	stage: Rect,
	personal: Rect,
	footer: Rect,
	countdown: Rect,
	status: Rect,
	secondary: Rect,
	primary: Rect,
	titleSize: number,
	detailSize: number,
	actionHeight: number,
	nameplateHeight: number,
	nameplateWidth: number,
	nameplateBadge: number,
	statRowHeight: number,
	rewardChipHeight: number,
	standingsRowHeight: number,
}

local function rect(x: number, y: number, width: number, height: number): Rect
	return {
		position = Vector2.new(math.floor(x), math.floor(y)),
		size = Vector2.new(math.max(math.floor(width), 0), math.max(math.floor(height), 0)),
	}
end

local function personalHeight(result: any, rowHeight: number, chipHeight: number, inset: number): number
	local sections = 1
	local contentHeight = chipHeight
	local rewards = result.rewards
	if rewards and ((rewards.xpMultiplier or 1) > 1 or (rewards.bonksMultiplier or 1) > 1) then
		sections += 1
		contentHeight += 18
	end
	local statCount = 0
	for _, stat in result.personalStats or {} do
		if stat.id ~= "Placement" then
			statCount += 1
		end
	end
	if statCount > 0 then
		sections += 1
		contentHeight += statCount * rowHeight + (statCount - 1) * 2 + 12
	end
	if result.seasonProgress then
		sections += 1
		contentHeight += R.SeasonHeight
	end
	local challengeCount = if result.challenges then #result.challenges else 0
	if challengeCount > 0 then
		sections += 1
		contentHeight += challengeCount * rowHeight + (challengeCount - 1) * 2 + 12
	end
	local unlockCount = if result.unlocks then #result.unlocks else 0
	sections += unlockCount
	contentHeight += unlockCount * (rowHeight + 8)
	contentHeight += (sections - 1) * R.RowGap
	local scrollTop = inset + R.SectionHeight + 2
	return scrollTop + R.PersonalScrollInset * 2 + contentHeight + inset
end

function PostMatchLayout.resolve(safeSize: Vector2, wantShop: boolean, result: any?): Layout
	local compact = safeSize.X < R.NarrowWidth or safeSize.Y < R.ShortHeight
	local portrait = safeSize.Y > safeSize.X
	local stacked = portrait or safeSize.X < R.StackWidth
	local edge = if compact then R.CompactEdge else R.Edge
	local gap = if compact then R.CompactGap else R.Gap
	local inset = if compact then R.CompactPanelInset else R.PanelInset
	local canvasWidth = math.floor(math.min(R.MaxWidth, safeSize.X - edge * 2))
	local canvasHeight = math.floor(safeSize.Y - edge * 2)
	local canvas = rect((safeSize.X - canvasWidth) / 2, edge, canvasWidth, canvasHeight)

	local kickerHeight = if compact then R.CompactKickerHeight else R.KickerHeight
	local titleHeight = if compact then R.CompactTitleHeight else R.TitleHeight
	local detailHeight = if compact then R.CompactDetailHeight else R.DetailHeight
	local controlWidth = if compact then R.CompactControlWidth else R.ControlWidth
	local showShop = wantShop and not compact and canvasWidth >= R.ShopMinWidth
	local controlsWidth = controlWidth + (if showShop then R.ControlGap + controlWidth else 0)
	local headerHeight = kickerHeight + R.TitleGap + titleHeight + R.DetailGap + detailHeight
	local textWidth = canvasWidth - controlsWidth - gap
	local kicker = rect(0, 0, math.min(R.KickerMaxWidth, textWidth), kickerHeight)
	local title = rect(0, kickerHeight + R.TitleGap, textWidth, titleHeight)
	local detail = rect(0, title.position.Y + titleHeight + R.DetailGap, textWidth, detailHeight)
	local scores = rect(canvasWidth - controlWidth, 0, controlWidth, R.ControlHeight)
	local shop = if showShop
		then rect(scores.position.X - R.ControlGap - controlWidth, 0, controlWidth, R.ControlHeight)
		else nil

	local footerInset = if compact then R.CompactFooterInset else R.FooterInset
	local actionHeight = if compact then R.CompactActionHeight else R.ActionHeight
	local primaryWidth = if compact then R.CompactPrimaryWidth else R.PrimaryWidth
	local secondaryWidth = if compact then R.CompactSecondaryWidth else R.SecondaryWidth
	local countdownWidth = if compact then R.CompactCountdownWidth else R.CountdownWidth
	local contentWidth = canvasWidth - footerInset * 2
	if primaryWidth + gap + secondaryWidth > contentWidth then
		local share = contentWidth - gap
		primaryWidth = math.floor(share * R.PrimaryShare)
		secondaryWidth = share - primaryWidth
	end
	local oneRowStatus = contentWidth - countdownWidth - secondaryWidth - primaryWidth - gap * 3
	local twoRowFooter = oneRowStatus < 0
	local showStatus = twoRowFooter or oneRowStatus >= R.StatusMinWidth
	local rowHeight = math.max(actionHeight, R.CountdownHeight)
	local footerHeight = if twoRowFooter
		then footerInset * 2 + R.CountdownHeight + R.RowGap + actionHeight
		else footerInset * 2 + rowHeight
	local footer = rect(0, canvasHeight - footerHeight, canvasWidth, footerHeight)
	local countdown, status, secondary, primary
	if twoRowFooter then
		countdown = rect(footerInset, footerInset, countdownWidth, R.CountdownHeight)
		status = rect(
			footerInset + countdownWidth + gap,
			footerInset,
			contentWidth - countdownWidth - gap,
			R.CountdownHeight
		)
		local actionsTop = footerInset + R.CountdownHeight + R.RowGap
		primary = rect(canvasWidth - footerInset - primaryWidth, actionsTop, primaryWidth, actionHeight)
		secondary = rect(primary.position.X - gap - secondaryWidth, actionsTop, secondaryWidth, actionHeight)
	else
		local actionsTop = footerInset + (rowHeight - actionHeight) / 2
		countdown =
			rect(footerInset, footerInset + (rowHeight - R.CountdownHeight) / 2, countdownWidth, R.CountdownHeight)
		primary = rect(canvasWidth - footerInset - primaryWidth, actionsTop, primaryWidth, actionHeight)
		secondary = rect(primary.position.X - gap - secondaryWidth, actionsTop, secondaryWidth, actionHeight)
		local statusX = footerInset + countdownWidth + gap
		status = rect(statusX, footerInset, secondary.position.X - gap - statusX, rowHeight)
	end

	local bodyTop = headerHeight + gap
	local bodyHeight = footer.position.Y - gap - bodyTop
	local personalWidth = math.clamp(math.floor(canvasWidth * R.PersonalFraction), R.PersonalMin, R.PersonalMax)
	if not stacked and canvasWidth - personalWidth - gap < R.StageMinWidth then
		stacked = true
	end
	local showStage = true
	local stage, personal
	if stacked then
		local stageHeight = math.max(R.StageMinHeight, math.floor(bodyHeight * R.StageFraction))
		if bodyHeight - stageHeight - gap < R.PersonalMinHeight then
			showStage = false
			stage = rect(0, bodyTop, canvasWidth, 0)
			personal = rect(0, bodyTop, canvasWidth, bodyHeight)
		else
			stage = rect(0, bodyTop, canvasWidth, stageHeight)
			personal = rect(0, bodyTop + stageHeight + gap, canvasWidth, bodyHeight - stageHeight - gap)
		end
	else
		stage = rect(0, bodyTop, canvasWidth - personalWidth - gap, bodyHeight)
		local panelHeight = if result
			then math.min(
				bodyHeight,
				math.max(
					R.PersonalComfortHeight,
					personalHeight(
						result,
						if compact then R.CompactStatRowHeight else R.StatRowHeight,
						if compact then R.CompactRewardChipHeight else R.RewardChipHeight,
						inset
					)
				)
			)
			else bodyHeight
		personal = rect(canvasWidth - personalWidth, bodyTop, personalWidth, panelHeight)
	end

	return {
		compact = compact,
		stacked = stacked,
		twoRowFooter = twoRowFooter,
		showStatus = showStatus,
		showStage = showStage,
		showShop = showShop,
		edge = edge,
		gap = gap,
		inset = inset,
		canvas = canvas,
		headerHeight = headerHeight,
		kicker = kicker,
		title = title,
		detail = detail,
		scores = scores,
		shop = shop,
		stage = stage,
		personal = personal,
		footer = footer,
		countdown = countdown,
		status = status,
		secondary = secondary,
		primary = primary,
		titleSize = if compact then R.CompactTitleSize else R.TitleSize,
		detailSize = if compact then R.CompactDetailSize else R.DetailSize,
		actionHeight = actionHeight,
		nameplateHeight = if compact then R.CompactNameplateHeight else R.NameplateHeight,
		nameplateWidth = math.min(R.NameplateMaxWidth, math.floor(stage.size.X * R.NameplateWidth)),
		nameplateBadge = if compact then R.CompactNameplateBadge else R.NameplateBadge,
		statRowHeight = if compact then R.CompactStatRowHeight else R.StatRowHeight,
		rewardChipHeight = if compact then R.CompactRewardChipHeight else R.RewardChipHeight,
		standingsRowHeight = if compact then R.CompactStandingsRowHeight else R.StandingsRowHeight,
	}
end

return table.freeze(PostMatchLayout)
