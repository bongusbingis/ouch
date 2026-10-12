--[[
    The candy loading screen (LoadingScreen) as the arena and Splashdown servers show it: logo,
    status panel with kicker pill, title and detail, a striped progress bar or bouncing dots, the
    RETURN / TRY AGAIN / STAY actions, and the tip sticker.

    Why: the arena overlay's copy and actions are decided by ArenaLoadingViewModel (copy() and
    actions()) from the loading, vote and teleport state; each state here feeds the real model a
    hand-made state, so the titles and the buttons are exactly what players see.

    States
      Loading arena        preload under way: LOADING ARENA with no detail line, progress bar.
      Waiting for players  gate held: 3 OF 6 IN ARENA, bar at 50%.
      Roster stalled       lone player, no ballot: NOT ENOUGH PLAYERS TO START + RETURN.
      Rejected             admission rejected: UNABLE TO JOIN MATCH + RETURN.
      Returning            teleport Attempting: RETURNING TO LOBBY.
      Reconnecting         teleport Retrying: ATTEMPT 2 OF 3.
      Return failed        teleport Failed: RETURN FAILED + TRY AGAIN / STAY.
      Splashdown roster    the old LoadingScreen story: SPLASHDOWN kicker, GETTING EVERYONE READY,
                           18 OF 24 READY at 75%, with a tip.

    Actions print to Output. Screen frames: the panel sizes from the safe area.
]]

--!strict

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local LoadingScreen = require(StoryRoot.Components:WaitForChild("LoadingScreen"))
local Model = require(StoryRoot.Models:WaitForChild("ArenaLoadingViewModel"))

local c = React.createElement

local ACTION_TEXT = { Retry = "TRY AGAIN", Stay = "STAY", Return = "RETURN" }

local function loadingState(overrides: { [string]: any }): any
	local loading = {
		fixedModeId = nil,
		admission = "Admitted",
		localReady = true,
		preloadReady = true,
		simulationReady = true,
		gateReleased = true,
		arrivedPlayerCount = 6,
		expectedPlayerCount = 6,
		readyPlayerCount = 6,
		matchPhase = "Idle",
	}
	for key, value in overrides do
		loading[key] = value
	end
	return loading
end

local function action(kind: string?, style: string): any
	if kind == nil then
		return nil
	end
	return { Text = ACTION_TEXT[kind] or string.upper(kind), Style = style, OnActivated = Fixtures.log("Loading", kind) }
end

local function screen(options: {
	loading: { [string]: any }?,
	teleport: any?,
	stalled: boolean?,
	progress: number?,
	tip: string?,
}): any
	local loading = loadingState(options.loading or {})
	local vote = { open = false }
	local stalled = options.stalled == true
	local title, detail = Model.copy(loading, vote, options.teleport, false, stalled)
	local primary, secondary = Model.actions(loading, options.teleport, stalled)
	return c(LoadingScreen, {
		Visible = true,
		Kicker = "ARENA",
		Title = title,
		Detail = detail,
		Progress = options.progress,
		Tip = options.tip,
		PrimaryAction = action(primary, "Primary"),
		SecondaryAction = action(secondary, "Secondary"),
	})
end

local function state(name: string, note: string, element: any): StoryRoot.State
	return { Name = name, Note = note, Screen = true, Fit = 0.5, Element = element }
end

return StoryRoot.story({
	Title = "Arena Loading",
	Summary = "LoadingScreen as the arena overlay drives it (ArenaLoadingViewModel copy + actions), "
		.. "plus the Splashdown roster wait.",
	States = {
		state("Loading arena", "Preload under way", screen({ loading = { localReady = false, preloadReady = false } })),
		state(
			"Waiting for players",
			"3 of 6 arrived",
			screen({ loading = { gateReleased = false, arrivedPlayerCount = 3 }, progress = 0.5 })
		),
		state("Roster stalled", "RETURN offered", screen({ stalled = true })),
		state("Rejected", "Admission rejected", screen({ loading = { admission = "Rejected" } })),
		state("Returning", "Teleport attempting", screen({ teleport = { state = "Attempting" } })),
		state(
			"Reconnecting",
			"Attempt 2 of 3",
			screen({ teleport = { state = "Retrying", attempt = 2, maxAttempts = 3 } })
		),
		state("Return failed", "TRY AGAIN / STAY", screen({ teleport = { state = "Failed" } })),
		state(
			"Splashdown roster",
			"Old LoadingScreen story",
			c(LoadingScreen, {
				Visible = true,
				Kicker = "SPLASHDOWN",
				Title = "GETTING EVERYONE READY",
				Detail = "18 OF 24 READY",
				Progress = 0.75,
				Tip = "PURPLE LAVA SENDS YOU BACK TO YOUR LAST CHECKPOINT.",
			})
		),
	},
})
