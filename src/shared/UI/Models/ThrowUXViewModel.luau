-- Description: Pure derivation of the throw HUD state from charge, cooldown, and feedback inputs.

--!strict

local ThrowUXViewModel = {}

export type State =
	"Idle"
	| "Ready"
	| "Aiming"
	| "PendingInput"
	| "Charging"
	| "FullCharge"
	| "Release"
	| "Recovery"
	| "Cancelled"

export type Input = {
	weapon: string,
	holdsBall: boolean,
	combatState: string,
	chargeAlpha: number,
	throwCooldown: number,
	ready: boolean,
	pendingInput: boolean,
	releaseActive: boolean,
	cancelActive: boolean,
}

function ThrowUXViewModel.state(input: Input): State
	if input.cancelActive then
		return "Cancelled"
	end
	if input.releaseActive or input.combatState == "Throwing" or input.combatState == "FollowThrough" then
		return "Release"
	end
	if input.combatState == "Charging" then
		return if input.chargeAlpha >= 0.995 then "FullCharge" else "Charging"
	end
	if input.combatState == "Recovering" or input.throwCooldown > 0 then
		return "Recovery"
	end
	if input.pendingInput and input.weapon == "Dodgeball" and input.holdsBall then
		return "PendingInput"
	end
	if input.ready then
		return "Ready"
	end
	if input.weapon == "Dodgeball" and input.holdsBall then
		return "Aiming"
	end
	return "Idle"
end

function ThrowUXViewModel.cooldownAlpha(remaining: number, duration: number): number
	if duration <= 0 then
		return 0
	end
	return math.clamp(remaining / duration, 0, 1)
end

return table.freeze(ThrowUXViewModel)
