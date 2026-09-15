--!strict
local Composition = {}
-- Choose proportions from the measured card width, after the parent section
-- has resolved its columns. Narrow cards retain the vertical artwork band.
function Composition.adaptiveClass(class, cardWidth, minimum, height, splitMinimum, stackHeight)
	if class.Layout == "Split" and cardWidth < splitMinimum then
		local stacked = table.clone(class)
		stacked.Layout = "Stack"
		stacked.MinHeightPx = stackHeight
		stacked.MaxHeightPx = stackHeight
		return stacked
	end
	if not class.Adaptive or class.Layout ~= "Stack" or cardWidth < minimum then
		return class
	end
	local adapted = table.clone(class)
	adapted.Layout = "Split"
	adapted.MinHeightPx = height
	adapted.MaxHeightPx = height
	return adapted
end
function Composition.shortClass(class, minimum, height)
	local compact = table.clone(class)
	compact.Layout = "Split"
	compact.MinPx = minimum
	compact.MaxPx = math.max(minimum, class.MaxPx)
	compact.MinHeightPx = height
	compact.MaxHeightPx = height
	return compact
end
function Composition.groups(model, config)
	local featured, catalog, byId = {}, {}, {}
	for _, section in model.sections do
		local cards = {}
		for _, card in section.cards do
			if card.kind == "SeasonPass" then
				table.insert(featured, {
					id = card.id,
					title = "THIS SEASON",
					cards = { card },
					style = {
						Class = "Season",
						MaxColumns = 1,
						Span = 4,
					},
				})
			else
				table.insert(cards, card)
			end
		end
		if #cards > 0 then
			local style = config.Sections[section.id] or config.DefaultSection
			local entry = {
				id = section.id,
				title = style.Title or section.title,
				cards = cards,
				countdownAt = section.countdownAt,
				style = style,
			}
			byId[section.id] = entry
		end
	end
	local hasSeason = #featured > 0
	for _, card in model.hero do
		table.insert(featured, {
			id = card.id,
			title = card.badge or "FEATURED",
			cards = { card },
			countdownAt = card.countdownAt
				or (if card.kind == "Bundle" then model.bundleExpireAt else model.featuredExpireAt),
			style = {
				Class = "Promo",
				MaxColumns = 1,
				Span = if #model.hero == 1 then (if hasSeason then 8 else 12) else 4,
			},
		})
	end
	if #featured == 1 then
		featured[1].style.Span = 12
	end
	for _, id in config.Order do
		if byId[id] then
			table.insert(catalog, byId[id])
			byId[id] = nil
		end
	end
	for _, section in model.sections do
		if byId[section.id] then
			table.insert(catalog, byId[section.id])
			byId[section.id] = nil
		end
	end
	return featured, catalog
end
function Composition.span(width, wanted, minimum, gap, wideMin, mediumMin)
	local unit = (width + gap) / 12
	if width < mediumMin then
		return 12
	end
	if width < wideMin then
		return if unit * 6 - gap >= minimum then 6 else 12
	end
	for _, span in { 4, 6, 8, 12 } do
		if span >= wanted and unit * span - gap >= minimum then
			return span
		end
	end
	return 12
end
return table.freeze(Composition)
