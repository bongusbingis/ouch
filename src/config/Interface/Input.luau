--!strict

-- Declarative input map materialized under each Player by InputSetup. Only the
-- OnboardingSkip action is read as an InputAction. Combat throw, catch, and aim
-- run through the raw-input Combat layer (PlayerModule/Combat) -- catch is
-- contextual on the throw button, not a separate binding -- and WeaponEquip is
-- consumed as raw KeyCode data by DeviceInput and the toolbar view model, not as
-- bindings here. Do not add throw/catch/aim bindings expecting them to fire.

export type BindingDef = {
	Name: string?,
	KeyCode: Enum.KeyCode?,
	Scriptable: boolean?,
	DisplayName: string?,
}

export type ActionDef = {
	Name: string,
	Type: Enum.InputActionType,
	Bindings: { BindingDef },
}

return {
	ContextName = "CombatInput",
	WeaponEquip = {
		Hammer = {
			Keyboard = Enum.KeyCode.One,
			KeyboardLabel = "1",
			Gamepad = Enum.KeyCode.ButtonL1,
			GamepadLabel = "L1",
		},
		Dodgeball = {
			Keyboard = Enum.KeyCode.Two,
			KeyboardLabel = "2",
			Gamepad = Enum.KeyCode.ButtonR1,
			GamepadLabel = "R1",
		},
	},
	-- Hold to open the radial emote selector; consumed as raw KeyCode data by
	-- EmoteWheelController, not as an InputAction. B and DPadDown are unbound
	-- elsewhere: X is OnboardingSkip, 1/2 and L1/R1 equip weapons, R2 throws.
	EmoteWheel = {
		Keyboard = Enum.KeyCode.B,
		KeyboardLabel = "B",
		Gamepad = Enum.KeyCode.DPadDown,
		GamepadLabel = "DPad Down",
	},
	-- HUD and menu actions with one keyboard key and one gamepad button each; the
	-- binders (CombatMenuClient, MatchHUDClient, LobbyNavigation) and InputHint read
	-- these so a shown hint can never drift from the real bind. ButtonStart is
	-- Roblox's own menu and is never used. Gamepad combat owns R2 (throw), X
	-- (hammer), B (cancel throw), A (jump), L1/R1 (equip) and DPadDown (emotes).
	Hints = {
		Menu = { Keyboard = Enum.KeyCode.M, Gamepad = Enum.KeyCode.ButtonY },
		-- Hold to view; ArenaCoreUI hides the PlayerList so Tab is free.
		Scores = { Keyboard = Enum.KeyCode.Tab, Gamepad = Enum.KeyCode.ButtonSelect },
		Back = { Keyboard = Enum.KeyCode.Escape, Gamepad = Enum.KeyCode.ButtonB },
		-- Gamepad-only: shown on the focused control (Roblox activates it with A).
		Confirm = { Gamepad = Enum.KeyCode.ButtonA },
		-- Menu tab cycling only while a tab rail owns input (never during combat).
		TabPrevious = { Gamepad = Enum.KeyCode.ButtonL1 },
		TabNext = { Gamepad = Enum.KeyCode.ButtonR1 },
		-- Mirrors the OnboardingSkip InputAction bindings below (spec-checked).
		Skip = { Keyboard = Enum.KeyCode.X, Gamepad = Enum.KeyCode.ButtonB },
	},
	Actions = {
		{
			Name = "OnboardingSkip",
			Type = Enum.InputActionType.Bool,
			Bindings = {
				{ Name = "Keyboard", KeyCode = Enum.KeyCode.X, DisplayName = "X" },
				{ Name = "Gamepad", KeyCode = Enum.KeyCode.ButtonB },
			},
		},
	} :: { ActionDef },
}
