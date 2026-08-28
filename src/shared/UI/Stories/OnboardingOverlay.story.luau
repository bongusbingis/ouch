-- Name: OnboardingOverlay.story.luau
-- Author: Jack C.
-- Description: Studio story previewing the training overlay across every step and device class, so the prompt, skip, party choice, and completion card can be checked on phone and tablet viewports without running a session.
-- Created: 2026-08-27

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local OnboardingOverlay = require(script.Parent.Parent.Components.OnboardingOverlay)
local StoryRoot = require(script.Parent.StoryRoot)

local c = React.createElement

local STEPS = { "NormalThrow", "Hammer", "ChargedThrow", "Practice" }
local DEVICES = { "Mouse", "Touch", "Gamepad" }

local function Story()
	local stepIndex, setStepIndex = React.useState(1)
	local deviceIndex, setDeviceIndex = React.useState(1)
	local variant, setVariant = React.useState("Prompt")

	local snapshot = {
		route = "Training",
		stepId = STEPS[stepIndex],
		stepIndex = stepIndex,
		prompt = "",
		success = if variant == "Success" then "NICE!" else "",
		hint = if variant == "Escalated" then "Escalated" else "",
		deviceClass = DEVICES[deviceIndex],
		partyReady = variant == "PartyReady",
		celebrating = variant == "Celebration",
		revealed = false,
		swipeHint = variant == "SwipeHint",
		revision = 1,
	}

	local function control(text: string, order: number, onActivated: () -> ())
		return c("TextButton", {
			BackgroundColor3 = Color3.fromRGB(40, 38, 70),
			BorderSizePixel = 0,
			FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
			LayoutOrder = order,
			Size = UDim2.fromOffset(190, 30),
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 16,
			[React.Event.Activated] = onActivated,
		})
	end

	return c("ScreenGui", {
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Backdrop = c("Frame", {
			BackgroundColor3 = Color3.fromRGB(96, 176, 214),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}),
		Overlay = c(OnboardingOverlay, {
			Snapshot = snapshot,
			OnSkip = function()
				print("[story] skip")
			end,
			OnJoinPartyMatch = function()
				print("[story] join party match")
			end,
			OnKeepTraining = function()
				setVariant("Prompt")
			end,
		}),
		Controls = c("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.01, 0.99),
			Size = UDim2.fromOffset(190, 200),
			ZIndex = 200,
		}, {
			Layout = c("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
			Step = control(`STEP: {STEPS[stepIndex]}`, 1, function()
				setStepIndex(stepIndex % #STEPS + 1)
			end),
			Device = control(`DEVICE: {DEVICES[deviceIndex]}`, 2, function()
				setDeviceIndex(deviceIndex % #DEVICES + 1)
			end),
			Prompt = control("PROMPT", 3, function()
				setVariant("Prompt")
			end),
			Success = control("SUCCESS", 4, function()
				setVariant("Success")
			end),
			Escalated = control("ESCALATED HINT", 5, function()
				setVariant("Escalated")
			end),
			Swipe = control("SWIPE HINT", 6, function()
				setVariant("SwipeHint")
			end),
			Party = control("PARTY READY", 7, function()
				setVariant("PartyReady")
			end),
			Celebration = control("CELEBRATION", 8, function()
				setVariant("Celebration")
			end),
		}),
	})
end

return function(target: Instance): () -> ()
	return StoryRoot(target, c(Story))
end
