--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Models"):WaitForChild("ResponsiveLayout")
)
local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))

return function()
	describe("Shipped landscape layout budgets", function()
		it("retains two readable inventory cards while giving the phone character room beside the panel", function()
			for _, size in
				{ Vector2.new(568, 262), Vector2.new(666, 316), Vector2.new(750, 303), Vector2.new(851, 334) }
			do
				local composition = Layout.inventoryComposition(size, Config.Layout)
				local inventory = Config.Layout.Inventory
				local contentWidth = composition.panel.size.X
					- inventory.ShortContentLeftPx
					- inventory.ShortContentBottomPx
				local cardWidth = (contentWidth - Config.Layout.InventoryContentGapPx * 2) * 0.955
				local columns, cardSize = Layout.gridCellSize(
					cardWidth,
					inventory.ShortCardMinPx,
					inventory.ShortCardSizePx,
					inventory.CardGapPx,
					inventory.MaxColumns
				)
				expect(columns >= 2 and cardSize >= inventory.ShortCardMinPx).to.equal(true)
				expect(composition.world.size.X >= inventory.ShortWorldMinWidthPx).to.equal(true)
				if size.X >= 666 then
					expect(composition.world.size.X >= size.X * 0.375).to.equal(true)
				end
			end
		end)

		it("keeps inventory dimensions positive before the viewport has rendered", function()
			for _, size in { Vector2.zero, Vector2.one, Vector2.new(2, 1), Vector2.new(16, 8), Vector2.new(666, 1) } do
				local composition = Layout.inventoryComposition(size, Config.Layout)
				for _, rectangle in { composition.panel, composition.world } do
					expect(rectangle.size.X >= 1 and rectangle.size.Y >= 1).to.equal(true)
				end
			end
		end)
		it("keeps the inventory and world preview disjoint across supported landscape sizes", function()
			for _, size in
				{
					Vector2.new(568, 262),
					Vector2.new(666, 316),
					Vector2.new(750, 303),
					Vector2.new(1024, 710),
					Vector2.new(1366, 710),
					Vector2.new(1920, 1022),
				}
			do
				local composition = Layout.inventoryComposition(size, Config.Layout)
				local panel, world = composition.panel, composition.world
				expect(panel.position.X >= 0 and panel.position.Y >= 0).to.equal(true)
				expect(world.position.X >= panel.position.X + panel.size.X + 8).to.equal(true)
				expect(world.position.X + world.size.X <= size.X).to.equal(true)
				expect(world.position.Y + world.size.Y <= size.Y).to.equal(true)
				expect(world.size.X >= 170 and world.size.Y >= 160).to.equal(true)
			end
		end)
		it("reserves a party window beside the phone progress stack and above actions", function()
			for _, size in { Vector2.new(568, 262), Vector2.new(666, 316), Vector2.new(750, 303) } do
				local world = Layout.splashWorldWindow(size, Config.Layout)
				local panels = Layout.splashPanels(
					size,
					Config.Layout.Splash.ProgressPanels,
					Config.Layout.PortraitMaxAspect,
					Config.Layout.ShortLandscapeMaxHeightPx
				)
				local stack = assert(panels.progressStack)
				expect(world.position.X + world.size.X < stack.position.X).to.equal(true)
				expect(world.position.Y >= Config.Layout.TopBar.ShortHeightPx).to.equal(true)
				expect(
					world.position.Y + world.size.Y
						<= size.Y
							- Config.Layout.Splash.ShortActionsHeightPx
							- Config.Layout.Splash.ShortActionsBottomPx
				).to.equal(true)
				expect(world.size.X >= 320 and world.size.Y >= 80).to.equal(true)
			end
		end)
		it("frames the desktop party in a tall column between the daily and progression cards", function()
			for _, size in
				{
					Vector2.new(820, 501),
					Vector2.new(1158, 520),
					Vector2.new(1158, 725),
					Vector2.new(1158, 1100),
					Vector2.new(1366, 709),
					Vector2.new(1920, 1022),
				}
			do
				local world = Layout.splashWorldWindow(size, Config.Layout)
				local panels = Layout.splashPanels(
					size,
					Config.Layout.Splash.ProgressPanels,
					Config.Layout.PortraitMaxAspect,
					Config.Layout.ShortLandscapeMaxHeightPx
				)
				local gap = Config.Layout.Splash.ProgressPanels.GapPx
				expect(world.position.X >= panels.daily.position.X + panels.daily.size.X + gap).to.equal(true)
				for _, panel in { panels.season, panels.quests } do
					expect(world.position.X + world.size.X <= panel.position.X - gap).to.equal(true)
				end
				expect(world.position.Y >= 0 and world.position.Y + world.size.Y <= size.Y - gap).to.equal(true)
				expect(world.position.X >= 0 and world.position.X + world.size.X <= size.X).to.equal(true)
				expect(world.size.X >= 200 and world.size.Y >= size.Y * 0.7).to.equal(true)
			end
		end)
		it("keeps the short progression viewport clear of actions while exposing the next section", function()
			for _, size in { Vector2.new(666, 258), Vector2.new(666, 316), Vector2.new(750, 303) } do
				local config = Config.Layout.Splash.ProgressPanels
				local panels = Layout.splashPanels(
					size,
					config,
					Config.Layout.PortraitMaxAspect,
					Config.Layout.ShortLandscapeMaxHeightPx
				)
				local stack = assert(panels.progressStack)
				expect(stack.position.Y + stack.size.Y <= size.Y - config.Landscape.ShortBottomPx).to.equal(true)
				expect(stack.size.Y >= panels.season.size.Y + config.GapPx * 1.5 + 36).to.equal(true)
				expect(panels.season.size.Y >= Config.Interaction.MinTargetPx).to.equal(true)
				expect(Config.Layout.QuestRow.CompactHeightPx >= Config.Interaction.MinTargetPx + 82).to.equal(true)
			end
		end)
		it("keeps progression panels clear of the desktop action stack and its spacing", function()
			for _, size in
				{ Vector2.new(820, 501), Vector2.new(1158, 520), Vector2.new(1158, 725), Vector2.new(1920, 1080) }
			do
				local panels = Layout.splashPanels(
					size,
					Config.Layout.Splash.ProgressPanels,
					Config.Layout.PortraitMaxAspect,
					Config.Layout.ShortLandscapeMaxHeightPx
				)
				local limit = size.Y - Config.Layout.Splash.ProgressPanels.Landscape.ActionsReservePx
				expect(panels.quests.position.Y + panels.quests.size.Y <= limit).to.equal(true)
				expect(
					panels.quests.position.Y
						>= panels.season.position.Y
							+ panels.season.size.Y
							+ Config.Layout.Splash.ProgressPanels.GapPx
				).to.equal(true)
				expect(panels.quests.size.Y >= Config.Interaction.MinTargetPx).to.equal(true)
			end
		end)

		it("reserves the action row and readable season XP beside Claim on short phones", function()
			for _, size in
				{ Vector2.new(750, 303), Vector2.new(666, 258), Vector2.new(820, 499), Vector2.new(820, 500) }
			do
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
				expect(Config.Layout.SeasonCompactClaimWidthPx >= Config.Interaction.MinTargetPx).to.equal(true)
			end
		end)
	end)
end
