--!strict

local LobbyHeaderLayout = require(script.Parent.LobbyHeaderLayout)

local ResponsiveLayout = {}

export type PanelVariant = {
	WidthScale: number,
	HeightScale: number,
	MaxSize: Vector2,
	AspectRatio: number?,
	ShortHeightScale: number?,
	ShortWidthScale: number?,
	ShortAspectRatio: number?,
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
	DailyMinHeightPx: number?,
	EdgePaddingPx: number,
	GapPx: number,
	Landscape: {
		SeasonHeightPx: number,
		DailyHeightPx: number,
		QuestsMinHeightPx: number,
		ActionsReservePx: number?,
		DailyBottomScale: number,
		SeasonTopScale: number,
		ShortTopPx: number?,
		ShortBottomPx: number?,
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
	progressStack: SplashPanelRect?,
	tabbed: boolean?,
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
	-- The viewport is the harder constraint: it reads (1, 1) until the client has
	-- rendered a frame, and an inset larger than it would otherwise invert the
	-- clamp bounds and throw inside a render.
	local limit = Vector2.new(math.max(viewport.X, 0), math.max(viewport.Y, 0))
	local low = Vector2.new(math.clamp(insetMin.X, 0, limit.X), math.clamp(insetMin.Y, 0, limit.Y))
	local maximum = Vector2.new(math.clamp(insetMax.X, low.X, limit.X), math.clamp(insetMax.Y, low.Y, limit.Y))
	local minimum = Vector2.new(math.min(low.X, maximum.X), math.min(low.Y, maximum.Y))
	return {
		position = if parentIsFullScreen then minimum else Vector2.new(0, 0),
		size = Vector2.new(maximum.X - minimum.X, maximum.Y - minimum.Y),
	}
end

function ResponsiveLayout.insetRect(
	viewport: Vector2,
	deviceMin: Vector2,
	deviceMax: Vector2,
	parentMin: Vector2,
	parentMax: Vector2
): SafeRect
	local parentSize =
		Vector2.new(math.min(viewport.X, parentMax.X - parentMin.X), math.min(viewport.Y, parentMax.Y - parentMin.Y))
	local minimum =
		Vector2.new(math.max(deviceMin.X, parentMin.X) - parentMin.X, math.max(deviceMin.Y, parentMin.Y) - parentMin.Y)
	local maximum =
		Vector2.new(math.min(deviceMax.X, parentMax.X) - parentMin.X, math.min(deviceMax.Y, parentMax.Y) - parentMin.Y)
	return ResponsiveLayout.safeRect(parentSize, minimum, maximum, true)
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
	local widthScale = if short and variant.ShortWidthScale then variant.ShortWidthScale else variant.WidthScale
	local width = math.min(available.X * widthScale, variant.MaxSize.X)
	local height = math.min(available.Y * heightScale, variant.MaxSize.Y)
	local aspect = if short and variant.ShortAspectRatio then variant.ShortAspectRatio else variant.AspectRatio
	if aspect then
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
		local dailyHeight = math.min(
			math.max(math.floor(contentHeight * portraitConfig.DailyWeight / totalWeight), config.DailyMinHeightPx or 1),
			contentHeight - seasonHeight - 1
		)
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
	dailySize = Vector2.new(dailySize.X, math.max(config.Landscape.DailyHeightPx, config.DailyMinHeightPx or 1))
	local seasonSize = landscapeSize(config.Season)
	seasonSize = Vector2.new(seasonSize.X, config.Landscape.SeasonHeightPx)
	local questsSize = landscapeSize(config.Quests)
	local edge = math.min(config.EdgePaddingPx, math.floor(available.X * 0.03))
	local short = shortLandscapeMaxHeight ~= nil and available.Y <= shortLandscapeMaxHeight
	local column = config.Landscape
	local headerHeight = LobbyHeaderLayout.resolve(available).height
	local columnTop = math.max(math.floor(available.Y * column.SeasonTopScale), headerHeight + 8)
	local columnMinimum = column.SeasonHeightPx + column.DailyHeightPx + column.QuestsMinHeightPx + config.GapPx * 2
	local stack = short or available.Y - columnTop - (column.ActionsReservePx or 0) < columnMinimum
	if not stack then
		local width = math.min(math.floor(available.X * config.Season.WidthScale), config.Season.MaxSize.X)
		local left = available.X - edge - width
		local dailyTop = columnTop + column.SeasonHeightPx + config.GapPx
		local questsTop = dailyTop + column.DailyHeightPx + config.GapPx
		return {
			portrait = false,
			season = {
				position = Vector2.new(left, columnTop),
				size = Vector2.new(width, column.SeasonHeightPx),
			},
			daily = {
				position = Vector2.new(left, dailyTop),
				size = Vector2.new(width, column.DailyHeightPx),
			},
			quests = {
				position = Vector2.new(left, questsTop),
				size = Vector2.new(width, available.Y - (column.ActionsReservePx or 0) - questsTop),
			},
		}
	end
	local seasonTop = math.max(columnTop, config.Landscape.ShortTopPx or 0)
	local questsTop =
		math.max(math.floor(available.Y * config.Landscape.QuestsTopScale), seasonTop + seasonSize.Y + config.GapPx)
	local tabbed = short
		or available.Y - seasonTop - (config.Landscape.ShortBottomPx or 0) < columnMinimum + config.GapPx
	local bottom = available.Y - (if tabbed then 12 else (config.Landscape.ShortBottomPx or 0))
	local columnWidth = math.max(seasonSize.X, questsSize.X, math.min(math.floor(available.X * 0.38), 300))
	local questsBottom = bottom
	questsSize = Vector2.new(questsSize.X, math.min(questsSize.Y, math.max(44, questsBottom - questsTop)))
	return {
		portrait = false,
		tabbed = tabbed,
		progressStack = {
			position = Vector2.new(available.X - edge - columnWidth - config.GapPx, seasonTop),
			size = Vector2.new(columnWidth + config.GapPx * 2, math.max(1, bottom - seasonTop)),
		},
		daily = {
			position = Vector2.new(
				edge,
				math.min(bottom, math.floor(available.Y * config.Landscape.DailyBottomScale)) - dailySize.Y
			),
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

function ResponsiveLayout.inventoryComposition(available: Vector2, layout: any)
	local portrait = ResponsiveLayout.isPortrait(available, layout.PortraitMaxAspect)
	local short = not portrait and available.Y <= layout.ShortLandscapeMaxHeightPx
	local edge = 12
	local size = ResponsiveLayout.panelSize(
		available,
		layout.Panels.Inventory,
		layout.PortraitMaxAspect,
		layout.ShortLandscapeMaxHeightPx
	)
	local center = if portrait then layout.PagePosition else layout.InventoryPagePosition
	local position = Vector2.new(
		available.X * center.X.Scale + center.X.Offset - size.X / 2,
		available.Y * center.Y.Scale + center.Y.Offset - size.Y / 2
	)
	if short then
		position = Vector2.new(edge, layout.TopBar.ShortHeightPx + 8)
		local inventory = layout.Inventory
		local preferredWidth =
			math.max(inventory.ShortPanelMinWidthPx, math.floor(available.X * inventory.ShortPanelWidthScale) - edge)
		local maximumWidth = math.max(1, available.X - edge * 3 - inventory.ShortWorldMinWidthPx)
		size = Vector2.new(math.min(preferredWidth, maximumWidth), math.max(1, available.Y - position.Y - edge))
	end
	local worldX = position.X + size.X + edge
	return {
		panel = { position = position, size = size },
		world = {
			position = Vector2.new(worldX, position.Y),
			size = Vector2.new(math.max(1, available.X - worldX - edge), size.Y),
		},
	}
end

function ResponsiveLayout.splashWorldWindow(available: Vector2, layout: any): SafeRect
	local panels = ResponsiveLayout.splashPanels(
		available,
		layout.Splash.ProgressPanels,
		layout.PortraitMaxAspect,
		layout.ShortLandscapeMaxHeightPx
	)
	local edge = layout.Splash.ProgressPanels.GapPx
	if panels.progressStack then
		local top = LobbyHeaderLayout.resolve(available).height + 8
		return {
			position = Vector2.new(edge, top),
			size = Vector2.new(
				math.max(1, panels.progressStack.position.X - edge * 2),
				math.max(1, available.Y - top - 70)
			),
		}
	end
	local left = edge
	local top = if panels.portrait
		then math.floor(available.Y * 0.38)
		else panels.season.position.Y + layout.Splash.DesktopLogoSizePx.Y + edge
	local right = math.min(panels.season.position.X, panels.quests.position.X) - edge
	local bottom = if panels.portrait then panels.daily.position.Y - edge else available.Y - edge
	return {
		position = Vector2.new(left, top),
		size = Vector2.new(math.max(1, right - left), math.max(1, bottom - top)),
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
