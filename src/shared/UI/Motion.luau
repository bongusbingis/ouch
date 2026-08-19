--!strict

return table.freeze({
	Page = table.freeze({ mass = 1, tension = 2500, friction = 100 }),
	Camera = table.freeze({ mass = 1, tension = 170, friction = 26 }),
	Control = table.freeze({ mass = 1, tension = 1500, friction = 35 }),
	Modal = table.freeze({ mass = 1, tension = 700, friction = 45 }),
	Controls = table.freeze({
		Standard = table.freeze({ hover = 1.055, pressed = 0.93, rotation = -1 }),
		Primary = table.freeze({ hover = 1.035, pressed = 0.95, rotation = -0.5 }),
		Card = table.freeze({ hover = 1.04, pressed = 0.94, rotation = -0.75 }),
	}),
})
