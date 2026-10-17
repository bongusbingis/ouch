--!strict
-- Geometry of the shared collectible card face: a recessed art window, the
-- rarity tag pinned on the window's lower seam, then the name and an optional
-- footer line on the card body. Art is always laid out clear of every tag, so
-- a 3D preview can never draw over the rarity.
local T = require(script.Parent.Parent.Tokens)
local K = T.Collectible

export type Rect = { x: number, y: number, w: number, h: number }
export type Options = {
	tag: boolean?,
	name: boolean?,
	footer: boolean?,
	corner: boolean?,
	nameHeight: number?,
}
export type Card = {
	well: Rect,
	-- Relative to the well.
	art: Rect,
	-- Card coordinates; the tag is centred on `centerX` and sized to its label.
	tag: { centerX: number, y: number, h: number, maxWidth: number }?,
	-- Relative to the well (top-left chip such as OWNED).
	corner: { x: number, y: number, h: number, maxWidth: number }?,
	name: Rect?,
	footer: Rect?,
}

local Layout = {}

-- `width` and `height` are the card face, excluding the puffy lip.
function Layout.card(width: number, height: number, options: Options): Card
	local pad = K.Pad
	local tagHeight = if options.tag then K.TagHeight else 0
	local half = math.ceil(tagHeight / 2)
	local nameHeight = if options.name then options.nameHeight or K.NameHeight else 0
	local footerHeight = if options.footer then K.FooterHeight else 0
	local below = if nameHeight + footerHeight > 0 then half + K.NameGap + nameHeight + footerHeight else half + pad
	local well = { x = pad, y = pad, w = math.max(width - pad * 2, 1), h = math.max(height - pad - below, 1) }
	local artTop = if options.corner then K.TagInset + K.TagHeight + K.ArtInset else K.ArtInset
	local artBottom = well.h - (if tagHeight > 0 then half + K.ArtInset else K.ArtInset)
	local card: Card = {
		well = well,
		art = {
			x = K.ArtInset,
			y = artTop,
			w = math.max(well.w - K.ArtInset * 2, 1),
			h = math.max(artBottom - artTop, 1),
		},
	}
	if tagHeight > 0 then
		card.tag = {
			centerX = well.x + well.w / 2,
			y = well.y + well.h - half,
			h = tagHeight,
			maxWidth = well.w - K.TagInset * 2,
		}
	end
	if options.corner then
		card.corner = { x = K.TagInset, y = K.TagInset, h = K.TagHeight, maxWidth = well.w - K.TagInset * 2 }
	end
	local cursor = well.y + well.h + (if tagHeight > 0 then half + K.NameGap else 0)
	if nameHeight > 0 then
		card.name = { x = pad, y = cursor, w = well.w, h = nameHeight }
		cursor += nameHeight
	end
	if footerHeight > 0 then
		card.footer = { x = pad, y = cursor, w = well.w, h = footerHeight }
	end
	return card
end

-- The CAPS card label for an inventory entry: "Default " and a redundant
-- " Ball"/" Hammer" suffix are dropped (the tab already says what it is).
function Layout.label(entry: { displayName: string, category: string }): string
	local name = string.gsub(entry.displayName, "^Default%s+", "")
	local suffix = if entry.category == "BallAssets"
		then " Ball"
		elseif entry.category == "HammerAssets" then " Hammer"
		else nil
	if suffix and string.sub(name, -#suffix) == suffix and #name > #suffix then
		name = string.sub(name, 1, #name - #suffix)
	end
	return string.upper(name)
end

-- Full card height (face plus puffy lip) for a Backpack card of `size` width
-- whose name block is `nameHeight` tall. A grid whose names all fit one line
-- gets the second line's height back instead of an empty band under the name.
function Layout.cardHeight(size: number, nameHeight: number?): number
	return size + K.ExtraHeight - (K.NameHeight - (nameHeight or K.NameHeight))
end

export type GridSpec = {
	width: number,
	-- Visible height of the scroll window, and how far down it the first row starts.
	visible: number,
	top: number,
	minimum: number,
	maximum: number,
	gap: number,
	maxColumns: number,
	nameHeight: number?,
	lip: number,
}
export type Grid = { columns: number, size: number, height: number }

-- One cell size for every tab of a grid, sized to the width and then snapped so
-- the first screen never ends inside a row's name band (which reads as text cut
-- in half). When the cut would land there, the cards shrink just enough (at most
-- 15%, never below `minimum`) for that row to fit whole; otherwise the cut stays
-- in the next row's art window, which reads as "more below".
function Layout.grid(spec: GridSpec): Grid
	local gap = spec.gap
	local width = math.max(spec.width, 1)
	local columns = math.clamp(math.floor((width + gap) / (spec.minimum + gap)), 1, spec.maxColumns)
	local size = math.floor((width - gap * (columns - 1)) / columns)
	size = math.clamp(size, math.min(spec.minimum, width), spec.maximum)
	local extra = Layout.cardHeight(size, spec.nameHeight) - size
	local height = size + extra
	local available = spec.visible - spec.top
	if available <= 0 then
		return { columns = columns, size = size, height = height }
	end
	local face = Layout.card(size, height - spec.lip, { tag = true, name = true, nameHeight = spec.nameHeight })
	local nameTop = if face.name then face.name.y else height
	local full = math.max(math.floor((available + gap) / (height + gap)), 0)
	local shown = available - full * (height + gap)
	if shown > nameTop - K.Pad and shown < height then
		local fitted = math.floor((available - full * gap) / (full + 1)) - extra
		if fitted >= spec.minimum and fitted >= math.floor(size * 0.85) then
			size = fitted
			height = size + extra
		end
	end
	return { columns = columns, size = size, height = height }
end

-- One name type size and block height for a set of CAPS names at a card's
-- name width: 22 px when every name fits in two lines, otherwise 18 px (longer
-- names truncate after two lines). Siblings share the result so names never mix
-- sizes, and the block is only as tall as the longest name needs. `maxHeight`
-- caps the block for a caller with a fixed card (the face's own name slot).
function Layout.nameStyle(texts: { string }, width: number, maxHeight: number?): (number, number)
	local TextService = game:GetService("TextService")
	local font = T.Type.Display
	local wrap = Vector2.new(math.max(width, 1), 1000)
	local function measure(size: number): (boolean, number)
		local line = TextService:GetTextSize("A", size, font, Vector2.new(4096, 1000)).Y
		local limit = math.min(line * 2, maxHeight or math.huge)
		local tallest = line
		local fits = true
		for _, text in texts do
			local bounds = TextService:GetTextSize(text, size, font, wrap)
			tallest = math.max(tallest, bounds.Y)
			if bounds.Y > limit + 1 then
				fits = false
			end
			for word in string.gmatch(text, "%S+") do
				if TextService:GetTextSize(word, size, font, Vector2.new(4096, 1000)).X > width then
					fits = false
				end
			end
		end
		return fits, math.min(math.ceil(tallest), math.ceil(limit))
	end
	local fits, height = measure(T.Type.TileLabel)
	if fits then
		return T.Type.TileLabel, height + K.NameGap * 2
	end
	local _, small = measure(T.Type.Minimum)
	return T.Type.Minimum, small + K.NameGap * 2
end

-- Content width for a tag label: measured text plus the tag's side padding,
-- clamped to the space the card offers.
function Layout.tagWidth(text: string, textSize: number, maxWidth: number?): number
	local TextService = game:GetService("TextService")
	local bounds = TextService:GetTextSize(text, textSize, T.Type.Label, Vector2.new(4096, 200))
	local width = math.ceil(bounds.X) + K.TagPadding * 2 + T.Shape.StrokeInner * 2
	return if maxWidth then math.min(width, maxWidth) else width
end

return table.freeze(Layout)
