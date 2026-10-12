--!strict
local T = require(script.Parent.TestKit)
local P = require(script.Parent.Parent.Game.Onboarding.OnboardingProgress)
local Config = require(script.Parent.Parent.Parent.Config.Interface.Onboarding).Course
local World = require(script.Parent.Parent.Parent.Config.Interface.Onboarding).World
local Model = require(script.Parent.Parent.UI.Models.OnboardingViewModel)
local State = require(script.Parent.Parent.Game.Onboarding.OnboardingState)

T.describe("Splashdown onboarding", function()
	T.it("requires a grounded arrival at the original arena waypoint", function()
		T.expect(P.atCheckpoint(Vector3.new(82, 4, 0), 82, true, Config)):toEqual(true)
		T.expect(P.atCheckpoint(Vector3.new(82, 4, 0), 82, false, Config)):toEqual(false)
		T.expect(P.atCheckpoint(Vector3.new(82, 4, 30), 82, true, Config)):toEqual(false)
		T.expect(P.atCheckpoint(Vector3.new(82, -3, 0), 82, true, Config)):toEqual(false)
		T.expect(P.atCheckpoint(Vector3.new(125, 4, 0), 82, true, Config)):toEqual(false)
	end)
	T.it("recovers falls and the existing elimination ring without confining the island", function()
		T.expect(P.isLost(Vector3.new(60, -61, 0), World)):toEqual(true)
		T.expect(P.isLost(Vector3.new(98, -3, 25), World)):toEqual(true)
		T.expect(P.isLost(Vector3.new(105, 4, 0), World)):toEqual(false)
		T.expect(P.isLost(Vector3.new(40, 4, 30), World)):toEqual(false)
	end)
	T.it("requires a nearby rising jump and keeps earned practice checkpoints", function()
		T.expect(P.jumpedAt(Vector3.new(110, 6, 0), 105, true, true)):toEqual(true)
		T.expect(P.jumpedAt(Vector3.new(160, 6, 0), 105, true, true)):toEqual(false)
		T.expect(P.jumpedAt(Vector3.new(110, 6, 0), 105, false, true)):toEqual(false)
		T.expect(P.jumpedAt(Vector3.new(110, 6, 0), 105, true, false)):toEqual(false)
		T.expect(P.needsJump(105, 125, 82)):toEqual(true)
		T.expect(P.needsJump(105, 82, 125)):toEqual(true)
		T.expect(P.needsJump(105, 125, 163)):toEqual(false)
	end)
	T.it("restarts unfinished legacy combat lessons without replaying terminal records", function()
		for _, checkpoint in { "Intro", "NormalThrow", "Hammer", "ChargedThrow", "Practice" } do
			local partial = State.normalize({ Status = "InProgress", Checkpoint = checkpoint, Version = 1 }, 2)
			T.expect(State.resumeStep(partial, true)):toEqual("Intro")
		end
		for _, status in { "CoreComplete", "Completed", "Skipped" } do
			local stored = State.normalize({ Status = status, Checkpoint = "ChargedThrow", Version = 1 }, 2)
			T.expect(State.isEligible(stored)):toEqual(false)
		end
	end)
	T.it("presents the correct movement controls and completed progress", function()
		T.expect(Model.build({ step = "JumpSweepers", deviceClass = "Touch" }).detail)
			:toEqual("Tap Jump as the spinning bar comes towards you.")
		T.expect(Model.build({ step = "TimeHammer", deviceClass = "Gamepad" }).skip):toEqual("SKIP")
		T.expect(Model.build({ step = "Celebration" }).done):toEqual(4)
		T.expect(Model.build({ step = "TimeHammer", retrying = true }).done):toEqual(2)
	end)
	T.it("keeps the card inside landscape, portrait and short safe widths", function()
		for _, size in { Vector2.new(1920, 1080), Vector2.new(874, 306), Vector2.new(360, 680), Vector2.new(1024, 420) } do
			local layout = Model.layout(size.X, size.Y)
			T.expect(layout.width + layout.edge * 2 <= size.X):toEqual(true)
			T.expect(layout.height + layout.edge < size.Y):toEqual(true)
		end
	end)
end)
return true
