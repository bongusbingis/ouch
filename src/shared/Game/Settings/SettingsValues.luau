-- Description: Pure value resolution shared by every setting control: clamping and step/allowed-value snapping for sliders, option validation for toggles, and the one alpha-to-value mapping every input path (click, drag, controller) goes through so none of them can disagree.

--!strict

local SettingsValues = {}

export type ToggleDefinition = {
	Id: string,
	Type: "Toggle",
	Values: { any },
	Default: any,
}

export type SliderDefinition = {
	Id: string,
	Type: "Slider",
	Min: number?,
	Max: number?,
	Step: number?,
	AllowedValues: { number }?,
	Default: number,
}

export type Definition = ToggleDefinition | SliderDefinition

local function decimalsOf(step: number): number
	local text = string.format("%.10f", step)
	local fraction = string.match(text, "%.(%d-)0*$") or ""
	return #fraction
end

local function roundTo(value: number, decimals: number): number
	local scale = 10 ^ decimals
	return math.round(value * scale) / scale
end

local function nearestAllowed(value: number, allowed: { number }): number
	local best = allowed[1]
	local bestDistance = math.abs(value - best)
	for index = 2, #allowed do
		local candidate = allowed[index]
		local distance = math.abs(value - candidate)
		if distance < bestDistance then
			best = candidate
			bestDistance = distance
		end
	end
	return best
end

function SettingsValues.stops(definition: SliderDefinition): { number }
	if definition.AllowedValues and #definition.AllowedValues > 0 then
		local sorted = table.clone(definition.AllowedValues)
		table.sort(sorted)
		return sorted
	end
	return {}
end

function SettingsValues.bounds(definition: SliderDefinition): (number, number)
	local stops = SettingsValues.stops(definition)
	if #stops > 0 then
		return stops[1], stops[#stops]
	end
	return definition.Min or 0, definition.Max or 1
end

function SettingsValues.snapSlider(definition: SliderDefinition, rawValue: number): number
	if rawValue ~= rawValue or math.abs(rawValue) == math.huge then
		return definition.Default
	end

	local stops = SettingsValues.stops(definition)
	if #stops > 0 then
		return nearestAllowed(rawValue, stops)
	end

	local min, max = SettingsValues.bounds(definition)
	local clamped = math.clamp(rawValue, min, max)
	local step = definition.Step
	if step == nil or step <= 0 then
		return clamped
	end

	local steps = math.round((clamped - min) / step)
	local snapped = min + steps * step
	snapped = math.clamp(snapped, min, max)
	return roundTo(snapped, decimalsOf(step))
end

function SettingsValues.alphaToValue(definition: SliderDefinition, alpha: number): number
	local clampedAlpha = math.clamp(alpha, 0, 1)
	local stops = SettingsValues.stops(definition)
	if #stops > 0 then
		local index = math.clamp(math.round(clampedAlpha * (#stops - 1)) + 1, 1, #stops)
		return stops[index]
	end

	local min, max = SettingsValues.bounds(definition)
	return SettingsValues.snapSlider(definition, min + clampedAlpha * (max - min))
end

function SettingsValues.valueToAlpha(definition: SliderDefinition, value: number): number
	local stops = SettingsValues.stops(definition)
	if #stops > 0 then
		if #stops == 1 then
			return 0
		end
		local nearest = nearestAllowed(value, stops)
		local index = table.find(stops, nearest) or 1
		return (index - 1) / (#stops - 1)
	end

	local min, max = SettingsValues.bounds(definition)
	if max <= min then
		return 0
	end
	return math.clamp((value - min) / (max - min), 0, 1)
end

function SettingsValues.stepIncrement(definition: SliderDefinition): number
	if definition.Step and definition.Step > 0 then
		return definition.Step
	end
	local min, max = SettingsValues.bounds(definition)
	return (max - min) / 20
end

function SettingsValues.stepValue(definition: SliderDefinition, value: number, direction: number): number
	local stops = SettingsValues.stops(definition)
	if #stops > 0 then
		local nearest = nearestAllowed(value, stops)
		local index = table.find(stops, nearest) or 1
		local nextIndex = math.clamp(index + (if direction < 0 then -1 else 1), 1, #stops)
		return stops[nextIndex]
	end
	local increment = SettingsValues.stepIncrement(definition)
	return SettingsValues.snapSlider(definition, value + (if direction < 0 then -increment else increment))
end

function SettingsValues.isValidToggleValue(definition: ToggleDefinition, value: any): boolean
	return value == definition.Values[1] or value == definition.Values[2]
end

function SettingsValues.normalize(definition: Definition, rawValue: any): any
	if definition.Type == "Toggle" then
		if SettingsValues.isValidToggleValue(definition, rawValue) then
			return rawValue
		end
		return definition.Default
	end

	if typeof(rawValue) ~= "number" then
		return definition.Default
	end
	return SettingsValues.snapSlider(definition, rawValue)
end

return SettingsValues
