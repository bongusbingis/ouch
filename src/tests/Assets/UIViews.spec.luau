--!nonstrict
-- Validates the Studio-authored UI infrastructure against what the client
-- modules WaitForChild on: the MainGui/BaseClip/Views container and its
-- Studio-authored Quests reference, the Hud sidebar and top bar, and the
-- element templates in ReplicatedStorage.Assets.UI. Other menu views use
-- authored-first runtime fallbacks while Studio access is unavailable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local MenuRegistry = require(Client:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("MenuRegistry"))
local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))

return function()
	describe("UI view assets", function()
		it("authors the MainGui BaseClip Views container", function()
			TestAssets.get(StarterGui, "MainGui", "BaseClip", "Views")
		end)

		it("authors the Quests reference CanvasGroup", function()
			local views = TestAssets.get(StarterGui, "MainGui", "BaseClip", "Views")
			local view = TestAssets.get(views, MenuRegistry.Quests.viewName)
			expect(view:IsA("CanvasGroup")).to.equal(true)
		end)

		it("authors the Hud sidebar and top bar", function()
			local side = TestAssets.get(StarterGui, "Hud", "Side")
			expect(side:IsA("Frame")).to.equal(true)
			TestAssets.get(StarterGui, "Hud", "Top")
		end)
	end)

	describe("UI template assets", function()
		it("authors the sidebar ButtonTemplate with its Label", function()
			local template = TestAssets.get(ReplicatedStorage, "Assets", "UI", "Templates", "ButtonTemplate")
			expect(template:IsA("ImageButton")).to.equal(true)
			local label = TestAssets.get(template, "Label")
			expect(label:IsA("TextLabel")).to.equal(true)
		end)

		it("authors the QuestCard template with the structure QuestCardElement needs", function()
			local template = TestAssets.get(ReplicatedStorage, "Assets", "UI", "Templates", "QuestCard")
			expect(template:IsA("GuiObject")).to.equal(true)

			for _, labelName in { "Title", "Count", "Rewards" } do
				local label = TestAssets.get(template, labelName)
				expect(label:IsA("TextLabel")).to.equal(true)
			end

			local progress = TestAssets.get(template, "Progress")
			expect(progress:IsA("GuiObject")).to.equal(true)
			local gradient = TestAssets.get(progress, "UIGradient")
			expect(gradient:IsA("UIGradient")).to.equal(true)

			local dividers = 0
			for _, child in progress:GetChildren() do
				if child:IsA("Frame") then
					dividers += 1
				end
			end
			expect(dividers > 0).to.equal(true)
		end)
	end)
end
