-- Description: Spec for the onboarding prompt: that every lesson names its own mechanic, that the obstacle lesson tells the player how to jump on their own device, that a shove reads as another go rather than a failure, and that the card and its skip button fit inside landscape, portrait and short safe areas.

--!strict

local T = require(script.Parent.TestKit)
local Model = require(script.Parent.Parent.UI.Models.OnboardingViewModel)
local State = require(script.Parent.Parent.Game.Onboarding.OnboardingState)
local Config = require(script.Parent.Parent.Parent.Config.Interface.Onboarding)

T.describe("OnboardingViewModel", function()
	T.it("names the mechanic each combat lesson teaches", function()
		T.expect(Model.build({ step = "NormalThrow" }).detail):toEqual("Aim at the dummy, then throw your ball.")
		T.expect(Model.build({ step = "Hammer" }).detail):toEqual("Get close to the dummy, then swing your hammer.")
		T.expect(Model.build({ step = "ChargedThrow" }).detail):toEqual("Hold to charge your throw, then release.")
		T.expect(Model.build({ step = "Practice" }).title):toEqual("KNOCK 'EM OUT!")
	end)

	T.it("teaches the obstacle as something to get past, on the player's own controls", function()
		T.expect(Model.build({ step = "Dodge" }).title):toEqual("GET ACROSS!")
		T.expect(Model.build({ step = "Dodge", hintLevel = 1, deviceClass = "Touch" }).detail)
			:toEqual("Tap jump as the bar sweeps past, then follow the arrow across.")
		T.expect(Model.build({ step = "Dodge", hintLevel = 1, deviceClass = "Gamepad" }).detail)
			:toEqual("Press A as the bar sweeps past, then follow the arrow across.")
		T.expect(Model.build({ step = "Dodge", hintLevel = 1, deviceClass = "Mouse" }).detail)
			:toEqual("Press Space as the bar sweeps past, then follow the arrow across.")
	end)

	T.it("reads a shove as another go and a hit as progress", function()
		T.expect(Model.build({ step = "Dodge", retrying = true }).title):toEqual("TRY AGAIN!")
		T.expect(Model.build({ step = "NormalThrow", succeeded = true }).title):toEqual("NICE!")
		T.expect(Model.build({ step = "Dodge" }).done):toEqual(1)
		T.expect(Model.build({ step = "Dodge", succeeded = true }).done):toEqual(2)
		T.expect(Model.build({ step = "Celebration" }).done):toEqual(5)
	end)

	T.it("escalates to a hint only once the player has been idle", function()
		local plain = Model.build({ step = "NormalThrow" }).detail
		local hinted = Model.build({ step = "NormalThrow", hintLevel = 2 }).detail
		T.expect(plain ~= hinted):toEqual(true)
		T.expect(Model.build({ step = "Celebration" }).celebrating):toEqual(true)
		T.expect(Model.build({ step = "Dodge" }).skip):toEqual("SKIP")
	end)

	T.it("keeps a prompt for every step the flow can publish", function()
		for _, step in State.Steps do
			local view = Model.build({ step = step })
			T.expect(#view.title > 0):toEqual(true)
			T.expect(#view.detail > 0):toEqual(true)
		end
		T.expect(Config.Analytics.Steps.Dodge.name):toEqual("Dodge")
	end)

	T.it("keeps the card inside landscape, portrait and short safe widths", function()
		for _, size in { Vector2.new(1920, 1080), Vector2.new(874, 306), Vector2.new(360, 680), Vector2.new(1024, 420) } do
			local layout = Model.layout(size.X, size.Y)
			T.expect(layout.width + layout.edge * 2 <= size.X):toEqual(true)
			T.expect(layout.height + layout.edge < size.Y):toEqual(true)
		end
	end)
end)

return true
