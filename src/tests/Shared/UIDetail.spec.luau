-- Engine font measurement and authored stage contracts catch issues absent from the headless renderer.
--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Metrics = require(ReplicatedStorage.Shared.UI.TextMetrics)
local TestAssets = require(game.ServerStorage.Tests.Helpers.TestAssets)
local VictoryRig = require(ReplicatedStorage.Shared.UI.Services.VictoryRig)

return function()
	describe("UI detail contracts", function()
		it("fits the entire currency group in a compact price cell", function()
			for _, amount in { "500", "10,000", "999,999,999" } do
				for _, width in { 68, 120, 300 } do
					local size =
						Metrics.fittingIconTextSize(amount, Enum.Font.LuckiestGuy, Vector2.new(width, 30), 28, 5)
					local bounds = game:GetService("TextService")
						:GetTextSize(amount, size, Enum.Font.LuckiestGuy, Vector2.new(10000, 10000))
					expect(bounds.X + size + 5 <= width).to.equal(true)
					expect(bounds.Y <= 30).to.equal(true)
				end
			end
		end)
		it("provides three authored podiums with rank labels and avatar markers", function()
			local stage = TestAssets.get(ReplicatedStorage, "Assets", "UI", "ResultsStage")
			expect(stage:IsA("Model")).to.equal(true)
			expect(TestAssets.get(stage, "ConfettiPiece"):IsA("BasePart")).to.equal(true)
			for index = 1, 3 do
				local stand = TestAssets.get(stage, "Stands", "Stand" .. index)
				expect(TestAssets.get(stand, "Avatar"):IsA("BasePart")).to.equal(true)
				expect(TestAssets.get(stand, "Plaque", "Label", "Rank"):IsA("TextLabel")).to.equal(true)
			end
		end)
		it("poses shared emotes at a world origin without drifting the character", function()
			local world = Instance.new("Folder")
			world.Parent = workspace
			local display = VictoryRig.create(world)
			local style = VictoryRig.style("ShowtimeTwirl")
			display.pose(style, 0.6, false)
			local first = display.model.HumanoidRootPart.CFrame
			local origin = CFrame.new(20, 10000, 30)
			display.pose(style, 0.6, false, origin)
			local offset = display.model.HumanoidRootPart.Position - (origin * first).Position
			local _, size = display.model:GetBoundingBox()
			expect(size.Magnitude < 20).to.equal(true)
			display.destroy()
			world:Destroy()
			expect(offset.Magnitude < 0.001).to.equal(true)
		end)
	end)
end
