--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local ModeVoteClient = {}

-- startsAt and winnerModeId are projected by ModeVoteService but not yet rendered: the winner
-- presentation is deferred. They are decoded here so the projection keeps exactly one owner.
export type Snapshot = {
	admitted: boolean,
	open: boolean,
	startsAt: number,
	endsAt: number,
	durationSeconds: number,
	options: { string },
	voteCounts: { [string]: number },
	selectedModeId: string?,
	winnerModeId: string?,
	revision: number,
}

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("ModeVoteState")
assert(state:IsA("Folder"), "[ModeVoteClient] ReplicatedStorage.ModeVoteState must be a Folder")

function ModeVoteClient.getSnapshot(): Snapshot
	local options = {}
	local voteCounts = {}
	local optionCount = (state:GetAttribute("optionCount") :: number?) or 0
	for index = 1, optionCount do
		local modeId = state:GetAttribute(`Option{index}Id`)
		if typeof(modeId) == "string" and modeId ~= "" then
			table.insert(options, modeId)
			voteCounts[modeId] = (state:GetAttribute(`Option{index}Count`) :: number?) or 0
		end
	end
	local selectedModeId = player:GetAttribute("ModeVoteSelection")
	local winnerModeId = state:GetAttribute("winnerModeId")
	return {
		admitted = player:GetAttribute("ArenaAdmission") ~= "Rejected",
		open = state:GetAttribute("open") == true,
		startsAt = (state:GetAttribute("startsAt") :: number?) or 0,
		endsAt = (state:GetAttribute("endsAt") :: number?) or 0,
		durationSeconds = (state:GetAttribute("durationSeconds") :: number?) or 0,
		options = options,
		voteCounts = voteCounts,
		selectedModeId = if typeof(selectedModeId) == "string" then selectedModeId else nil,
		winnerModeId = if typeof(winnerModeId) == "string" and winnerModeId ~= "" then winnerModeId else nil,
		revision = (state:GetAttribute("revision") :: number?) or 0,
	}
end

function ModeVoteClient.subscribe(callback: (Snapshot) -> ()): () -> ()
	local function changed()
		callback(ModeVoteClient.getSnapshot())
	end
	-- Every attribute on the folder, not just revision: attributes do not
	-- replicate in the order they were written, so a subscriber woken only by
	-- revision can read a snapshot whose open flag has not arrived yet and never
	-- be told again.
	local stateConnection = state.AttributeChanged:Connect(changed)
	local selectionConnection = player:GetAttributeChangedSignal("ModeVoteSelection"):Connect(changed)
	local admissionConnection = player:GetAttributeChangedSignal("ArenaAdmission"):Connect(changed)
	return function()
		stateConnection:Disconnect()
		selectionConnection:Disconnect()
		admissionConnection:Disconnect()
	end
end

function ModeVoteClient.vote(modeId: string)
	Network.fireServer("SubmitModeVote", modeId)
end

return table.freeze(ModeVoteClient)
