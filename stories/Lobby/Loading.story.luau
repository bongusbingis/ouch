--[[
    The lobby-side LoadingScreen (the candy backdrop, OUCH! logo and cream status panel) in the
    states a lobby player meets on the way into a match. Full-viewport, so Screen frames, two per
    row.

    States: SPLASHDOWN ROSTER (kicker, title, 18 OF 24 READY with a 75% striped bar and a tip --
    the old story's single state), TELEPORTING (no progress value -> bouncing candy dots),
    STATIC (Static = true: the held, no-motion screen used for teleport handoffs), TELEPORT FAILED
    (TRY AGAIN primary + BACK secondary actions), and a long title/detail pair that has to wrap.
    Actions print. The arena's loading/return states are in Arena/Loading.story.
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local LoadingScreen = require(StoryRoot.Components:WaitForChild("LoadingScreen"))

local c = React.createElement

local TIP = "PURPLE LAVA SENDS YOU BACK TO YOUR LAST CHECKPOINT."

local function screen(props: { [string]: any }): any
	local merged: { [string]: any } = { Visible = true }
	for key, value in props do
		merged[key] = value
	end
	return c(LoadingScreen, merged)
end

return StoryRoot.story({
	Title = "Lobby loading",
	Summary = "LoadingScreen while a match fills, while teleporting, held static, after a failure, and with long copy.",
	States = {
		{
			Name = "Splashdown roster",
			Note = "75% bar + tip.",
			Screen = true,
			Fit = 0.5,
			Element = screen({
				Kicker = "SPLASHDOWN",
				Title = "GETTING EVERYONE READY",
				Detail = "18 OF 24 READY",
				Progress = 0.75,
				Tip = TIP,
			}),
		},
		{
			Name = "Teleporting",
			Note = "No progress: candy dots.",
			Screen = true,
			Fit = 0.5,
			Element = screen({
				Kicker = "ARENA PVP",
				Title = "JOINING MATCH",
				Detail = "MATCH READY — TELEPORTING",
				Tip = TIP,
			}),
		},
		{
			Name = "Static",
			Note = "Held still for teleport handoff.",
			Screen = true,
			Fit = 0.5,
			Element = screen({ Title = "TELEPORTING", Static = true }),
		},
		{
			Name = "Teleport failed",
			Note = "Primary + secondary actions.",
			Screen = true,
			Fit = 0.5,
			Element = screen({
				Kicker = "ARENA PVP",
				Title = "COULDN'T JOIN THE MATCH",
				Detail = "THE SERVER DIDN'T ANSWER IN TIME",
				PrimaryAction = {
					Text = "TRY AGAIN",
					Style = "Primary",
					OnActivated = Fixtures.log("Loading", "TRY AGAIN"),
				},
				SecondaryAction = { Text = "BACK", Style = "Secondary", OnActivated = Fixtures.log("Loading", "BACK") },
			}),
		},
		{
			Name = "Long copy",
			Note = "Wrapping title and detail.",
			Screen = true,
			Fit = 0.5,
			Element = screen({
				Kicker = "SPLASHDOWN",
				Title = "WAITING FOR THE REST OF YOUR PARTY TO FINISH LOADING IN",
				Detail = "SOME PLAYERS ARE STILL DOWNLOADING THE COURSE — THIS USUALLY TAKES A FEW SECONDS",
				Progress = 0.4,
				Tip = TIP,
			}),
		},
	},
})
