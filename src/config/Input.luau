--!strict

-- Declarative input map, materialized as InputContext/InputAction/InputBinding
-- instances under each Player by InputSetup.

export type BindingDef = {
	Name: string?,
	KeyCode: Enum.KeyCode?,
	Scriptable: boolean?,
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
			Gamepad = Enum.KeyCode.ButtonL1,
		},
		Dodgeball = {
			Keyboard = Enum.KeyCode.Two,
			Gamepad = Enum.KeyCode.ButtonR1,
		},
	},
	-- Lateral offset, in studs, applied to the camera while the mouse is
	-- locked to center. Positive moves the camera to the right, making the
	Actions = {
		{
			Name = "Throw",
			Type = Enum.InputActionType.Bool,
			Bindings = {
				{ Name = "Mouse", KeyCode = Enum.KeyCode.MouseLeftButton },
				{ Name = "Gamepad", KeyCode = Enum.KeyCode.ButtonR2 },
				-- Pulsed by InputRouter on non-GUI screen taps (touch devices).
				{ Name = "TouchFeed", Scriptable = true },
			},
		},
		{
			Name = "Catch",
			Type = Enum.InputActionType.Bool,
			Bindings = {
				{ Name = "Mouse", KeyCode = Enum.KeyCode.MouseRightButton },
				{ Name = "Keyboard", KeyCode = Enum.KeyCode.F },
				{ Name = "Gamepad", KeyCode = Enum.KeyCode.ButtonL2 },
				{ Name = "TouchFeed", Scriptable = true },
			},
		},
		{
			-- Camera look direction, fed every frame by InputRouter through a
			-- scriptable binding driven by the client aim director.
			Name = "Aim",
			Type = Enum.InputActionType.Direction3D,
			Bindings = {
				{ Name = "AimFeed", Scriptable = true },
			},
		},
	} :: { ActionDef },
}
