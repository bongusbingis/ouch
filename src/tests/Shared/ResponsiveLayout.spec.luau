--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Models"):WaitForChild("ResponsiveLayout")
)
local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))

return function()
	describe("Shipped landscape layout budgets", function()
		it("fits phone category targets and readable reward content using the shipped configuration", function()
			for _, size in { Vector2.new(750, 304), Vector2.new(600, 302) } do
				local panels = Layout.splashPanels(size, Config.Layout.Splash.ProgressPanels, 1, 500)
				local stack = assert(panels.progressStack)
				local world = Layout.splashWorldWindow(size, Config.Layout)
				expect(panels.tabbed).to.equal(true)
				expect(
					(stack.size.X - Config.Layout.Splash.ProgressPanels.GapPx * 2) / 3 - 6
						>= Config.Interaction.MinTargetPx
				).to.equal(true)
				expect(stack.size.Y - 44 - 12 >= Config.Layout.Splash.ProgressPanels.DailyMinHeightPx).to.equal(true)
				expect(stack.size.Y - 44 - 12 >= Config.Layout.QuestRow.CompactHeightPx).to.equal(true)
				expect(world.position.X + world.size.X < stack.position.X).to.equal(true)
				expect(stack.position.Y + stack.size.Y).to.equal(size.Y - 12)
			end
		end)
		it("keeps intermediate cards visible until the full desktop card column can fit", function()
			local config = Config.Layout.Splash.ProgressPanels
			local intermediate = Layout.splashPanels(Vector2.new(1158, 719), config, 1, 500)
			local stack = assert(intermediate.progressStack)
			expect(intermediate.tabbed).to.equal(false)
			expect(stack.position.Y + stack.size.Y).to.equal(719 - config.Landscape.ShortBottomPx)
			local desktop = Layout.splashPanels(Vector2.new(1158, 841), config, 1, 500)
			expect(desktop.progressStack == nil).to.equal(true)
			expect(desktop.daily.size.Y >= 140).to.equal(true)
			expect(desktop.quests.size.Y >= config.Landscape.QuestsMinHeightPx).to.equal(true)
			expect(desktop.quests.position.Y + desktop.quests.size.Y <= 841 - config.Landscape.ActionsReservePx).to.equal(
				true
			)
		end)
		it("fits season daily and quest cards together in a roomier intermediate column", function()
			local config = Config.Layout.Splash.ProgressPanels
			for _, size in { Vector2.new(1158, 600), Vector2.new(1158, 662), Vector2.new(1158, 719) } do
				local panels = Layout.splashPanels(size, config, 1, 500)
				local stack = assert(panels.progressStack)
				expect(panels.tabbed).to.equal(false)
				expect(stack.position.Y + stack.size.Y).to.equal(size.Y - config.Landscape.ShortBottomPx)
				local questContentBudget = stack.size.Y
					- panels.season.size.Y
					- panels.daily.size.Y
					- config.GapPx * 3.5
				expect(panels.season.size.Y >= 88).to.equal(true)
				expect(panels.daily.size.Y >= config.DailyMinHeightPx).to.equal(true)
				expect(questContentBudget >= config.Landscape.QuestsMinHeightPx).to.equal(true)
				local world = Layout.splashWorldWindow(size, Config.Layout)
				expect(world.position.X + world.size.X < stack.position.X).to.equal(true)
			end
		end)
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
				-- The 568px phone gives its widened category column 215px, leaving
				-- a 306px stage: retain a majority of the usable width for the party.
				expect(world.size.X >= size.X * 0.5 and world.size.Y >= 80).to.equal(true)
				if size.X >= 600 then
					expect(world.size.X >= 320).to.equal(true)
				end
			end
		end)
		it("gives the desktop party the left composition beside one progression column", function()
			for _, size in
				{
					Vector2.new(820, 725),
					Vector2.new(1158, 725),
					Vector2.new(1024, 841),
					Vector2.new(1152, 841),
					Vector2.new(1158, 1100),
					Vector2.new(1366, 841),
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
				expect(panels.progressStack == nil).to.equal(true)
				for _, panel in { panels.season, panels.daily, panels.quests } do
					expect(world.position.X + world.size.X <= panel.position.X - gap).to.equal(true)
					expect(panel.position.X == panels.season.position.X).to.equal(true)
					expect(panel.size.X == panels.season.size.X).to.equal(true)
				end
				expect(world.position.Y >= 0 and world.position.Y + world.size.Y <= size.Y - gap).to.equal(true)
				expect(world.position.X >= 0 and world.position.X + world.size.X <= size.X).to.equal(true)
				expect(world.size.X >= size.X * 0.6 and world.size.Y >= size.Y * 0.6).to.equal(true)
				expect(panels.daily.position.Y >= panels.season.position.Y + panels.season.size.Y + gap).to.equal(true)
				expect(panels.quests.position.Y >= panels.daily.position.Y + panels.daily.size.Y + gap).to.equal(true)
				expect(panels.quests.size.Y >= Config.Layout.Splash.ProgressPanels.Landscape.QuestsMinHeightPx).to.equal(
					true
				)
			end
		end)
		it("uses the home fallback composition before fixed cards would collide with actions", function()
			for _, size in { Vector2.new(820, 501), Vector2.new(1158, 520), Vector2.new(1246, 691) } do
				local panels = Layout.splashPanels(
					size,
					Config.Layout.Splash.ProgressPanels,
					Config.Layout.PortraitMaxAspect,
					Config.Layout.ShortLandscapeMaxHeightPx
				)
				local stack = assert(panels.progressStack)
				local world = Layout.splashWorldWindow(size, Config.Layout)
				expect(world.position.X + world.size.X < stack.position.X).to.equal(true)
				expect(stack.position.Y + stack.size.Y).to.equal(size.Y - (if panels.tabbed then 12 else 78))
				expect(panels.tabbed).to.equal(size.Y <= 520)
				expect(world.position.Y + world.size.Y <= size.Y - 70).to.equal(true)
			end
		end)
		it("keeps phone category controls usable while their column extends beside actions", function()
			for _, size in { Vector2.new(666, 258), Vector2.new(666, 316), Vector2.new(750, 303) } do
				local config = Config.Layout.Splash.ProgressPanels
				local panels = Layout.splashPanels(
					size,
					config,
					Config.Layout.PortraitMaxAspect,
					Config.Layout.ShortLandscapeMaxHeightPx
				)
				local stack = assert(panels.progressStack)
				expect(panels.tabbed).to.equal(true)
				expect(stack.position.Y + stack.size.Y).to.equal(size.Y - 12)
				local actionsTop = size.Y
					- Config.Layout.Splash.ShortActionsHeightPx
					- Config.Layout.Splash.ShortActionsBottomPx
				local world = Layout.splashWorldWindow(size, Config.Layout)
				expect(world.position.X + world.size.X < stack.position.X).to.equal(true)
				expect(world.position.Y + world.size.Y <= actionsTop).to.equal(true)
				expect(stack.size.Y - 44 - 12 >= Config.Interaction.MinTargetPx).to.equal(true)
				expect(panels.season.size.Y >= Config.Interaction.MinTargetPx).to.equal(true)
				expect(Config.Layout.QuestRow.CompactHeightPx >= Config.Interaction.MinTargetPx + 82).to.equal(true)
			end
		end)
		it("keeps progression panels clear of the desktop action stack and its spacing", function()
			for _, size in
				{
					Vector2.new(820, 725),
					Vector2.new(1158, 725),
					Vector2.new(1024, 841),
					Vector2.new(1152, 841),
					Vector2.new(1920, 1080),
				}
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
		it("keeps desktop Play prominent while reserving the party preview above its dock", function()
			local actions = Config.Layout.Splash
			local dockHeight = actions.DesktopStatusHeightPx
				+ actions.ActionHeightPx * 2
				+ actions.DesktopPrimaryActionHeightPx
				+ actions.ActionsGapPx * 3
			expect(actions.DesktopPrimaryActionHeightPx > actions.PrimaryActionHeightPx).to.equal(true)
			expect(actions.DesktopPrimaryActionTextPx > actions.PrimaryActionTextPx).to.equal(true)
			for _, size in { Vector2.new(1152, 783), Vector2.new(1366, 710), Vector2.new(1366, 768) } do
				local panels = Layout.splashPanels(size, actions.ProgressPanels, 1, 500)
				local stack = assert(panels.progressStack)
				local world = Layout.splashWorldWindow(size, Config.Layout)
				expect(stack.size.X - actions.ProgressPanels.GapPx * 2 >= 360).to.equal(true)
				expect(world.position.X + world.size.X < stack.position.X).to.equal(true)
				expect(world.position.Y + world.size.Y + 12 <= size.Y - 24 - dockHeight).to.equal(true)
				expect(world.size.X >= 500 and world.size.Y >= 250).to.equal(true)
			end
		end)

		it("retains readable season XP beside Claim inside the phone category column", function()
			for _, size in
				{
					Vector2.new(600, 302),
					Vector2.new(750, 303),
					Vector2.new(666, 258),
					Vector2.new(820, 499),
					Vector2.new(820, 500),
				}
			do
				local panels = Layout.splashPanels(
					size,
					Config.Layout.Splash.ProgressPanels,
					Config.Layout.PortraitMaxAspect,
					Config.Layout.ShortLandscapeMaxHeightPx
				)
				local limit = size.Y - 12
				local stack = assert(panels.progressStack)
				expect(stack.position.Y + stack.size.Y <= limit).to.equal(true)
				local cardWidth = stack.size.X - Config.Layout.Splash.ProgressPanels.GapPx * 2
				local infoWidth = (cardWidth - 20) * 0.75
					- Config.Layout.SeasonCompactClaimWidthPx
					- Config.Layout.InventoryContentGapPx
				expect(infoWidth >= 54).to.equal(true)
				expect(Config.Layout.SeasonCompactClaimWidthPx >= Config.Interaction.MinTargetPx).to.equal(true)
			end
		end)
	end)
end
