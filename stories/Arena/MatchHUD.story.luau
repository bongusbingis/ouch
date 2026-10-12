--[[
    The in-match HUD (MatchHUD): objective line, clock, team score bars or the FFA elimination
    readout, the standings strip, the SCORES button and the respawn / spectating banner.

    Why: one HUD serves every combat mode, and its copy changes with the mode and the local
    player's state -- each of those is a state here, side by side, built through the real
    MatchHUDModel.build from Fixtures.matchHUD (eight fixture players, local player "YOU").

    States
      TDM          team deathmatch, Red 18 / Blue 22 to 40, local player on Blue.
      FFA          free-for-all to 15, no teams.
      Respawning   the old story's "Respawning" attribute variant: local player dead, BACK IN 3.
      Starting     phase Starting (pre-round).
      Infection    Survivors vs Infected, no elimination target (headcount bars).
      Spectating   not eligible this round: YOU'LL JOIN THE NEXT ROUND.
      Scoreboard   the scoreboard overlay open over the HUD.

    Every state is interactive: SCORES / the strip toggle the scoreboard, close shuts it. MatchHUD
    lays out from the camera viewport (useArenaHUDLayout), so these are Screen frames; use the
    Device emulator for the phone layout. Teammate name markers are BillboardGuis on character
    heads and are not stubbable here.
]]

--!strict

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local MatchHUD = require(StoryRoot.Components:WaitForChild("MatchHUD"))

local c = React.createElement

local function HUD(props: { Kind: string })
	local open, setOpen = React.useState(props.Kind == "Scoreboard")
	local view = Fixtures.matchHUD(props.Kind)
	view.scoreboardOpen = open
	return c(MatchHUD, {
		Snapshot = view,
		Visible = true,
		OnToggleScores = function()
			setOpen(not open)
		end,
		OnCloseScores = function()
			setOpen(false)
		end,
	})
end

local KINDS = {
	{ "TDM", "Red 18 · Blue 22 · to 40" },
	{ "FFA", "To 15, no teams" },
	{ "Respawning", "Local player down: BACK IN 3" },
	{ "Starting", "Pre-round phase" },
	{ "Infection", "Survivors vs Infected, no target" },
	{ "Spectating", "Not eligible this round" },
	{ "Scoreboard", "Scoreboard overlay open" },
}

local states = {}
for _, kind in KINDS do
	table.insert(states, {
		Name = kind[1],
		Note = kind[2],
		Screen = true,
		Fit = 0.5,
		Element = c(HUD, { Kind = kind[1] }),
	})
end

return StoryRoot.story({
	Title = "Match HUD",
	Summary = "MatchHUD in every mode and local-player state, built by MatchHUDModel from shared fixture players. "
		.. "SCORES toggles the scoreboard.",
	States = states,
})
