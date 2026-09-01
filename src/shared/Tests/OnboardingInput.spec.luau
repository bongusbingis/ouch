--!strict

local T = require(script.Parent.TestKit)
local Input = require(script.Parent.Parent.Parent.Config.Interface.Input)

local function actionNamed(name: string): any
	for _, action in Input.Actions do
		if action.Name == name then
			return action
		end
	end
	return nil
end

local function keyFor(action: any, name: string): Enum.KeyCode?
	for _, binding in action.Bindings do
		if binding.Name == name then
			return binding.KeyCode
		end
	end
	return nil
end

T.describe("Onboarding input", function()
	T.it("gives locked-cursor devices an explicit skip binding", function()
		local action = actionNamed("OnboardingSkip")
		T.expect(action ~= nil):toBeTruthy()
		T.expect(keyFor(action, "Keyboard")):toEqual(Enum.KeyCode.X)
		T.expect(keyFor(action, "Gamepad")):toEqual(Enum.KeyCode.ButtonB)
	end)
end)

return true
