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

	T.it("keeps thumbnails on the shared stub id until key art lands", function()
		for _, definition in GameModes.Modes do
			T.expect(definition.ThumbnailId):toEqual("rbxassetid://123456789")
		end
	end)
end)

return true
