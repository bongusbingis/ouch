-- Name: AnalyticsLogic.spec.luau
-- Author: Jack C.
-- Description: Spec for the pure analytics routing rules: once-only onboarding advancement, weapon inference from eliminations, and which funnel or custom event each UI interaction becomes.
-- Created: 2026-07-22

--!strict

local T = require(script.Parent.TestKit)
local AnalyticsLogic = require(script.Parent.Parent.Game.Economy.AnalyticsLogic)

T.describe("AnalyticsLogic", function()
	T.it("advances Joined unconditionally", function()
		local step, name =
			AnalyticsLogic.onboardingStepFor("Joined", { spawned = false, matchStarted = false, matchEnded = false })
		T.expect(step):toEqual(1)
		T.expect(name):toEqual("Joined")
	end)

	T.it("advances FirstSpawn only once", function()
		local progress = { spawned = false, matchStarted = false, matchEnded = false }
		local step, name = AnalyticsLogic.onboardingStepFor("FirstSpawn", progress)
		T.expect(step):toEqual(2)
		T.expect(name):toEqual("FirstSpawn")

		progress.spawned = true
		local step2, name2 = AnalyticsLogic.onboardingStepFor("FirstSpawn", progress)
		T.expect(step2):toBeNil()
		T.expect(name2):toBeNil()
	end)

	T.it("advances MatchStarted and MatchEnded only once each", function()
		local progress = { spawned = true, matchStarted = false, matchEnded = false }
		local startedStep = AnalyticsLogic.onboardingStepFor("MatchStarted", progress)
		T.expect(startedStep):toEqual(3)
		progress.matchStarted = true
		local repeatStep = AnalyticsLogic.onboardingStepFor("MatchStarted", progress)
		T.expect(repeatStep):toBeNil()

		local endedStep = AnalyticsLogic.onboardingStepFor("MatchEnded", progress)
		T.expect(endedStep):toEqual(4)
		progress.matchEnded = true
		local repeatEndedStep = AnalyticsLogic.onboardingStepFor("MatchEnded", progress)
		T.expect(repeatEndedStep):toBeNil()
	end)

	T.it("infers weapon type from projectileId presence", function()
		T.expect(AnalyticsLogic.weaponTypeForElim({ projectileId = "abc" })):toEqual("Dodgeball")
		T.expect(AnalyticsLogic.weaponTypeForElim({ projectileId = nil })):toEqual("Hammer")
	end)

	T.it("routes Shop menu opens to the ShopPurchase funnel", function()
		local route = AnalyticsLogic.routeUIEvent({ kind = "MenuOpened", menuId = "Shop" })
		T.expect(route ~= nil):toBeTruthy()
		if route then
			T.expect(route.funnel):toEqual("ShopPurchase")
			T.expect(route.step):toEqual(1)
			T.expect(route.stepName):toEqual("Opened")
		end
	end)

	T.it("routes other menu opens to a generic custom event", function()
		local route = AnalyticsLogic.routeUIEvent({ kind = "MenuOpened", menuId = "Quests" })
		T.expect(route ~= nil):toBeTruthy()
		if route then
			T.expect(route.funnel):toBeNil()
			T.expect(route.customEventName):toEqual("MenuOpened")
		end
	end)

	T.it("ignores unrelated payloads", function()
		local route = AnalyticsLogic.routeUIEvent({ kind = "Other" })
		T.expect(route):toBeNil()
	end)
	T.it("routes Shop interactions to named custom events", function()
		local selected = AnalyticsLogic.routeUIEvent({ kind = "OfferSelected", offerKey = "Bonks500" })
		T.expect(selected ~= nil):toBeTruthy()
		if selected then
			T.expect(selected.customEventName):toEqual("ShopOfferSelected")
		end
		local failed = AnalyticsLogic.routeUIEvent({ kind = "PurchaseFailed", offerKey = "Bonks500" })
		T.expect(failed ~= nil):toBeTruthy()
		if failed then
			T.expect(failed.customEventName):toEqual("ShopPurchaseFailed")
		end
	end)
end)

return true
