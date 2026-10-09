-- Description: Registers the game-specific Cmdr argument types (cosmetics, crates, quests, profile fields) so commands can accept validated, autocompleted game identifiers.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local Cosmetics = require(Config:WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Crates = require(Config:WaitForChild("Economy"):WaitForChild("Crates"))
local Quests = require(Config:WaitForChild("Progression"):WaitForChild("Quests"))
local ModeRegistry = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Modes"):WaitForChild("ModeRegistry")
)

local SimUtil =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Sim"):WaitForChild("SimUtil"))

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
	registry:RegisterType(
		"cosmeticId",
		registry.Cmdr.Util.MakeEnumType("cosmetic", SimUtil.sortedKeys(Cosmetics.Items))
	)
	registry:RegisterType(
		"cosmeticSlot",
		registry.Cmdr.Util.MakeEnumType("cosmetic slot", SimUtil.sortedKeys(Cosmetics.Slots))
	)
	registry:RegisterType("crateId", registry.Cmdr.Util.MakeEnumType("crate", SimUtil.sortedKeys(Crates)))
	registry:RegisterType(
		"profileField",
		registry.Cmdr.Util.MakeEnumType("profile field", {
			"Bonks",
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
