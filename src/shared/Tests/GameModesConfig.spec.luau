-- Description: Spec that the shipped game mode configuration offers the launch modes and keeps the disabled entries as explicit stubs.

--!strict

local T = require(script.Parent.TestKit)
local GameModes = require(script.Parent.Parent.Parent.Config.Gameplay.GameModes)

T.describe("GameModes config", function()
	T.it("offers launch modes while retaining the disabled Infection stub", function()
		T.expect(table.concat(GameModes.VoteOptions, ",")):toEqual("FFA,TDM")
		T.expect(GameModes.Modes.FFA.Enabled):toBeTruthy()
		T.expect(GameModes.Modes.TDM.Enabled):toBeTruthy()
		T.expect(not GameModes.Modes.Infection.Enabled):toBeTruthy()
	end)

	-- Empty, not a stand-in asset id: both read paths treat empty as "no art yet"
	-- and fall back to the authored placeholder, where a stub id made every ballot
	-- render request an asset that does not exist. When real key art lands, these
	-- become rbxassetid:// strings and this expectation flips with them.
	T.it("leaves thumbnails empty until key art lands", function()
		for _, definition in GameModes.Modes do
			T.expect(definition.ThumbnailId):toEqual("")
		end
	end)

	T.it("keeps the enabled Splashdown mode off the arena ballot and in its own queue", function()
		T.expect(GameModes.Modes.Splashdown.Enabled):toBeTruthy()
		T.expect(table.find(GameModes.VoteOptions, "Splashdown")):toBeNil()
		T.expect(GameModes.ModeQueue("Splashdown")):toEqual("Splashdown")
		T.expect(GameModes.ModeQueue("FFA")):toEqual("Arena")
		T.expect(GameModes.QueueCapacity("Splashdown")):toEqual(30)
		T.expect(GameModes.QueueCapacity("Arena")):toEqual(GameModes.MatchCapacity)
		T.expect(GameModes.QueueCapacity("Nope")):toEqual(GameModes.MatchCapacity)
	end)

	T.it("labels combat by mode with combat as the default for unknown ids", function()
		T.expect(GameModes.IsCombat("Splashdown")):toEqual(false)
		T.expect(GameModes.IsCombat("TDM")):toEqual(true)
		T.expect(GameModes.IsCombat(nil)):toEqual(true)
		T.expect(GameModes.ScoreLabel("Splashdown")):toEqual("POINTS")
		T.expect(GameModes.ScoreLabel("FFA")):toEqual("ELIMS")
		T.expect(GameModes.ScoreLabel("")):toEqual("ELIMS")
	end)
end)

return true
