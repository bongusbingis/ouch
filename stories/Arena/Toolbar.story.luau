--[[
    The combat dock (CombatToolbar): the Dodgeball and Hammer slots at the bottom of the arena HUD,
    built through the real CombatToolbarViewModel.fromSnapshot exactly as the combat client does.

    Why: the dock's look depends on the weapon held, the ball, the hammer lock, both cooldowns and
    the throw charge, and its key hints change per input device. Every one of the old story's ten
    scenarios is kept, on each device, so 30 combinations -- too many full-screen frames to read
    side by side, so this is a Switch (pick a chip).

    States (scenario × Mouse / Gamepad / Touch)
      DODGEBALL SELECTED, HAMMER SELECTED, HAMMER LOCKED, HAMMER UNLOCK (locked, then after 0.65 s
      the unlock lands and the hammer is equipped -- REPLAY re-runs it), BOTH AVAILABLE, NO BALL,
      DODGEBALL COOLDOWN (55%), HAMMER COOLDOWN (60%), DODGEBALL CHARGING (65%), DODGEBALL FULL
      CHARGE.

    Tapping a slot equips it (local state). The dock lays out from the live viewport
    (useViewportSize / useArenaHUDLayout), so the frames are Screen frames. The ball and hammer
    previews show the default items (no save in a story).
]]

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local T = StoryRoot.Tokens
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))
local CombatToolbar = require(StoryRoot.Components:WaitForChild("CombatToolbar"))
local CombatToolbarViewModel = require(StoryRoot.Models:WaitForChild("CombatToolbarViewModel"))

local c = React.createElement

type Scenario = {
	name: string,
	weapon: string,
	holdsBall: boolean,
	weaponLocked: boolean?,
	transition: boolean?,
	throwCooldown: number?,
	hammerCooldown: number?,
	throwState: string?,
	chargeAlpha: number?,
}

local DEVICES = { "Mouse", "Gamepad", "Touch" }
local SCENARIOS: { Scenario } = {
	{ name = "DODGEBALL SELECTED", weapon = "Dodgeball", holdsBall = true },
	{ name = "HAMMER SELECTED", weapon = "Hammer", holdsBall = true },
	{ name = "HAMMER LOCKED", weapon = "Dodgeball", holdsBall = true, weaponLocked = true },
	{ name = "HAMMER UNLOCK", weapon = "Dodgeball", holdsBall = true, weaponLocked = true, transition = true },
	{ name = "BOTH AVAILABLE", weapon = "Hammer", holdsBall = true },
	{ name = "NO BALL", weapon = "Hammer", holdsBall = false },
	{
		name = "DODGEBALL COOLDOWN",
		weapon = "Dodgeball",
		holdsBall = true,
		throwCooldown = Combat.Dodgeball.ThrowCooldown * 0.55,
	},
	{
		name = "HAMMER COOLDOWN",
		weapon = "Hammer",
		holdsBall = true,
		hammerCooldown = Combat.Hammer.Cooldown * 0.6,
	},
	{
		name = "DODGEBALL CHARGING",
		weapon = "Dodgeball",
		holdsBall = true,
		throwState = "Charging",
		chargeAlpha = 0.65,
	},
	{
		name = "DODGEBALL FULL CHARGE",
		weapon = "Dodgeball",
		holdsBall = true,
		throwState = "FullCharge",
		chargeAlpha = 1,
	},
}

local function Dock(props: { Scenario: Scenario, Device: string })
	local scenario = props.Scenario
	local replay, setReplay = React.useState(0)
	local transitioned, setTransitioned = React.useState(false)
	local weapon, setWeapon = React.useState(scenario.weapon)

	React.useEffect(function()
		setTransitioned(false)
		setWeapon(scenario.weapon)
		if not scenario.transition then
			return nil
		end
		local thread = task.delay(0.65, function()
			setTransitioned(true)
			setWeapon("Hammer")
		end)
		return function()
			task.cancel(thread)
		end
	end, { replay })

	local model = CombatToolbarViewModel.fromSnapshot(
		{
			active = true,
			weapon = weapon,
			holdsBall = if scenario.transition and transitioned then false else scenario.holdsBall,
			throwCooldown = scenario.throwCooldown or 0,
			hammerCooldown = scenario.hammerCooldown or 0,
			weaponLocked = scenario.weaponLocked == true and not transitioned,
			throwState = scenario.throwState or "Idle",
			chargeAlpha = scenario.chargeAlpha or 0,
		} :: any,
		props.Device
	)

	return c(React.Fragment, nil, {
		Dock = c(CombatToolbar, {
			Model = model,
			OnEquip = function(next: string)
				Fixtures.log("Toolbar", "equip")(next)
				setWeapon(next)
			end,
			RegisterExclusion = Fixtures.noop,
		}),
		Replay = if scenario.transition
			then c("TextButton", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = T.Colors.Yellow,
				Font = T.Type.Label,
				Position = UDim2.new(0.5, 0, 0, 24),
				Size = UDim2.fromOffset(180, 44),
				Text = "REPLAY UNLOCK",
				TextColor3 = T.Colors.Ink,
				TextSize = 18,
				ZIndex = 200,
				[React.Event.Activated] = function()
					setReplay(replay + 1)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Stroke = c("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = T.Colors.Ink,
					Thickness = 2,
				}),
			})
			else nil,
	})
end

local states: { StoryRoot.State } = {}
for _, scenario in SCENARIOS do
	for _, device in DEVICES do
		table.insert(states, {
			Name = `{scenario.name} · {device}`,
			Note = if scenario.transition then "Unlock lands after 0.65 s; REPLAY re-runs it" else nil,
			Screen = true,
			Element = c(Dock, { Scenario = scenario, Device = device }),
		})
	end
end

return StoryRoot.story({
	Title = "Combat Toolbar",
	Summary = "The Dodgeball / Hammer dock: 10 combat scenarios × Mouse, Gamepad and Touch (30), one at a time.",
	Mode = "Switch",
	States = states,
})
