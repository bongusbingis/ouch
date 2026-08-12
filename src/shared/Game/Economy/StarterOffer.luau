--!strict

-- Pure eligibility rules for the one-time starter offer.
--
-- The offer grants nothing on its own -- it only decides whether to merchandise
-- an ordinary game pass more prominently -- so it is safe for the client to
-- evaluate. The purchase itself still goes through the normal server-verified
-- game-pass flow.
--
-- The window is real: once it elapses the offer genuinely stops being shown.
-- Nothing here manufactures scarcity that does not exist.

local StarterOffer = {}

export type Config = {
	PassKey: string,
	WindowSeconds: number,
}

export type State = {
	active: boolean,
	expiresAt: number,
	secondsRemaining: number,
}

local INACTIVE: State = { active = false, expiresAt = 0, secondsRemaining = 0 }

-- A player counts as converted the moment they own anything or hold any
-- receipt; the offer is for first purchases only.
function StarterOffer.hasPurchased(receipts: { [string]: any }?, ownsAnyPass: boolean): boolean
	if ownsAnyPass then
		return true
	end
	return receipts ~= nil and next(receipts) ~= nil
end

function StarterOffer.evaluate(config: Config, firstJoinAt: number?, now: number, hasPurchased: boolean): State
	if hasPurchased or firstJoinAt == nil or firstJoinAt <= 0 then
		return INACTIVE
	end
	local expiresAt = firstJoinAt + config.WindowSeconds
	local remaining = expiresAt - now
	if remaining <= 0 then
		return INACTIVE
	end
	return { active = true, expiresAt = expiresAt, secondsRemaining = remaining }
end

function StarterOffer.formatRemaining(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local days = total // 86400
	local hours = (total % 86400) // 3600
	local minutes = (total % 3600) // 60
	if days > 0 then
		return `{days}d {hours}h`
	end
	if hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m`
end

return StarterOffer
