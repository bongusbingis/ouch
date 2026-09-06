--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.Shared.UI.Models.ResponsiveLayout)
local Config = require(ReplicatedStorage.Config.Interface.UI)

return function()
	describe("Shipped landscape layout budgets", function()
		it("reserves the action row and readable season XP beside Claim on short phones", function()
			for _, size in { Vector2.new(750, 303), Vector2.new(666, 258) } do
				local panels = Layout.splashPanels(
					size,
					Config.Layout.Splash.ProgressPanels,
					Config.Layout.PortraitMaxAspect,
					Config.Layout.ShortLandscapeMaxHeightPx
				)
				local limit = size.Y - Config.Layout.Splash.ProgressPanels.Landscape.ShortBottomPx
				expect(panels.daily.position.Y + panels.daily.size.Y <= limit).to.equal(true)
				expect(panels.quests.position.Y + panels.quests.size.Y <= limit).to.equal(true)
				local infoWidth = (panels.season.size.X - 20) * 0.75
					- Config.Layout.SeasonCompactClaimWidthPx
					- Config.Layout.InventoryContentGapPx
				expect(infoWidth >= 54).to.equal(true)
			end
		end)
	end)
end
