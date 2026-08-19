--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Config = ReplicatedStorage:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("GameModes"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModeRegistry = require(Shared:WaitForChild("Game"):WaitForChild("Modes"):WaitForChild("ModeRegistry"))
local GameModeSelect = require(Shared:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GameModeSelect"))
local GameVersion = require(Shared:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GameVersion"))
local useExternalStore = require(Shared:WaitForChild("UI"):WaitForChild("Hooks"):WaitForChild("useExternalStore"))
local ModeVoteClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ModeVoteClient"))

local c = React.createElement

local function imageId(value: any): string
	if value == nil or value == "" then
		return ""
	end
	local text = tostring(value)
	return if string.find(text, "rbxassetid://", 1, true) == 1 then text else `rbxassetid://{text}`
end

return function()
	local snapshot = useExternalStore(ModeVoteClient.getSnapshot, ModeVoteClient.subscribe)
	local modes = {}
	for _, modeId in snapshot.options do
		local definition = GameModes.Modes[modeId]
		local mode = ModeRegistry.get(modeId)
		assert(definition ~= nil and definition.Enabled, `[ArenaApp] unavailable configured mode "{modeId}"`)
		assert(mode ~= nil, `[ArenaApp] unregistered mode "{modeId}"`)
		table.insert(modes, {
			Id = modeId,
			Title = definition.Title,
			Description = definition.Description,
			ThumbnailId = imageId(definition.ThumbnailId),
			SortOrder = definition.SortOrder,
			VoteCount = snapshot.voteCounts[modeId] or 0,
			Selected = snapshot.selectedModeId == modeId,
		})
	end

	return c("ScreenGui", {
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		GameModeSelect = c(GameModeSelect, {
			Active = snapshot.admitted and snapshot.open,
			Modes = modes,
			EndsAt = snapshot.endsAt,
			DurationSeconds = snapshot.durationSeconds,
			OnVote = ModeVoteClient.vote,
		}),
		GameVersion = c(GameVersion),
	})
end
