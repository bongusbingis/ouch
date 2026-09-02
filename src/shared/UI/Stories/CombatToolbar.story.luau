-- Name: CombatToolbar.story.luau
-- Author: Jack C.
-- Description: Studio story for cycling combat dock states and input-device presentations.
-- Created: 2026-08-28

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))
local CombatToolbar = require(script.Parent.Parent.Components.CombatToolbar)
local CombatToolbarViewModel = require(script.Parent.Parent.Models.CombatToolbarViewModel)
local StoryRoot = require(script.Parent.StoryRoot)

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

local function control(text: string, position: UDim2, size: UDim2, onActivated: () -> ()): any
	return c("TextButton", {
		BackgroundTransparency = 1,
		FontFace = Font.new(
			"rbxasset://fonts/families/HighwayGothic.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		),
		Position = position,
		Size = size,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 17,
		ZIndex = 102,
		[React.Event.Activated] = onActivated,
	})
end

local function Story()
	local scenarioIndex, setScenarioIndex = React.useState(1)
	local deviceIndex, setDeviceIndex = React.useState(1)
	local replay, setReplay = React.useState(0)
	local transitioned, setTransitioned = React.useState(false)
	local selectedWeapon, setSelectedWeapon = React.useState(SCENARIOS[1].weapon)
	local transitionRevision = React.useRef(0)
	local scenario = SCENARIOS[scenarioIndex]
	local deviceClass = DEVICES[deviceIndex]

	React.useEffect(function()
		transitionRevision.current += 1
		local revision = transitionRevision.current
		setTransitioned(false)
		setSelectedWeapon(scenario.weapon)
		if scenario.transition then
			task.delay(0.65, function()
				if transitionRevision.current == revision then
					setTransitioned(true)
					setSelectedWeapon("Hammer")
				end
			end)
		end
		return function()
			transitionRevision.current += 1
		end
	end, { scenarioIndex, replay })

	local snapshot = {
		active = true,
		weapon = selectedWeapon,
		holdsBall = if scenario.transition and transitioned then false else scenario.holdsBall,
		throwCooldown = scenario.throwCooldown or 0,
		hammerCooldown = scenario.hammerCooldown or 0,
		weaponLocked = scenario.weaponLocked == true,
		throwState = scenario.throwState or "Idle",
		chargeAlpha = scenario.chargeAlpha or 0,
	}
	local model = CombatToolbarViewModel.fromSnapshot(snapshot, deviceClass)

	return c("ScreenGui", {
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Backdrop = c("Frame", {
			BackgroundColor3 = Color3.fromRGB(104, 197, 222),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, {
			Horizon = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(119, 139, 150),
				BackgroundTransparency = 0.22,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromScale(1, 0.34),
			}),
		}),
		Dock = c(CombatToolbar, {
			Model = model,
			OnEquip = setSelectedWeapon,
			RegisterExclusion = function() end,
		}),
		Toolbar = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(24, 41, 48),
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.02),
			Size = UDim2.new(0.7, 0, 0, 52),
			ZIndex = 100,
		}, {
			Bounds = c("UISizeConstraint", { MinSize = Vector2.new(320, 52), MaxSize = Vector2.new(900, 52) }),
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 14) }),
			Previous = control("<", UDim2.fromScale(0.01, 0), UDim2.fromScale(0.08, 1), function()
				setScenarioIndex(if scenarioIndex == 1 then #SCENARIOS else scenarioIndex - 1)
			end),
			Scenario = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.1, 0),
				Size = UDim2.fromScale(0.45, 1),
				Text = scenario.name,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 19,
				ZIndex = 101,
			}),
			Next = control(">", UDim2.fromScale(0.55, 0), UDim2.fromScale(0.08, 1), function()
				setScenarioIndex(scenarioIndex % #SCENARIOS + 1)
			end),
			Device = control(deviceClass, UDim2.fromScale(0.64, 0), UDim2.fromScale(0.18, 1), function()
				setDeviceIndex(deviceIndex % #DEVICES + 1)
			end),
			Replay = control("REPLAY", UDim2.fromScale(0.82, 0), UDim2.fromScale(0.17, 1), function()
				setReplay(replay + 1)
			end),
		}),
	})
end

return function(target: Instance)
	return StoryRoot(target, c(Story))
end
