--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local Cosmetics = require(Config:WaitForChild("Cosmetics"))
local Crates = require(Config:WaitForChild("Crates"))
local Quests = require(Config:WaitForChild("Quests"))
local ModeRegistry = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Modes"):WaitForChild("ModeRegistry")
)

local function sortedKeys(values: { [string]: any }): { string }
	local keys = {}
	for key in values do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

return function(registry)
	local modes = {}
	for _, mode in ModeRegistry.all() do
		table.insert(modes, mode.id)
	end
	table.sort(modes)

	local quests = {}
	for _, definition in Quests.Definitions do
		table.insert(quests, definition.id)
	end
	table.sort(quests)

	registry:RegisterType("modeId", registry.Cmdr.Util.MakeEnumType("mode", modes))
	registry:RegisterType("questId", registry.Cmdr.Util.MakeEnumType("quest", quests))
	registry:RegisterType("cosmeticId", registry.Cmdr.Util.MakeEnumType("cosmetic", sortedKeys(Cosmetics.Items)))
	registry:RegisterType("cosmeticSlot", registry.Cmdr.Util.MakeEnumType("cosmetic slot", sortedKeys(Cosmetics.Slots)))
	registry:RegisterType("crateId", registry.Cmdr.Util.MakeEnumType("crate", sortedKeys(Crates)))
	registry:RegisterType(
		"profileField",
		registry.Cmdr.Util.MakeEnumType("profile field", {
			"Cash",
			"XP",
			"Elims",
			"Deaths",
			"Catches",
			"Wins",
			"Losses",
			"MatchesPlayed",
		})
	)
	registry:RegisterType("deviceClass", registry.Cmdr.Util.MakeEnumType("device class", { "Mouse", "Touch" }))
end
