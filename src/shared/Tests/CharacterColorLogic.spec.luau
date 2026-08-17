--!strict

local T = require(script.Parent.TestKit)
local CharacterColorLogic = require(script.Parent.Parent.Game.Economy.CharacterColorLogic)
local Cosmetics = require(script.Parent.Parent.Parent.Config.Cosmetics)

T.describe("CharacterColorLogic", function()
	T.it("resolves an equipped character color from the catalog", function()
		local expected = Cosmetics.Items.CharacterColorPurple.PreviewColor
		T.expect(CharacterColorLogic.resolve(Cosmetics, "CharacterColorPurple")):toEqual(expected)
	end)

	T.it("uses the default for an empty, unknown, or wrong-category equip", function()
		local expected = Cosmetics.Defaults.CharacterColor.PreviewColor
		T.expect(CharacterColorLogic.resolve(Cosmetics, "")):toEqual(expected)
		T.expect(CharacterColorLogic.resolve(Cosmetics, "Missing")):toEqual(expected)
		T.expect(CharacterColorLogic.resolve(Cosmetics, "BallRed")):toEqual(expected)
	end)
end)

return true
