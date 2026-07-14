--!strict

-- Declarative input map, materialized as InputContext/InputAction/InputBinding
-- instances under each Player by InputSetup. Console/gamepad support later is
-- additional binding rows here — no code changes.

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
	Actions = {
		{
			Name = "Throw",
			Type = Enum.InputActionType.Bool,
			Bindings = {
				{ Name = "Mouse", KeyCode = Enum.KeyCode.MouseLeftButton },
				-- Pulsed by InputRouter on non-GUI screen taps (touch devices).
				{ Name = "TouchFeed", Scriptable = true },
			},
		},
		{
			-- Camera look direction, fed every frame by InputRouter through a
			-- scriptable binding so it replays correctly during resimulation.
			Name = "Aim",
			Type = Enum.InputActionType.Direction3D,
			Bindings = {
				{ Name = "AimFeed", Scriptable = true },
			},
		},
	} :: { ActionDef },
}
