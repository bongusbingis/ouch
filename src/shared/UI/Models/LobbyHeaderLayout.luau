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

-- TopbarInset describes the free CoreGui row relative to the device-safe origin.
-- Return full-screen rectangles so callers can convert once into their root space.
function LobbyHeaderLayout.resolveMobile(available: Vector2, insets: any, includeEmote: boolean?)
	if not includeEmote and not LobbyHeaderLayout.resolve(available).compact then
		return nil
	end
	local n = T.LobbyNavigation
	local target = T.Layout.MinTarget
	local deviceOffset, deviceSize = insets.deviceOffset, insets.deviceSize
	if deviceSize.X < target * 4 + n.MobileEdge * 2 or deviceSize.Y < target then
		return nil
	end
	local topbar = insets.topbar
	local left = deviceOffset.X + math.max(0, topbar.Min.X) + n.MobileEdge
	local right = deviceOffset.X + math.min(topbar.Max.X, deviceSize.X) - n.MobileEdge
	local freeWidth = math.max(0, right - left)
	local topbarHeight = topbar.Max.Y - topbar.Min.Y
	local width, height = n.MobileWidth, n.MobileHeight
	local iconOnly = false
	local docked = topbarHeight > 0 and freeWidth >= width
	if not docked and topbarHeight > 0 and freeWidth >= target * 4 then
		width, height = target * 4, target
		iconOnly, docked = true, true
	end
	local emote = nil
	local navLeft, navTop
	if docked then
		-- Accessories use spare room; they never displace readable navigation.
		local hasEmote = includeEmote and freeWidth >= width + n.MobileAccessoryGap + target
		local clusterWidth = width + (if hasEmote then n.MobileAccessoryGap + target else 0)
		navLeft = left + (freeWidth - clusterWidth) / 2
		local centerY = deviceOffset.Y + topbar.Min.Y + topbarHeight / 2
		navTop = centerY - height / 2
		if hasEmote then
			emote = {
				position = Vector2.new(navLeft + width + n.MobileAccessoryGap, centerY - target / 2),
				size = Vector2.new(target, target),
			}
		end
	else
		-- If even four minimum-size icons cannot fit beside CoreGui, retain one
		-- labeled row below it, never the old extra logo/accessory row.
		width = math.min(width, deviceSize.X - n.MobileEdge * 2)
		navLeft = deviceOffset.X + (deviceSize.X - width) / 2
		navTop = insets.coreOffset.Y + n.MobileFallbackGap
	end
	local clearance = if deviceSize.X > deviceSize.Y and deviceSize.Y <= T.LobbyLandscape.MaxHeight
		then n.LandscapeSelectionClearance
		else n.MobileSelectionClearance
	local bandHeight = math.max(insets.coreOffset.Y, navTop + height + clearance + n.MobileBandPadding)
	return {
		nav = { position = Vector2.new(navLeft, navTop), size = Vector2.new(width, height) },
		emote = emote,
		bandHeight = bandHeight,
		height = math.max(0, bandHeight - insets.coreOffset.Y),
		docked = docked,
		iconOnly = iconOnly,
	}
end

return table.freeze(LobbyHeaderLayout)
