-- Name: SettingsRegistry.luau
-- Author: Jack C.
-- Description: The single declarative list of every setting in the game -- its stable id, control type, place scope, and default -- so a new setting is one entry here rather than hand-built UI, input handling, and persistence wiring.
-- Created: 2026-08-25

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local AudioConfig = require(Config:WaitForChild("Audio"))
local Debug = require(Config:WaitForChild("Debug"))

local SettingsRegistry = {}

export type Scope = "Lobby" | "Arena" | "Both"

export type ToggleDefinition = {
	Id: string,
	Type: "Toggle",
	Label: string,
	Description: string?,
	Category: string,
	Scope: Scope,
	Persist: boolean?,
	Values: { any },
	Labels: { string },
	Default: any,
}

export type SliderDefinition = {
	Id: string,
	Type: "Slider",
	Label: string,
	Description: string?,
	Category: string,
	Scope: Scope,
	Persist: boolean?,
	Min: number?,
	Max: number?,
	Step: number?,
	AllowedValues: { number }?,
	Default: number,
	Format: ((number) -> string)?,
}

export type Definition = ToggleDefinition | SliderDefinition

local function percentFormat(value: number): string
	return `{math.round(value * 100)}%`
end

local Definitions: { Definition } = {
	{
		Id = "CameraShake",
		Type = "Toggle",
		Label = "Camera Shake",
		Description = "Adds impact movement to the camera during combat.",
		Category = "GAMEPLAY",
		Scope = "Arena",
		Values = { true, false },
		Labels = { "ON", "OFF" },
		Default = true,
	},
	{
		Id = "MasterVolume",
		Type = "Slider",
		Label = "Master Volume",
		Category = "AUDIO",
		Scope = "Arena",
		Min = 0,
		Max = 1,
		Step = 0.05,
		Default = AudioConfig.Mix.MasterVolume,
		Format = percentFormat,
	},
	{
		Id = "MusicVolume",
		Type = "Slider",
		Label = "Music Volume",
		Category = "AUDIO",
		Scope = "Arena",
		Min = 0,
		Max = 1,
		Step = 0.05,
		Default = AudioConfig.Mix.MusicVolume,
		Format = percentFormat,
	},
	{
		Id = "EffectsVolume",
		Type = "Slider",
		Label = "Effects Volume",
		Category = "AUDIO",
		Scope = "Arena",
		Min = 0,
		Max = 1,
		Step = 0.05,
		Default = AudioConfig.Mix.EffectsVolume,
		Format = percentFormat,
	},
}

if Debug.SettingsShowExamples then
	local examples: { Definition } = {
		{
			Id = "DebugThrowInput",
			Type = "Toggle",
			Label = "Throw Input (example)",
			Description = "Demonstrates a This/That toggle whose options are not ON/OFF.",
			Category = "DEBUG EXAMPLES",
			Scope = "Both",
			Persist = false,
			Values = { "Hold", "Toggle" },
			Labels = { "HOLD", "TOGGLE" },
			Default = "Hold",
		},
		{
			Id = "DebugContinuousSlider",
			Type = "Slider",
			Label = "Continuous Slider (example)",
			Category = "DEBUG EXAMPLES",
			Scope = "Both",
			Persist = false,
			Min = 0,
			Max = 1,
			Default = 0.5,
		},
		{
			Id = "DebugIntegerSlider",
			Type = "Slider",
			Label = "Integer Slider (example)",
			Category = "DEBUG EXAMPLES",
			Scope = "Both",
			Persist = false,
			Min = 1,
			Max = 10,
			Step = 1,
			Default = 5,
		},
		{
			Id = "DebugSteppedDecimalSlider",
			Type = "Slider",
			Label = "Stepped Decimal Slider (example)",
			Category = "DEBUG EXAMPLES",
			Scope = "Both",
			Persist = false,
			Min = 0.5,
			Max = 2,
			Step = 0.1,
			Default = 1,
			Format = function(value: number): string
				return string.format("%.1fx", value)
			end,
		},
		{
			Id = "DebugAllowedValuesSlider",
			Type = "Slider",
			Label = "Max FPS (example)",
			Category = "DEBUG EXAMPLES",
			Scope = "Both",
			Persist = false,
			AllowedValues = { 30, 60, 90, 120, 144 },
			Default = 60,
			Format = function(value: number): string
				return `{value} FPS`
			end,
		},
		{
			Id = "DebugLobbyOnly",
			Type = "Toggle",
			Label = "Lobby-Only Setting (example)",
			Category = "DEBUG EXAMPLES",
			Scope = "Lobby",
			Persist = false,
			Values = { true, false },
			Labels = { "ON", "OFF" },
			Default = false,
		},
		{
			Id = "DebugArenaOnly",
			Type = "Toggle",
			Label = "Arena-Only Setting (example)",
			Category = "DEBUG EXAMPLES",
			Scope = "Arena",
			Persist = false,
			Values = { true, false },
			Labels = { "ON", "OFF" },
			Default = false,
		},
	}
	for _, definition in examples do
		table.insert(Definitions, definition)
	end
end

for _, definition in Definitions do
	assert(definition.Id ~= "", "[SettingsRegistry] every setting needs a non-empty Id")
	if definition.Type == "Toggle" then
		assert(#definition.Values == 2, `[SettingsRegistry] "{definition.Id}" must declare exactly two Values`)
		assert(#definition.Labels == 2, `[SettingsRegistry] "{definition.Id}" must declare exactly two Labels`)
	end
end

local byId: { [string]: Definition } = {}
for _, definition in Definitions do
	assert(byId[definition.Id] == nil, `[SettingsRegistry] duplicate setting id "{definition.Id}"`)
	byId[definition.Id] = definition
end

function SettingsRegistry.all(): { Definition }
	return Definitions
end

function SettingsRegistry.get(id: string): Definition?
	return byId[id]
end

function SettingsRegistry.isPersisted(definition: Definition): boolean
	return definition.Persist ~= false
end

function SettingsRegistry.appliesTo(definition: Definition, place: Scope): boolean
	return definition.Scope == "Both" or definition.Scope == place
end

function SettingsRegistry.forPlace(place: "Lobby" | "Arena"): { Definition }
	local result = {}
	for _, definition in Definitions do
		if SettingsRegistry.appliesTo(definition, place) then
			table.insert(result, definition)
		end
	end
	return result
end

return SettingsRegistry
