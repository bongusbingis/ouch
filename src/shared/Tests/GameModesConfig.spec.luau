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
end)

return true
