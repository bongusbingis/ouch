-- Name: OnboardingRuntime.spec.luau
-- Author: Jack C.
-- Description: In-place spec for the parts of onboarding that only exist inside a running lobby: its remotes, the Studio-authored assets the training world clones, and the services that must be present for a session to run.
-- Created: 2026-08-27

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EXPECTED_REMOTES = {
	OnboardingAction = "RemoteFunction",
	OnboardingEvent = "RemoteEvent",
	SubmitCombatInput = "RemoteEvent",
	SubmitWeaponEquip = "RemoteEvent",
	CombatSimEvent = "UnreliableRemoteEvent",
}

return function()
	describe("Onboarding remotes", function()
		it("materializes the onboarding and combat remotes the lobby now needs", function()
			local folder = ReplicatedStorage:WaitForChild("Remotes", 5)
			expect(folder).to.be.ok()
			for name, className in EXPECTED_REMOTES do
				local remote = (folder :: Folder):FindFirstChild(name)
				expect(remote).to.be.ok()
				expect((remote :: Instance):IsA(className)).to.equal(true)
			end
		end)
	end)

	describe("Onboarding world assets", function()
		it("has the Studio-authored rig the training dummies are cloned from", function()
			local assets = ReplicatedStorage:WaitForChild("Assets", 5)
			local rig = assets:WaitForChild("Rigs", 5):WaitForChild("CharacterRig", 5)
			expect(rig:IsA("Model")).to.equal(true)
			expect(rig:FindFirstChildOfClass("Humanoid")).to.be.ok()
			expect(rig:FindFirstChild("HumanoidRootPart")).to.be.ok()
		end)

		it("has the ball the training session hands the player", function()
			local templates = ReplicatedStorage:WaitForChild("Assets", 5):WaitForChild("Cosmetics", 5)
			expect(templates:WaitForChild("Templates", 5):FindFirstChild("DodgeballBase")).to.be.ok()
		end)
	end)

	describe("Onboarding services", function()
		it("starts the combat simulation in the lobby", function()
			local modules = ServerScriptService:WaitForChild("Server", 5):WaitForChild("Modules", 5)
			local onboarding = modules:WaitForChild("Onboarding", 5)
			expect(onboarding:FindFirstChild("OnboardingService")).to.be.ok()
			expect(onboarding:FindFirstChild("OnboardingWorld")).to.be.ok()
			expect(onboarding:FindFirstChild("TrainingDummies")).to.be.ok()
			expect(modules:FindFirstChild("BallService")).to.be.ok()
			expect(modules:FindFirstChild("InputSetup")).to.be.ok()
		end)

		it("keeps the balls folder the simulation encodes its state into", function()
			expect(workspace:WaitForChild("Balls", 10)).to.be.ok()
		end)
	end)
end
