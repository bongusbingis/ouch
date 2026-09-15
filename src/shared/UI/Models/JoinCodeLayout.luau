-- Keeps the join form above a visible keyboard without shrinking its readable content.
--!strict

local JoinCodeLayout = { EntryTop = 0.333456, ActionBottom = 0.944206 }

function JoinCodeLayout.resolve(
	safeArea: { position: Vector2, size: Vector2 },
	preferredSize: Vector2,
	rootPosition: Vector2,
	keyboard: { visible: boolean, position: Vector2, size: Vector2 }
)
	local result = {
		position = nil :: Vector2?,
		size = preferredSize,
		contentHeight = preferredSize.Y,
		scrollY = 0,
		scrolling = false,
	}
	if not keyboard.visible or keyboard.size.X <= 0 or keyboard.size.Y <= 0 then
		return result
	end

	local safeLeft = rootPosition.X + safeArea.position.X
	local safeTop = rootPosition.Y + safeArea.position.Y
	local keyboardTop = keyboard.position.Y - rootPosition.Y
	local preferredBottom = safeArea.position.Y + safeArea.size.Y * 0.534555 + preferredSize.Y / 2
	if
		keyboard.position.X >= safeLeft + safeArea.size.X
		or keyboard.position.X + keyboard.size.X <= safeLeft
		or keyboard.position.Y + keyboard.size.Y <= safeTop
		or keyboardTop >= preferredBottom + 8
	then
		return result
	end

	local availableHeight = math.clamp(keyboard.position.Y - safeTop - 8, 1, math.max(1, safeArea.size.Y))
	local width = math.min(math.max(preferredSize.X, safeArea.size.X * 0.9), math.max(1, safeArea.size.X - 16))
	local contentHeight = math.max(preferredSize.Y, 280)
	local height = math.min(contentHeight, math.max(1, availableHeight - 4))
	result.size = Vector2.new(math.floor(width), math.floor(height))
	result.position = Vector2.new(safeArea.position.X + safeArea.size.X / 2, safeArea.position.Y + availableHeight / 2)
	result.contentHeight = contentHeight
	result.scrolling = contentHeight > height
	-- Fit entry through actions together when possible, sharing any spare margin.
	-- Shorter windows start at the entry and retain scrolling to the actions.
	local entryTop = contentHeight * JoinCodeLayout.EntryTop
	local entryThroughActions = contentHeight * JoinCodeLayout.ActionBottom - entryTop
	local topPadding = if result.size.Y >= entryThroughActions
		then math.min(8, (result.size.Y - entryThroughActions) / 2)
		else 8
	result.scrollY = math.clamp(entryTop - topPadding, 0, contentHeight - result.size.Y)
	return result
end

return JoinCodeLayout
