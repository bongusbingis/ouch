--!strict

local ResponsiveLayout = {}

export type PanelVariant = {
	WidthScale: number,
	HeightScale: number,
	MaxSize: Vector2,
	AspectRatio: number?,
	ShortHeightScale: number?,
}

export type PanelSpec = {
	Portrait: PanelVariant,
	Landscape: PanelVariant,
}

export type SafeRect = {
	position: Vector2,
	size: Vector2,
}

export type MenuToggleLayout = {
	labelPosition: Vector2,
	labelSize: Vector2,
	keycapPosition: Vector2,
	keycapSize: Vector2,
}

export type SplashPanelConfig = {
	EdgePaddingPx: number,
	GapPx: number,
	Landscape: {
		DailyBottomScale: number,
		SeasonTopScale: number,
		QuestsTopScale: number,
	},
	Portrait: {
		WidthScale: number,
		TopScale: number,
		BottomScale: number,
		GapPx: number,
		SeasonWeight: number,
		DailyWeight: number,
		QuestsWeight: number,
	},
	Daily: PanelVariant,
	Season: PanelVariant,
	Quests: PanelVariant,
}

export type SplashPanelRect = {
	position: Vector2,
	size: Vector2,
}

export type SplashPanelLayout = {
	portrait: boolean,
	daily: SplashPanelRect,
	season: SplashPanelRect,
	quests: SplashPanelRect,
}

function ResponsiveLayout.isPortrait(size: Vector2, maxAspect: number): boolean
	return size.Y > 0 and size.X / size.Y <= maxAspect
end

function ResponsiveLayout.safeRect(
	viewport: Vector2,
	insetMin: Vector2,
	insetMax: Vector2,
	parentIsFullScreen: boolean
): SafeRect
	local maximum =
		Vector2.new(math.clamp(insetMax.X, insetMin.X, viewport.X), math.clamp(insetMax.Y, insetMin.Y, viewport.Y))
	local minimum = Vector2.new(math.clamp(insetMin.X, 0, maximum.X), math.clamp(insetMin.Y, 0, maximum.Y))
	return {
		position = if parentIsFullScreen then minimum else Vector2.new(0, 0),
		size = Vector2.new(maximum.X - minimum.X, maximum.Y - minimum.Y),
	}
end

function ResponsiveLayout.panelSize(
	available: Vector2,
	spec: PanelSpec,
	portraitMaxAspect: number,
	shortLandscapeMaxHeight: number?
): Vector2
	local portrait = ResponsiveLayout.isPortrait(available, portraitMaxAspect)
	local variant = if portrait then spec.Portrait else spec.Landscape
	local short = not portrait and shortLandscapeMaxHeight ~= nil and available.Y <= shortLandscapeMaxHeight
	local heightScale = if short and variant.ShortHeightScale then variant.ShortHeightScale else variant.HeightScale
	local width = math.min(available.X * variant.WidthScale, variant.MaxSize.X)
	local height = math.min(available.Y * heightScale, variant.MaxSize.Y)
	if variant.AspectRatio then
		local aspect = variant.AspectRatio
		if width / math.max(height, 1) > aspect then
			width = height * aspect
		else
			height = width / aspect
		end
	end
	return Vector2.new(math.max(math.floor(width), 1), math.max(math.floor(height), 1))
end

function ResponsiveLayout.splashPanels(
	available: Vector2,
	config: SplashPanelConfig,
	portraitMaxAspect: number,
	shortLandscapeMaxHeight: number?
): SplashPanelLayout
	local portrait = ResponsiveLayout.isPortrait(available, portraitMaxAspect)
	if portrait then
		local portraitConfig = config.Portrait
		local width = math.max(math.floor(available.X * portraitConfig.WidthScale), 1)
		local left = math.floor((available.X - width) * 0.5)
		local top = math.floor(available.Y * portraitConfig.TopScale)
		local bottom = math.floor(available.Y * portraitConfig.BottomScale)
		local gap = portraitConfig.GapPx
		local contentHeight = math.max(bottom - top - gap * 2, 3)
		local totalWeight = portraitConfig.SeasonWeight + portraitConfig.DailyWeight + portraitConfig.QuestsWeight
		local seasonHeight = math.max(math.floor(contentHeight * portraitConfig.SeasonWeight / totalWeight), 1)
		local dailyHeight = math.max(math.floor(contentHeight * portraitConfig.DailyWeight / totalWeight), 1)
		local questsHeight = math.max(contentHeight - seasonHeight - dailyHeight, 1)
		return {
			portrait = true,
			season = {
				position = Vector2.new(left, top),
				size = Vector2.new(width, seasonHeight),
			},
			daily = {
				position = Vector2.new(left, top + seasonHeight + gap),
				size = Vector2.new(width, dailyHeight),
			},
			quests = {
				position = Vector2.new(left, top + seasonHeight + gap + dailyHeight + gap),
				size = Vector2.new(width, questsHeight),
			},
		}
	end

	local function landscapeSize(variant: PanelVariant): Vector2
		local spec = { Portrait = variant, Landscape = variant }
		return ResponsiveLayout.panelSize(available, spec, portraitMaxAspect, shortLandscapeMaxHeight)
	end
	local dailySize = landscapeSize(config.Daily)
	local seasonSize = landscapeSize(config.Season)
	local questsSize = landscapeSize(config.Quests)
	local edge = math.min(config.EdgePaddingPx, math.floor(available.X * 0.03))
	local seasonTop = math.floor(available.Y * config.Landscape.SeasonTopScale)
	local questsTop =
		math.max(math.floor(available.Y * config.Landscape.QuestsTopScale), seasonTop + seasonSize.Y + config.GapPx)
	return {
		portrait = false,
		daily = {
			position = Vector2.new(edge, math.floor(available.Y * config.Landscape.DailyBottomScale) - dailySize.Y),
			size = dailySize,
		},
		season = {
			position = Vector2.new(available.X - edge - seasonSize.X, seasonTop),
			size = seasonSize,
		},
		quests = {
			position = Vector2.new(available.X - edge - questsSize.X, questsTop),
			size = questsSize,
		},
	}
end

function ResponsiveLayout.gridCellSize(
	availableWidth: number,
	minimum: number,
	maximum: number,
	gap: number,
	maxColumns: number
): (number, number)
	local columns = math.clamp(math.floor((availableWidth + gap) / (minimum + gap)), 1, maxColumns)
	local cellSize = math.floor((availableWidth - gap * (columns - 1)) / columns)
	return columns, math.clamp(cellSize, math.min(minimum, availableWidth), maximum)
end

function ResponsiveLayout.menuToggle(
	size: Vector2,
	horizontalPadding: number,
	gap: number,
	keycapWidthScale: number
): MenuToggleLayout
	local keycapSize = Vector2.new(size.X * keycapWidthScale, size.Y * 0.54)
	local keycapPosition = Vector2.new(size.X - horizontalPadding - keycapSize.X, size.Y * 0.24)
	local labelPosition = Vector2.new(horizontalPadding, size.Y * 0.25)
	local labelSize = Vector2.new(math.max(keycapPosition.X - gap - labelPosition.X, 0), size.Y * 0.58)
	return {
		labelPosition = labelPosition,
		labelSize = labelSize,
		keycapPosition = keycapPosition,
		keycapSize = keycapSize,
	}
end

return ResponsiveLayout
