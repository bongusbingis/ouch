-- Description: Pure eligibility rules for the one-time starter offer window, deciding only whether an ordinary game pass is merchandised more prominently.

--!strict

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

export type Resolved = {
	passKey: string,
	expiresAt: number,
	secondsRemaining: number,
}

export type Context = {
	-- False while pass ownership is still being fetched. The offer stays hidden
	-- until it is known: dangling a first-purchase offer at someone who already
	-- bought one reads as a mistake, and the storefront refetches on open.
	ready: boolean,
	ownsPass: boolean,
	ownsAnyPass: boolean,
	receipts: { [string]: any }?,
	firstJoinAt: number?,
	now: number,
}

-- The whole merchandising decision in one pure place, so the server gathers
-- inputs and never re-derives eligibility, and the storefront never decides it.
function StarterOffer.resolve(config: Config, pass: any?, context: Context): Resolved?
	if pass == nil or pass.CatalogStatus ~= "Active" or pass.Id == nil then
		return nil
	end
	if not context.ready or context.ownsPass then
		return nil
	end
	local purchased = StarterOffer.hasPurchased(context.receipts, context.ownsAnyPass)
	local state = StarterOffer.evaluate(config, context.firstJoinAt, context.now, purchased)
	if not state.active then
		return nil
	end
	return {
		passKey = config.PassKey,
		expiresAt = state.expiresAt,
		secondsRemaining = state.secondsRemaining,
	}
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
