-- Name: OnboardingApp.luau
-- Author: Jack C.
-- Description: React roots for the first-session training UI: the chrome, which respects the device's safe area, and the input indicator, which must not, because it is drawn in the same pixel space the touch classifier reads.
-- Created: 2026-08-27

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local SharedUI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local OnboardingGestureLayer = require(SharedUI:WaitForChild("Components"):WaitForChild("OnboardingGestureLayer"))
local OnboardingOverlay = require(SharedUI:WaitForChild("Components"):WaitForChild("OnboardingOverlay"))
local useExternalStore = require(SharedUI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))

local OnboardingClient = require(
	Players.LocalPlayer
		:WaitForChild("PlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Modules")
		:WaitForChild("Onboarding")
		:WaitForChild("OnboardingClient")
)

local c = React.createElement

export type Props = {
	OnPresented: (() -> ())?,
}

local OnboardingApp = {}

-- The chrome: panel, skip, party choice, completion card. Mounted in a
-- safe-area root so nothing lands under a notch or the platform topbar.
function OnboardingApp.Chrome(props: Props)
	local snapshot = useExternalStore(OnboardingClient.getSnapshot, OnboardingClient.subscribe)
	local presented = React.useRef(false)

	React.useEffect(function()
		if not presented.current and props.OnPresented then
			presented.current = true
			props.OnPresented()
		end
	end, { props.OnPresented })

	return c(OnboardingOverlay, {
		Snapshot = snapshot,
		OnSkip = OnboardingClient.skip,
		OnJoinPartyMatch = OnboardingClient.joinPartyMatch,
		OnKeepTraining = OnboardingClient.keepTraining,
	})
end

-- The input indicator, mounted uninset so its pixel positions are the same
-- coordinates the touch classifier decides taps, holds and swipes in.
function OnboardingApp.Gestures()
	local snapshot = useExternalStore(OnboardingClient.getSnapshot, OnboardingClient.subscribe)
	return c(OnboardingGestureLayer, { Snapshot = snapshot })
end

return OnboardingApp
