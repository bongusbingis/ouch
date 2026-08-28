--!strict

-- Declarative input map, materialized as InputContext/InputAction/InputBinding
-- instances under each Player by InputSetup.

export type BindingDef = {
	Name: string?,
	KeyCode: Enum.KeyCode?,
	Scriptable: boolean?,
	-- What an InputActionLabel prints when the engine has no glyph for this
	-- binding's key. Without it a mouse prompt reads "MouseLeftButton"; gamepad
	-- bindings deliberately leave it unset so the platform's own button art
	-- wins, which is what makes an Xbox pad show A and a DualSense show Cross.
	DisplayName: string?,
}

export type ActionDef = {
	Name: string,
	Type: Enum.InputActionType,
	Bindings: { BindingDef },
}

return {
	ContextName = "CombatInput",
	-- Lateral offset, in studs, applied to the camera while the mouse is
	-- locked to center. Positive moves the camera to the right, making the
	Actions = {
		{
			Name = "Throw",
			Type = Enum.InputActionType.Bool,
			Bindings = {
				{ Name = "Mouse", KeyCode = Enum.KeyCode.MouseLeftButton, DisplayName = "LMB" },
				{ Name = "Gamepad", KeyCode = Enum.KeyCode.ButtonR2 },
				-- Pulsed by InputRouter on non-GUI screen taps (touch devices).
				{ Name = "TouchFeed", Scriptable = true, DisplayName = "TAP" },
			},
		},
		{
			Name = "Catch",
			Type = Enum.InputActionType.Bool,
			Bindings = {
				{ Name = "Mouse", KeyCode = Enum.KeyCode.MouseRightButton, DisplayName = "RMB" },
				{ Name = "Keyboard", KeyCode = Enum.KeyCode.F },
				{ Name = "Gamepad", KeyCode = Enum.KeyCode.ButtonL2 },
				{ Name = "TouchFeed", Scriptable = true, DisplayName = "TAP" },
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
