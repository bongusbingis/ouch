--!strict

local T = require(script.Parent.TestKit)
local GameModes = require(script.Parent.Parent.Parent.Config.GameModes)

T.describe("GameModes config", function()
	T.it("offers every implemented mode", function()
		T.expect(table.concat(GameModes.VoteOptions, ",")):toEqual("FFA,TDM,Infection")
		T.expect(GameModes.Modes.FFA.Enabled):toBeTruthy()
		T.expect(GameModes.Modes.TDM.Enabled):toBeTruthy()
		T.expect(GameModes.Modes.Infection.Enabled):toBeTruthy()
	end)

	T.it("keeps thumbnails as explicit empty configuration stubs", function()
		T.expect(GameModes.Modes.FFA.ThumbnailId):toEqual("")
		T.expect(GameModes.Modes.TDM.ThumbnailId):toEqual("")
		T.expect(GameModes.Modes.Infection.ThumbnailId):toEqual("")
	end)
end)

return true
