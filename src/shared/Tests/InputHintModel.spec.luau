-- Description: Spec for input-hint selection (keycap on keyboard/mouse, controller glyph on gamepad, nothing on touch), hint width reservation, shoulder-button tab cycling, and the HUD bind table staying conflict-free with combat and in step with the onboarding skip action.

--!strict

local T = require(script.Parent.TestKit)
local Model = require(script.Parent.Parent.UI.Models.InputHintModel)
local Tokens = require(script.Parent.Parent.UI.Tokens)
local Input = require(script.Parent.Parent.Parent.Config.Interface.Input)

local MENU = Input.Hints.Menu

T.describe("InputHintModel.resolve", function()
	T.it("shows the keyboard key on Mouse (and EmoteWheel's Keyboard alias)", function()
		local hint = Model.resolve("Mouse", MENU) :: any
		T.expect(hint.kind):toEqual("Key")
		T.expect(hint.text):toEqual("M")
		T.expect((Model.resolve("Keyboard", Input.Hints.Back) :: any).text):toEqual("ESC")
		T.expect((Model.resolve("Mouse", Input.WeaponEquip.Hammer) :: any).text):toEqual("1")
	end)

	T.it("shows the platform glyph on Gamepad with a readable fallback", function()
		local hint = Model.resolve("Gamepad", MENU) :: any
		T.expect(hint.kind):toEqual("Glyph")
		T.expect(hint.keyCode):toEqual(Enum.KeyCode.ButtonY)
		T.expect(hint.fallback):toEqual("Y")
		T.expect((Model.resolve("Gamepad", Input.Hints.TabPrevious) :: any).fallback):toEqual("LB")
	end)

	T.it("shows nothing on touch, for a missing binding, or for a device the binding lacks", function()
		T.expect(Model.resolve("Touch", MENU).kind):toEqual("None")
		T.expect(Model.resolve("Mouse", nil).kind):toEqual("None")
		T.expect(Model.resolve("Mouse", Input.Hints.Confirm).kind):toEqual("None")
		T.expect(Model.resolve("Mouse", Input.Hints.TabNext).kind):toEqual("None")
	end)
end)

T.describe("InputHintModel width", function()
	T.it("reserves nothing on touch and at least one keycap plus gap otherwise", function()
		T.expect(Model.reserve(Model.resolve("Touch", MENU))):toEqual(0)
		local S = Tokens.InputHint
		T.expect(Model.reserve(Model.resolve("Gamepad", MENU))):toEqual(S.Size + S.Gap)
		T.expect(Model.reserve(Model.resolve("Mouse", MENU), 12)):toEqual(S.Size + S.Gap)
		-- Word keys grow past the square cap.
		T.expect(Model.width(Model.resolve("Mouse", Input.Hints.Scores), 34)):toEqual(34 + S.KeyPadding * 2)
		T.expect(S.TextSize >= Tokens.Type.HudMinimum):toBeTruthy()
	end)
end)

T.describe("InputHintModel.cycle", function()
	local ids = { "SplashScreen", "Shop", "Inventory", "Settings" }
	T.it("steps forward and back with wrap-around", function()
		T.expect(Model.cycle(ids, nil, "Shop", 1)):toEqual("Inventory")
		T.expect(Model.cycle(ids, nil, "Settings", 1)):toEqual("SplashScreen")
		T.expect(Model.cycle(ids, nil, "SplashScreen", -1)):toEqual("Settings")
	end)

	T.it("skips disabled tabs and starts from an edge for an unknown page", function()
		T.expect(Model.cycle(ids, { Inventory = false }, "Shop", 1)):toEqual("Settings")
		T.expect(Model.cycle(ids, nil, "Unknown", 1)):toEqual("SplashScreen")
		T.expect(Model.cycle(ids, nil, "Unknown", -1)):toEqual("Settings")
		T.expect(Model.cycle({ "Only" }, nil, "Only", 1)):toEqual("Only")
	end)
end)

T.describe("HUD input bindings", function()
	T.it("never use Roblox's menu button and stay clear of gameplay gamepad binds", function()
		local combat = {
			[Enum.KeyCode.ButtonR2] = "throw",
			[Enum.KeyCode.ButtonX] = "hammer",
			[Enum.KeyCode.ButtonA] = "jump",
			[Input.WeaponEquip.Hammer.Gamepad] = "equip",
			[Input.WeaponEquip.Dodgeball.Gamepad] = "equip",
			[Input.EmoteWheel.Gamepad] = "emote",
		}
		for _, name in { "Menu", "Scores" } do
			local binding = Input.Hints[name]
			T.expect(binding.Keyboard ~= nil and binding.Gamepad ~= nil):toBeTruthy()
			T.expect(binding.Gamepad ~= Enum.KeyCode.ButtonStart):toBeTruthy()
			T.expect(combat[binding.Gamepad]):toBeNil()
			T.expect(binding.Keyboard ~= Input.EmoteWheel.Keyboard):toBeTruthy()
		end
		T.expect(Input.Hints.Menu.Gamepad ~= Input.Hints.Scores.Gamepad):toBeTruthy()
		T.expect(Input.Hints.Menu.Keyboard ~= Input.Hints.Scores.Keyboard):toBeTruthy()
	end)

	T.it("mirrors the OnboardingSkip InputAction so the SKIP hint cannot drift", function()
		local skip
		for _, action in Input.Actions do
			if action.Name == "OnboardingSkip" then
				skip = action
			end
		end
		T.expect(skip ~= nil):toBeTruthy()
		for _, binding in skip.Bindings do
			T.expect(Input.Hints.Skip[binding.Name]):toEqual(binding.KeyCode)
		end
	end)
end)

return true
