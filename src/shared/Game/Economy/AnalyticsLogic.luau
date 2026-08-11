--!strict

-- Pure analytics routing and onboarding progression decisions.

local AnalyticsLogic = {}

export type OnboardingKind = "Joined" | "FirstSpawn" | "MatchStarted" | "MatchEnded"

export type OnboardingProgress = {
	spawned: boolean,
	matchStarted: boolean,
	matchEnded: boolean,
}

local ONBOARDING_STEPS: { [OnboardingKind]: { step: number, name: string } } = {
	Joined = { step = 1, name = "Joined" },
	FirstSpawn = { step = 2, name = "FirstSpawn" },
	MatchStarted = { step = 3, name = "FirstMatchStarted" },
	MatchEnded = { step = 4, name = "FirstMatchCompleted" },
}

function AnalyticsLogic.onboardingStepFor(kind: OnboardingKind, progress: OnboardingProgress): (number?, string?)
	if kind == "Joined" then
		local entry = ONBOARDING_STEPS.Joined
		return entry.step, entry.name
	elseif kind == "FirstSpawn" then
		if progress.spawned then
			return nil, nil
		end
		local entry = ONBOARDING_STEPS.FirstSpawn
		return entry.step, entry.name
	elseif kind == "MatchStarted" then
		if progress.matchStarted then
			return nil, nil
		end
		local entry = ONBOARDING_STEPS.MatchStarted
		return entry.step, entry.name
	elseif kind == "MatchEnded" then
		if progress.matchEnded then
			return nil, nil
		end
		local entry = ONBOARDING_STEPS.MatchEnded
		return entry.step, entry.name
	end
	return nil, nil
end

function AnalyticsLogic.weaponTypeForElim(event: { [string]: any }): string
	return if event.projectileId ~= nil then "Dodgeball" else "Hammer"
end

export type UIEventPayload = {
	kind: string,
	menuId: string?,
	reason: string?,
	offerKey: string?,
	offerKind: string?,
}

export type UIRoute = {
	funnel: string?,
	step: number?,
	stepName: string?,
	customEventName: string?,
}

local SHOP_EVENTS = {
	ShopSectionViewed = "ShopSectionViewed",
	OfferSelected = "ShopOfferSelected",
	PromptOpened = "ShopPromptOpened",
	PromptClosed = "ShopPromptClosed",
	PurchaseFailed = "ShopPurchaseFailed",
}

function AnalyticsLogic.routeUIEvent(payload: UIEventPayload): UIRoute?
	if payload.kind == "MenuOpened" then
		if payload.menuId == nil then
			return nil
		end
		if payload.menuId == "Shop" then
			return { funnel = "ShopPurchase", step = 1, stepName = "Opened", customEventName = nil }
		end
		return { funnel = nil, step = nil, stepName = nil, customEventName = "MenuOpened" }
	end

	local customEventName = SHOP_EVENTS[payload.kind]
	if customEventName then
		return { funnel = nil, step = nil, stepName = nil, customEventName = customEventName }
	end
	return nil
end

return AnalyticsLogic
