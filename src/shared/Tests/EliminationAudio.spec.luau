-- Description: Spec for elimination sound resolution: weapon variants, environmental eliminations, equipped-item validation, and default fallbacks.

--!strict

local T = require(script.Parent.TestKit)
local EliminationAudio = require(script.Parent.Parent.Game.Cosmetics.EliminationAudio)

local CATALOG = {
	Defaults = {
		ElimEffectAssets = {
			ElimEffect = {
				DodgeballSound = "DefaultDodgeball",
				HammerSound = "DefaultHammer",
			},
		},
	},
	Items = {
		EquippedSound = {
			Category = "ElimEffectAssets",
			ElimEffect = {
				DodgeballSound = "EquippedDodgeball",
				HammerSound = "EquippedHammer",
			},
		},
		WrongCategory = {
			Category = "BallAssets",
			ElimEffect = {
				DodgeballSound = "WrongDodgeball",
				HammerSound = "WrongHammer",
			},
		},
	},
}

T.describe("EliminationAudio", function()
	T.it("uses the eliminator's equipped weapon-specific cue", function()
		local dodgeball, dodgeballFallback = EliminationAudio.soundFor(CATALOG, "EquippedSound", {
			kind = "Elim",
			sourceId = "eliminator",
			targetId = "victim",
			projectileId = "ball",
		})
		local hammer, hammerFallback = EliminationAudio.soundFor(CATALOG, "EquippedSound", {
			kind = "Elim",
			sourceId = "eliminator",
			targetId = "victim",
		})
		T.expect(dodgeball):toEqual("EquippedDodgeball")
		T.expect(dodgeballFallback):toEqual("DefaultDodgeball")
		T.expect(hammer):toEqual("EquippedHammer")
		T.expect(hammerFallback):toEqual("DefaultHammer")
	end)

	T.it("falls back for a missing, empty, or wrong-category equipped item", function()
		local function expectFallback(itemId: string?)
			local sound = EliminationAudio.soundFor(CATALOG, itemId, {
				kind = "Elim",
				sourceId = "eliminator",
				targetId = "victim",
				projectileId = "ball",
			})
			T.expect(sound):toEqual("DefaultDodgeball")
		end
		expectFallback(nil)
		for _, itemId in { "", "Missing", "WrongCategory" } do
			expectFallback(itemId)
		end
	end)

	T.it("keeps uncredited projectile and zone eliminations distinct", function()
		local projectile = EliminationAudio.soundFor(CATALOG, nil, {
			kind = "Elim",
			targetId = "victim",
			projectileId = "ball",
		})
		local zone, fallback = EliminationAudio.soundFor(CATALOG, "EquippedSound", {
			kind = "Elim",
			targetId = "victim",
		})
		T.expect(projectile):toEqual("DefaultDodgeball")
		T.expect(zone):toEqual("ElimZoneFall")
		T.expect(fallback):toBeNil()
	end)
end)

return true
