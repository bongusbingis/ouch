--!strict

type Padding = {
	x: number,
	y: number,
}

export type FitOptions = {
	font: any?,
	minSize: number?,
	maxSize: number?,
	padding: Padding?,
	paramsFactory: (() -> any)?,
	textService: any?,
}

local TextSizer = {}

local function resolveConfig()
	local replicatedStorage = game:GetService("ReplicatedStorage")
	return require(replicatedStorage:WaitForChild("Config"):WaitForChild("UI")).Text
end

local function axis(value: any, upper: string, lower: string): number
	local axisValue = value[upper] or value[lower]
	if typeof(axisValue) == "number" then
		return axisValue
	end
	return 0
end

local function vector2(x: number, y: number): any
	if Vector2 ~= nil then
		return Vector2.new(x, y)
	end
	return { x = x, y = y }
end

local function getTextService(options: FitOptions?): any
	if options and options.textService then
		return options.textService
	end
	return game:GetService("TextService")
end

local function getFont(options: FitOptions?, config): any
	if options and options.font then
		return options.font
	end
	if config and config.DefaultFont then
		return config.DefaultFont
	end
	return Font.fromName("Comic Neue Angular", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
end

local function boundsWithPadding(bounds: any, padding: Padding?): any
	local x = axis(bounds, "X", "x")
	local y = axis(bounds, "Y", "y")
	if padding then
		x -= padding.x * 2
		y -= padding.y * 2
	end
	return vector2(math.max(1, x), math.max(1, y))
end

local function makeParams(options: FitOptions?): any
	if options and options.paramsFactory then
		return options.paramsFactory()
	end
	return Instance.new("GetTextBoundsParams")
end

local function measure(textService: any, text: string, size: number, font: any, bounds: any, options: FitOptions?): any
	if type(textService.GetTextBoundsAsync) == "function" then
		local params = makeParams(options)
		params.Text = text
		params.Font = font
		params.Size = size
		params.Width = axis(bounds, "X", "x")
		return textService:GetTextBoundsAsync(params)
	end
	return textService:GetTextSize(text, size, font, bounds)
end

local function fits(textService: any, text: string, size: number, font: any, bounds: any, options: FitOptions?): boolean
	local measured = measure(textService, text, size, font, bounds, options)
	return axis(measured, "X", "x") <= axis(bounds, "X", "x") and axis(measured, "Y", "y") <= axis(bounds, "Y", "y")
end

function TextSizer.textSizeForBounds(text: string, bounds: any, options: FitOptions?): number
	local config = if options
			and options.textService
			and options.minSize
			and options.maxSize
			and options.font
		then nil
		else resolveConfig()
	local minSize = if options and options.minSize
		then options.minSize
		else if config then config.DefaultMinSize else 12
	local maxSize = if options and options.maxSize
		then options.maxSize
		else if config then config.DefaultMaxSize else 28
	local padding = if options and options.padding
		then options.padding
		else if config then config.DefaultPadding else nil
	local font = getFont(options, config)
	local textService = getTextService(options)
	local availableBounds = boundsWithPadding(bounds, padding)

	local low = math.max(1, math.floor(minSize))
	local high = math.max(low, math.floor(maxSize))
	local best = low

	while low <= high do
		local midpoint = math.floor((low + high) / 2)
		if fits(textService, text, midpoint, font, availableBounds, options) then
			best = midpoint
			low = midpoint + 1
		else
			high = midpoint - 1
		end
	end

	return best
end

function TextSizer.apply(label: TextLabel, bounds: any, options: FitOptions?)
	local config = if options and options.textService and options.font then nil else resolveConfig()
	local font = getFont(options, config)
	label.TextScaled = false
	label.FontFace = font
	label.TextSize = TextSizer.textSizeForBounds(label.Text, bounds, options)
end

function TextSizer.bind(label: TextLabel, boundsGui: GuiObject, options: FitOptions?): () -> ()
	local connections: { RBXScriptConnection } = {}

	local function update()
		TextSizer.apply(label, boundsGui.AbsoluteSize, options)
	end

	update()
	table.insert(connections, boundsGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
	table.insert(connections, label:GetPropertyChangedSignal("Text"):Connect(update))
	table.insert(connections, label:GetPropertyChangedSignal("Font"):Connect(update))

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
end

return TextSizer
