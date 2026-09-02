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
