--!strict

-- PROTOTYPE: Structural layout only. Coordinates are relative to the nearest
-- functional GuiObject ancestor: BaseClip/Views, Holder, or row.

local EconomyPrototypeLayout = {}

local function vector2(x: number, y: number): Vector2
	if Vector2 == nil then
		return ({ X = x, Y = y } :: any) :: Vector2
	end
	return Vector2.new(x, y)
end

local function dimensions(xScale: number, xOffset: number, yScale: number, yOffset: number): UDim2
	if UDim2 == nil then
		return (
			{
				X = { Scale = xScale, Offset = xOffset },
				Y = { Scale = yScale, Offset = yOffset },
			} :: any
		) :: UDim2
	end
	return UDim2.new(xScale, xOffset, yScale, yOffset)
end

local function setRect(
	gui: GuiObject,
	anchorX: number,
	anchorY: number,
	positionX: number,
	positionY: number,
	sizeXScale: number,
	sizeXOffset: number,
	sizeYScale: number,
	sizeYOffset: number,
	zIndex: number
)
	gui.AnchorPoint = vector2(anchorX, anchorY)
	gui.Position = dimensions(positionX, 0, positionY, 0)
	gui.Size = dimensions(sizeXScale, sizeXOffset, sizeYScale, sizeYOffset)
	gui.ZIndex = zIndex
end

local function child(parent: Instance, name: string, className: string): GuiObject
	local instance = parent:WaitForChild(name)
	assert(instance:IsA(className), `[EconomyPrototypeLayout] {parent.Name}.{name} must be a {className}`)
	return instance :: GuiObject
end

local function applyViewRoot(view: GuiObject)
	setRect(view, 0.5, 0.5, 0.5, 0.5, 0.86, 0, 0.82, 0, 10)
	view.ClipsDescendants = true
end

function EconomyPrototypeLayout.applyEconomyItem(row: GuiObject)
	-- UIListLayout owns the final position under the scrolling Holder. A fixed
	-- row height avoids circular scale sizing with AutomaticCanvasSize.
	setRect(row, 0, 0, 0, 0, 1, 0, 0, 88, 11)
	setRect(child(row, "ItemName", "TextLabel"), 0, 0, 0, 0, 0.7, 0, 0.25, 0, 12)
	setRect(child(row, "Details", "TextLabel"), 0, 0, 0, 0.25, 0.7, 0, 0.25, 0, 12)
	setRect(child(row, "State", "TextLabel"), 0, 0, 0, 0.5, 0.7, 0, 0.25, 0, 12)
	setRect(child(row, "Action", "TextButton"), 0, 0, 0.72, 0.2, 0.28, 0, 0.6, 0, 12)
end

function EconomyPrototypeLayout.applyShop(view: GuiObject)
	applyViewRoot(view)
	setRect(child(view, "Title", "TextLabel"), 0, 0, 0, 0, 1, 0, 0.1, 0, 11)
	setRect(child(view, "Cash", "TextLabel"), 0, 0, 0, 0.1, 1, 0, 0.1, 0, 11)
	setRect(child(view, "Status", "TextLabel"), 0, 0, 0, 0.2, 1, 0, 0.1, 0, 11)
	setRect(child(view, "Holder", "ScrollingFrame"), 0, 0, 0, 0.3, 1, 0, 0.7, 0, 11)
end

function EconomyPrototypeLayout.applyInventory(view: GuiObject)
	applyViewRoot(view)
	setRect(child(view, "Title", "TextLabel"), 0, 0, 0, 0, 1, 0, 0.1, 0, 11)
	setRect(child(view, "Status", "TextLabel"), 0, 0, 0, 0.1, 1, 0, 0.1, 0, 11)
	setRect(child(view, "Holder", "ScrollingFrame"), 0, 0, 0, 0.2, 1, 0, 0.8, 0, 11)
end

return EconomyPrototypeLayout
