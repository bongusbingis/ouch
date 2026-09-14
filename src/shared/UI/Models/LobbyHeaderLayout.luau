-- Fits the lobby's existing navigation, logo and party action inside the usable rectangle.
--!strict

local T = require(script.Parent.Parent.Tokens)
local LobbyHeaderLayout = {}

function LobbyHeaderLayout.resolve(available: Vector2, tabCount: number?, includeEmote: boolean?)
	local count = math.max(tabCount or 4, 1)
	local width = math.max(available.X, 1)
	local compact = available.Y <= 500 or width < 860
	local edge = if compact then 6 else 20
	local gap = if compact then 6 else 16
	local buttonWidth = if width < 594 and available.Y > width
		then math.floor((width - edge * 2 - gap * (count - 1)) / count)
		elseif width < 594 then 66
		else if compact then 74 else T.Layout.NavWidth
	local navWidth = buttonWidth * count + gap * (count - 1)
	local partyWidth = if width < 660 then 88 else if compact then 128 else 154
	local emoteWidth = if includeEmote then 44 else 0
	local rightCluster = partyWidth + (if includeEmote then gap + emoteWidth else 0)
	local logoWidth = math.clamp(width - edge * 2 - navWidth - rightCluster - gap * 2, 168, 220)
	local height = if compact then 72 else 88
	local navHeight = if compact then 56 else T.Layout.NavHeight
	local required = edge * 2 + logoWidth + navWidth + rightCluster + gap * 2
	local stacked = required > width
	local navTop = (height - navHeight) / 2
	local navLeft = math.clamp(
		(width - navWidth) / 2,
		edge + logoWidth + gap,
		math.max(edge + logoWidth + gap, width - edge - rightCluster - gap - navWidth)
	)
	if stacked then
		height = 124
		navTop = height - navHeight - 6
		navLeft = math.max(edge, (width - navWidth) / 2)
	end
	local accessoryHeight = if stacked then 60 else height
	local logoHeight = math.min(accessoryHeight - 8, navHeight + 8)
	local logoSize = Vector2.new(logoWidth, logoHeight)
	return {
		height = height,
		compact = compact,
		stacked = stacked,
		buttonWidth = buttonWidth,
		gap = gap,
		logo = {
			position = Vector2.new(edge + (logoWidth - logoSize.X) / 2, (accessoryHeight - logoSize.Y) / 2),
			size = logoSize,
		},
		nav = { position = Vector2.new(navLeft, navTop), size = Vector2.new(navWidth, navHeight) },
		party = {
			position = Vector2.new(width - edge - partyWidth, (accessoryHeight - 44) / 2),
			size = Vector2.new(partyWidth, 44),
		},
		partyLabel = if partyWidth < 120 then "PARTY" else "PARTY CODE",
		emote = if includeEmote
			then {
				position = Vector2.new(width - edge - partyWidth - gap - emoteWidth, (accessoryHeight - 44) / 2),
				size = Vector2.new(emoteWidth, 44),
			}
			else nil,
	}
end

return table.freeze(LobbyHeaderLayout)
