--!strict
-- Reserve the full scaled card outline inside the upright scrolling viewport.
local T = require(script.Parent.Parent.Tokens)

local Layout = {}

-- Shortest odds tile that still leaves a >=56 px art window above the seam tag,
-- the 2-line name and the footer (so ~2 rows fit the odds window), rather than
-- the 270 px shop card.
Layout.TileHeight = 186

function Layout.resolve(viewportWidth: number)
	local height = Layout.TileHeight
	local growth = (T.Motion.HoverScale - 1) / 2
	local stroke = T.Shape.StrokeTab * T.Motion.HoverScale
	local minimumInset = math.ceil(height * growth + stroke)
	local columns =
		math.max(1, math.floor((viewportWidth - minimumInset * 2 + T.Shop.CardGap) / (T.Shop.CardMin + T.Shop.CardGap)))
	local available = (viewportWidth - (columns - 1) * T.Shop.CardGap) / columns
	local inset = math.ceil(math.max(available, height) * growth + stroke)
	return {
		columns = columns,
		tileWidth = math.floor((viewportWidth - inset * 2 - (columns - 1) * T.Shop.CardGap) / columns),
		tileHeight = height,
		inset = inset,
		gap = T.Shop.CardGap,
	}
end

-- Reveal the animated bounds, rather than only the stable input hitbox, on focus.
function Layout.reveal(
	top: number,
	height: number,
	inset: number,
	position: number,
	window: number,
	canvas: number
): number
	local first, last = top - inset, top + height + inset
	if first < position then
		position = first
	elseif last > position + window then
		position = math.min(first, last - window)
	end
	return math.clamp(position, 0, math.max(0, canvas - window))
end

return Layout
