--[[
    The post-match results screen (PostMatchScreen): headline, podium with celebration avatars,
    reward and season progress, party panel and the PLAY AGAIN / LOBBY / SHOP actions.

    Why: post-match has many result shapes -- team / FFA / infection / race outcomes, rewards
    pending or boosted, parties of one to four, a leaving member, request errors, first match,
    future unlock rows. They come from the game's own DebugPostMatchData scenarios (via
    Fixtures.postMatchScenarios()), so the story and the in-game debug command stay in step.

    States (Switch mode -- one full screen at a time; ~25 scenarios): every DebugPostMatchData
    scenario by name (TDM VICTORY / PARTY 4, TDM DEFEAT, FFA 1ST, FFA 6TH, SURVIVORS WIN, INFECTED
    WIN, NO REWARDS, REWARDS PENDING, BOOSTS / TIER UP, TIED ROUND, SPLASHDOWN 2ND, NO PARTY
    PROJECTION, LONG PARTY NAMES, FUTURE CHALLENGE / UNLOCK / MAX, PARTY OF ONE, PARTY MEMBER,
    PARTY MEMBER LEAVING, REQUEST ERROR, PARTY RETURNING, FIRST MATCH, ...). The local player is
    put into the party at the scenario's localMemberIndex (leader when 1), as the old story did.
    PLAY AGAIN toggles the status to the PlayAgain revision (the old story's replay toggle).

    Not stubbable in edit mode: PostMatchScreen reads Players.LocalPlayer.UserId during render,
    which is nil outside Play. Each frame shows a notice until UI Labs is opened during a Play
    session (Play Solo, then open the story); the state list still shows every scenario.
]]

--!strict

local Players = game:GetService("Players")

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local PostMatchScreen = require(StoryRoot.Components:WaitForChild("PostMatchScreen"))

local c = React.createElement

local function Screen(props: { Scenario: any })
	local replay, setReplay = React.useState(false)
	local scenario = props.Scenario
	local result = scenario.result
	result.endsAt = Fixtures.serverNow() + 12
	local localUserId = (Players.LocalPlayer :: Player).UserId
	if result.party then
		local localMemberIndex = scenario.localMemberIndex or 1
		for _, member in result.party.members do
			member.isLocal = false
		end
		result.party.members[localMemberIndex].isLocal = true
		result.party.members[localMemberIndex].userId = localUserId
		if localMemberIndex == 1 then
			result.party.leaderUserId = localUserId
		end
	end
	local leaderUserId = if result.party then result.party.leaderUserId else localUserId
	return c(PostMatchScreen, {
		Visible = true,
		Result = result,
		Status = {
			resultId = result.resultId,
			revision = if replay then 2 else 1,
			state = if replay then "PlayAgain" else scenario.statusState or "Interactive",
			leaderUserId = leaderUserId,
		},
		Requesting = scenario.requesting,
		PendingAction = scenario.pendingAction,
		Error = scenario.error,
		OnPlayAgain = function()
			setReplay(not replay)
		end,
		OnReturnToLobby = Fixtures.log("PostMatch", "return to lobby"),
		OnLeaveParty = Fixtures.log("PostMatch", "leave party"),
		OnOpenShop = Fixtures.log("PostMatch", "open shop"),
	})
end

local NOTICE = "PostMatchScreen reads Players.LocalPlayer, which is nil in edit mode.\n"
	.. "Start Play Solo, then open this story in UI Labs."

local states = {}
for _, scenario in Fixtures.postMatchScenarios() do
	table.insert(states, {
		Name = scenario.name,
		Note = `{scenario.result.modeName or scenario.result.modeId or ""} · {scenario.result.resultId or ""}`,
		Screen = true,
		Element = if StoryRoot.hasLocalPlayer() then c(Screen, { Scenario = scenario }) else StoryRoot.Notice(NOTICE),
	})
end

return StoryRoot.story({
	Title = "Post-Match",
	Summary = "PostMatchScreen over every DebugPostMatchData scenario. Requires Play mode (reads LocalPlayer). "
		.. "PLAY AGAIN toggles the PlayAgain status.",
	Mode = "Switch",
	States = states,
})
