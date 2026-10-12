--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Models"):WaitForChild("ResponsiveLayout")
)
local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))

-- Smallest viewport height at which the shipped config lets the season/daily/quest cards stand
-- alone (no stacked progression column) for a given width. Derived from the real layout so the
-- specs follow config changes instead of hardcoding the boundary.
local function desktopCardsMinHeight(width: number): number
	local config = Config.Layout.Splash.ProgressPanels
	for height = Config.Layout.ShortLandscapeMaxHeightPx + 1, 2400 do
		if
			Layout.splashPanels(
				Vector2.new(width, height),
				config,
				Config.Layout.PortraitMaxAspect,
				Config.Layout.ShortLandscapeMaxHeightPx
			).progressStack == nil
		then
			return height
		end
	end
	error("no viewport height fits the desktop splash cards")
end

local INVENTORY_PANEL = {
	Portrait = { WidthScale = 0.956, HeightScale = 0.75, MaxSize = Vector2.new(480, 720) },
	Landscape = {
		WidthScale = 0.602436,
		HeightScale = 0.74763,
		MaxSize = Vector2.new(1000, 820),
		AspectRatio = 1.08,
	},
}
local SHOP_PANEL = {
	Portrait = { WidthScale = 0.956, HeightScale = 0.78, MaxSize = Vector2.new(680, 760) },
	Landscape = {
		WidthScale = 0.9,
		HeightScale = 0.82,
		MaxSize = Vector2.new(1240, 820),
		AspectRatio = 1.5,
	},
}
local PORTRAIT_MAX_ASPECT = 1
-- ResponsiveLayout.splashPanels ends a non-tabbed intermediate column this far above the bottom edge.
local STACKED_COLUMN_BOTTOM_MARGIN_PX = 24
-- Tabbed (short-phone) columns end this far above the bottom edge.
local TABBED_COLUMN_BOTTOM_MARGIN_PX = 12
-- Mirrors SplashPage's portrait action dock: the BottomRight frame is bottom
-- anchored at 0.98 and PortraitActionsHeightPx tall, so the progress panels have
-- to end above it.
local SPLASH_ACTIONS_BOTTOM_SCALE = 0.98
local SPLASH_ACTIONS_HEIGHT_PX = 146
-- Seven day cells stay legible only while the card keeps this much height.
local DAILY_MIN_HEIGHT_PX = 88
local SPLASH_PANELS = {
	DailyMinHeightPx = 98,
	EdgePaddingPx = 24,
	GapPx = 10,
	Landscape = {
		SeasonHeightPx = 88,
		DailyHeightPx = 140,
		QuestsMinHeightPx = 116,
		DailyBottomScale = 0.9,
		SeasonTopScale = 0.145,
		QuestsTopScale = 0.31,
	},
	Portrait = {
		WidthScale = 0.94,
		TopScale = 0.24,
		BottomScale = 0.67,
		GapPx = 6,
		SeasonWeight = 0.22,
		DailyWeight = 0.37,
		QuestsWeight = 0.41,
	},
	Daily = {
		WidthScale = 0.34,
		HeightScale = 0.27,
		MaxSize = Vector2.new(600, 220),
		AspectRatio = 2.5,
	},
	Season = {
		WidthScale = 0.3,
		HeightScale = 0.16,
		MaxSize = Vector2.new(600, 180),
		AspectRatio = 3.5,
	},
	Quests = {
		WidthScale = 0.3,
		HeightScale = 0.32,
		MaxSize = Vector2.new(600, 340),
		AspectRatio = 1.65,
	},
}

local function overlaps(positionA: Vector2, sizeA: Vector2, positionB: Vector2, sizeB: Vector2): boolean
	return positionA.X < positionB.X + sizeB.X
		and positionA.X + sizeA.X > positionB.X
		and positionA.Y < positionB.Y + sizeB.Y
		and positionA.Y + sizeA.Y > positionB.Y
end

local function landscapePanels()
	local config = table.clone(SPLASH_PANELS)
	config.DailyMinHeightPx = 140
	config.Landscape = table.clone(config.Landscape)
	config.Landscape.ActionsReservePx = 252
	config.Landscape.ShortTopPx = 80
	config.Landscape.ShortBottomPx = 78
	config.Season = table.clone(config.Season)
	config.Season.ShortHeightScale = 0.19
	config.Season.ShortAspectRatio = 4
	config.Quests = table.clone(config.Quests)
	config.Quests.ShortHeightScale = 0.4
	return config
end

local function shopPanels()
	local inventory = { Portrait = INVENTORY_PANEL.Portrait, Landscape = table.clone(INVENTORY_PANEL.Landscape) }
	inventory.Landscape.ShortWidthScale = 0.9
	inventory.Landscape.ShortHeightScale = 0.7
	inventory.Landscape.ShortAspectRatio = 2.4
	local shop = { Portrait = SHOP_PANEL.Portrait, Landscape = table.clone(SHOP_PANEL.Landscape) }
	shop.Landscape.ShortWidthScale = 0.9
	shop.Landscape.ShortHeightScale = 0.7
	shop.Landscape.ShortAspectRatio = 2.5
	return {
		PortraitMaxAspect = PORTRAIT_MAX_ASPECT,
		ShortLandscapeMaxHeightPx = 500,
		PagePosition = { X = { Scale = 0.5, Offset = 0 }, Y = { Scale = 0.56, Offset = 0 } },
		InventoryPagePosition = { X = { Scale = 0.32, Offset = 0 }, Y = { Scale = 0.56, Offset = 0 } },
		Panels = { Inventory = inventory, Shop = shop },
		TopBar = { ShortHeightPx = 72 },
		Inventory = { ShortPanelMinWidthPx = 360, ShortPanelWidthScale = 0.58, ShortWorldMinWidthPx = 170 },
	}
end

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
			local fitHeight = desktopCardsMinHeight(1158)
			local intermediate = Layout.splashPanels(Vector2.new(1158, fitHeight - 1), config, 1, 500)
			local stack = assert(intermediate.progressStack)
			expect(intermediate.tabbed).to.equal(false)
			expect(stack.position.Y + stack.size.Y).to.equal(fitHeight - 1 - STACKED_COLUMN_BOTTOM_MARGIN_PX)
			local desktop = Layout.splashPanels(Vector2.new(1158, fitHeight), config, 1, 500)
			expect(desktop.progressStack == nil).to.equal(true)
			expect(desktop.daily.size.Y >= config.Landscape.DailyHeightPx).to.equal(true)
			expect(desktop.quests.size.Y >= config.Landscape.QuestsMinHeightPx).to.equal(true)
			expect(desktop.quests.position.Y + desktop.quests.size.Y <= fitHeight - config.Landscape.ActionsReservePx).to.equal(
				true
			)
		end)
		it("fits season daily and quest cards together in a roomier intermediate column", function()
			local config = Config.Layout.Splash.ProgressPanels
			local fitHeight = desktopCardsMinHeight(1158)
			for _, size in { Vector2.new(1158, 600), Vector2.new(1158, 662), Vector2.new(1158, fitHeight - 1) } do
				local panels = Layout.splashPanels(size, config, 1, 500)
				local stack = assert(panels.progressStack)
				expect(panels.tabbed).to.equal(false)
				expect(stack.position.Y + stack.size.Y).to.equal(size.Y - STACKED_COLUMN_BOTTOM_MARGIN_PX)
				local questContentBudget = stack.size.Y
					- panels.season.size.Y
					- panels.daily.size.Y
					- config.GapPx * 3.5
				expect(panels.season.size.Y >= config.Landscape.SeasonHeightPx).to.equal(true)
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
					Vector2.new(820, desktopCardsMinHeight(820)),
					Vector2.new(1158, desktopCardsMinHeight(1158)),
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
				-- The shipped column keeps at least Landscape.MinWidthPx, so the narrowest desktop
				-- window gives the party about half the width instead of 60%.
				local worldWidthShare = if size.X >= 1024 then 0.6 else 0.5
				expect(world.size.X >= size.X * worldWidthShare and world.size.Y >= size.Y * 0.6).to.equal(true)
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
				expect(stack.position.Y + stack.size.Y).to.equal(
					size.Y - (if panels.tabbed then TABBED_COLUMN_BOTTOM_MARGIN_PX else STACKED_COLUMN_BOTTOM_MARGIN_PX)
				)
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
			-- The redesign unified Play at one height; desktop prominence is carried by the larger label.
			expect(actions.DesktopPrimaryActionHeightPx >= actions.PrimaryActionHeightPx).to.equal(true)
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

	describe("Inset coordinate conversion", function()
		it("restores full-screen height when engine rectangles start above the Core UI origin", function()
			local rect = Layout.insetRect(
				Vector2.new(666, 374),
				Vector2.new(0, -58),
				Vector2.new(666, 316),
				Vector2.new(0, -58),
				Vector2.new(666, 316)
			)
			expect(rect.position.Y).to.equal(0)
			expect(rect.size.Y).to.equal(374)
		end)
		it("preserves hardware cutouts and an already inset Core UI parent", function()
			local deviceMin, deviceMax = Vector2.new(0, -58), Vector2.new(733, 313)
			local full = Layout.insetRect(
				Vector2.new(851, 392),
				deviceMin,
				deviceMax,
				Vector2.new(-59, -58),
				Vector2.new(792, 334)
			)
			expect(full.position.X).to.equal(59)
			expect(full.size.X).to.equal(733)
			expect(full.size.Y).to.equal(371)
			local core =
				Layout.insetRect(Vector2.new(851, 392), deviceMin, deviceMax, Vector2.zero, Vector2.new(733, 313))
			expect(core.position.X).to.equal(0)
			expect(core.size.Y).to.equal(313)
		end)
	end)

	describe("Responsive UI layout", function()
		it("keeps home progression clear of actions across fixed and fallback compositions", function()
			local config = landscapePanels()
			for _, size in
				{
					Vector2.new(820, 501),
					Vector2.new(1158, 520),
					Vector2.new(1158, 600),
					Vector2.new(1158, 691),
					Vector2.new(1158, 692),
					Vector2.new(1158, 725),
					Vector2.new(1920, 1080),
				}
			do
				local layout = Layout.splashPanels(size, config, 1, 500)
				if layout.progressStack then
					local stack = layout.progressStack
					-- Non-short stacks share the action dock's 24 px bottom margin so the column and PLAY end together.
					expect(stack.position.Y + stack.size.Y).to.equal(size.Y - (if layout.tabbed then 12 else 24))
					expect(stack.size.Y >= 100).to.equal(true)
				else
					expect(layout.quests.position.Y + layout.quests.size.Y <= size.Y - 252).to.equal(true)
					expect(layout.quests.position.Y >= layout.daily.position.Y + layout.daily.size.Y + config.GapPx).to.equal(
						true
					)
					expect(layout.quests.size.Y - 60 >= 44).to.equal(true)
				end
			end
		end)

		it("reflows an intermediate-height home when the desktop actions leave too little card space", function()
			local config = landscapePanels()
			local unreserved = landscapePanels()
			unreserved.Landscape.ActionsReservePx = 0
			for _, size in
				{ Vector2.new(666, 258), Vector2.new(750, 303), Vector2.new(820, 499), Vector2.new(820, 500) }
			do
				local layout = Layout.splashPanels(size, config, 1, 500)
				local original = Layout.splashPanels(size, unreserved, 1, 500)
				for _, name in { "daily", "season", "quests" } do
					expect(layout[name].position.Y).to.equal(original[name].position.Y)
					expect(layout[name].size.Y).to.equal(original[name].size.Y)
				end
				expect(layout.tabbed).to.equal(true)
				local stack = assert(layout.progressStack)
				expect(stack.position.Y + stack.size.Y).to.equal(size.Y - 12)
			end
			local size = Vector2.new(820, 501)
			local layout = Layout.splashPanels(size, config, 1, 500)
			local original = Layout.splashPanels(size, unreserved, 1, 500)
			expect(original.progressStack).to.equal(nil)
			local stack = assert(layout.progressStack)
			expect(layout.tabbed).to.equal(true)
			expect(stack.position.Y + stack.size.Y).to.equal(size.Y - 12)
		end)

		it("keeps desktop rewards aligned and uses the available column for scrollable quests", function()
			local config = landscapePanels()
			local size = Vector2.new(1920, 1080)
			local layout = Layout.splashPanels(size, config, 1, 500)
			expect(layout.progressStack).to.equal(nil)
			expect(layout.quests.position.Y + layout.quests.size.Y).to.equal(size.Y - 252)
			for _, panel in { layout.daily, layout.quests } do
				expect(panel.position.X).to.equal(layout.season.position.X)
				expect(panel.size.X).to.equal(layout.season.size.X)
			end
			expect(layout.daily.position.Y >= layout.season.position.Y + layout.season.size.Y + config.GapPx).to.equal(
				true
			)
			expect(layout.quests.size.Y - 60 >= 44).to.equal(true)
		end)

		it("uses short landscape dimensions without changing the portrait branch", function()
			local spec = {
				Portrait = INVENTORY_PANEL.Portrait,
				Landscape = table.clone(INVENTORY_PANEL.Landscape),
			}
			spec.Landscape.ShortWidthScale = 0.9
			spec.Landscape.ShortHeightScale = 0.7
			spec.Landscape.ShortAspectRatio = 2.4
			local landscape = Layout.panelSize(Vector2.new(666, 316), spec, 1, 500)
			expect(landscape.X > 500).to.equal(true)
			expect(landscape.Y).to.equal(221)
			local portrait = Layout.panelSize(Vector2.new(390, 844), spec, 1, 500)
			expect(portrait.X).to.equal(372)
			expect(portrait.Y).to.equal(633)
		end)

		it("reserves readable quest content when phone categories occupy the right column", function()
			local config = table.clone(SPLASH_PANELS)
			config.Landscape = table.clone(config.Landscape)
			config.Landscape.ShortTopPx = 80
			config.Landscape.ShortBottomPx = 62
			config.Season = table.clone(config.Season)
			config.Season.ShortHeightScale = 0.14
			config.Quests = table.clone(config.Quests)
			config.Quests.ShortHeightScale = 0.4
			local layout = Layout.splashPanels(Vector2.new(666, 316), config, 1, 500)
			expect(layout.quests.size.Y >= 120).to.equal(true)
			expect(layout.tabbed).to.equal(true)
			local stack = assert(layout.progressStack)
			expect(stack.position.Y + stack.size.Y).to.equal(304)
			expect(stack.size.Y - 44 - 12 >= 140).to.equal(true)
			expect(overlaps(layout.season.position, layout.season.size, layout.quests.position, layout.quests.size)).to.equal(
				false
			)
		end)

		it("expands the inventory panel instead of preserving its landscape aspect in portrait", function()
			local size = Layout.panelSize(Vector2.new(390, 844), INVENTORY_PANEL, PORTRAIT_MAX_ASPECT)
			expect(size.X).to.equal(372)
			expect(size.Y).to.equal(633)
		end)

		it("preserves the bounded desktop inventory aspect", function()
			local size = Layout.panelSize(Vector2.new(1920, 1080), INVENTORY_PANEL, PORTRAIT_MAX_ASPECT)
			expect(size.X).to.equal(872)
			expect(size.Y).to.equal(807)
		end)

		it("gives the landscape shop the midpoint between its original width and the backpack", function()
			local available = Vector2.new(1920, 1080)
			local config = {
				PortraitMaxAspect = PORTRAIT_MAX_ASPECT,
				ShortLandscapeMaxHeightPx = 500,
				PagePosition = { X = { Scale = 0.5, Offset = 0 }, Y = { Scale = 0.56, Offset = 0 } },
				InventoryPagePosition = { X = { Scale = 0.32, Offset = 0 }, Y = { Scale = 0.56, Offset = 0 } },
				Panels = { Inventory = INVENTORY_PANEL, Shop = SHOP_PANEL },
			}
			local backpack = Layout.inventoryComposition(available, config)
			local original = Layout.panelSize(available, SHOP_PANEL, PORTRAIT_MAX_ASPECT, 500)
			local shop = Layout.shopComposition(available, config)
			expect(shop.panel.size.X).to.equal(math.floor((backpack.panel.size.X + original.X) / 2))
			expect(shop.panel.size.Y).to.equal(math.floor((backpack.panel.size.Y + original.Y) / 2))
			expect(shop.panel.position.X).to.equal(backpack.panel.position.X)
			-- Vector2 components are float32 in Studio, so edges that are sums of fractional values
			-- match only within a tolerance (1241.3999 vs 1241.4).
			expect(shop.world.position.X).to.be.near(shop.panel.position.X + shop.panel.size.X + 12, 0.01)
			expect(shop.world.position.X + shop.world.size.X).to.be.near(available.X - 12, 0.01)
		end)

		it("preserves desktop shop geometry without a mobile header reservation", function()
			local available = Vector2.new(1920, 1080)
			local config = shopPanels()
			local backpack = Layout.inventoryComposition(available, config)
			local original = Layout.panelSize(available, config.Panels.Shop, PORTRAIT_MAX_ASPECT, 500)
			local shop = Layout.shopComposition(available, config, nil)
			expect(shop.panel.size.X).to.equal(math.floor((backpack.panel.size.X + original.X) / 2))
			expect(shop.panel.size.Y).to.equal(math.floor((backpack.panel.size.Y + original.Y) / 2))
			expect(shop.panel.position.X).to.equal(backpack.panel.position.X)
			expect(shop.panel.position.Y).to.equal(
				backpack.panel.position.Y + (backpack.panel.size.Y - shop.panel.size.Y) / 2
			)
		end)

		it("gives landscape browsers usable width below the mobile header and a separate preview", function()
			for _, available in { Vector2.new(600, 280), Vector2.new(750, 304), Vector2.new(844, 344) } do
				local config = shopPanels()
				local shop = Layout.shopComposition(available, config, 13)
				local backpack = Layout.inventoryComposition(available, config, 13)
				expect(shop.panel.size).to.equal(backpack.panel.size)
				expect(shop.panel.position.Y >= 13 + 12).to.equal(true)
				expect(shop.panel.position.Y + shop.panel.size.Y <= available.Y - 12).to.equal(true)
				expect(shop.panel.size.X >= 390).to.equal(true)
				expect(shop.world.size.X >= 154).to.equal(true)
				expect(shop.panel.position.X + shop.panel.size.X < shop.world.position.X).to.equal(true)
				expect(shop.world.position.X + shop.world.size.X <= available.X - 12).to.equal(true)
			end
		end)

		it("extends portrait shop content through the height freed by compact navigation", function()
			local available = Vector2.new(402, 778)
			local config = shopPanels()
			local legacy = Layout.shopComposition(available, config)
			local shop = Layout.shopComposition(available, config, 17)
			expect(shop.panel.position.Y).to.equal(29)
			expect(shop.panel.position.Y + shop.panel.size.Y).to.equal(766)
			expect(shop.panel.position.X).to.equal(legacy.panel.position.X)
			expect(shop.panel.size.X).to.equal(legacy.panel.size.X)
			expect(shop.panel.size.Y - legacy.panel.size.Y >= 120).to.equal(true)
			expect(shop.world.position.Y).to.equal(shop.panel.position.Y)
			expect(shop.world.size.Y).to.equal(shop.panel.size.Y)
			local tallerHeader = Layout.shopComposition(available, config, 67)
			expect(shop.panel.size.Y - tallerHeader.panel.size.Y).to.equal(50)
		end)

		it("derives usable inventory card columns from available width", function()
			local phoneColumns, phoneCell = Layout.gridCellSize(311, 132, 150, 7, 6)
			expect(phoneColumns).to.equal(2)
			expect(phoneCell).to.equal(150)

			local narrowColumns, narrowCell = Layout.gridCellSize(126, 132, 150, 7, 6)
			expect(narrowColumns).to.equal(1)
			expect(narrowCell).to.equal(126)
		end)

		it("translates device-safe bounds only for full-screen roots", function()
			local fullScreen = Layout.safeRect(Vector2.new(390, 844), Vector2.new(0, 47), Vector2.new(390, 810), true)
			expect(fullScreen.position.X).to.equal(0)
			expect(fullScreen.position.Y).to.equal(47)
			expect(fullScreen.size.X).to.equal(390)
			expect(fullScreen.size.Y).to.equal(763)

			local insetRoot = Layout.safeRect(Vector2.new(390, 844), Vector2.new(0, 47), Vector2.new(390, 810), false)
			expect(insetRoot.position.X).to.equal(0)
			expect(insetRoot.position.Y).to.equal(0)
			expect(insetRoot.size.X).to.equal(390)
			expect(insetRoot.size.Y).to.equal(763)

			-- The camera reports (1, 1) until the first frame, so a real device inset can
			-- exceed the viewport; that has to yield a degenerate rect, not an error.
			local unrendered = Layout.safeRect(Vector2.new(1, 1), Vector2.new(0, 47), Vector2.new(1, 1), true)
			expect(unrendered.size.X >= 0 and unrendered.size.Y >= 0).to.equal(true)
			expect(unrendered.position.X >= 0 and unrendered.position.Y >= 0).to.equal(true)

			local noCamera = Layout.safeRect(Vector2.zero, Vector2.new(12, 47), Vector2.zero, true)
			expect(noCamera.size.X).to.equal(0)
			expect(noCamera.size.Y).to.equal(0)
		end)

		it("reserves a non-intersecting keycap band at every supported menu size", function()
			local config = {
				HorizontalPaddingPx = 12,
				LabelKeycapGapPx = 10,
				KeycapWidthScale = 0.27,
			}
			for _, size in { Vector2.new(126, 54), Vector2.new(210, 88) } do
				local layout = Layout.menuToggle(
					size,
					config.HorizontalPaddingPx,
					config.LabelKeycapGapPx,
					config.KeycapWidthScale
				)
				expect(overlaps(layout.labelPosition, layout.labelSize, layout.keycapPosition, layout.keycapSize)).to.equal(
					false
				)
				expect(layout.keycapPosition.X - (layout.labelPosition.X + layout.labelSize.X)).to.equal(
					config.LabelKeycapGapPx
				)
			end
		end)

		it("keeps splash progress panels bounded and non-overlapping", function()
			for _, size in
				{
					Vector2.new(375, 586),
					Vector2.new(375, 667),
					Vector2.new(390, 844),
					Vector2.new(844, 390),
					Vector2.new(820, 500),
					Vector2.new(1920, 1080),
					Vector2.new(2560, 1440),
				}
			do
				local layout = Layout.splashPanels(size, SPLASH_PANELS, PORTRAIT_MAX_ASPECT, 500)
				expect(overlaps(layout.daily.position, layout.daily.size, layout.season.position, layout.season.size)).to.equal(
					false
				)
				expect(overlaps(layout.daily.position, layout.daily.size, layout.quests.position, layout.quests.size)).to.equal(
					false
				)
				expect(overlaps(layout.season.position, layout.season.size, layout.quests.position, layout.quests.size)).to.equal(
					false
				)
				if layout.portrait then
					local actionsTop = size.Y * SPLASH_ACTIONS_BOTTOM_SCALE - SPLASH_ACTIONS_HEIGHT_PX
					expect(layout.quests.position.Y + layout.quests.size.Y < actionsTop).to.equal(true)
				end
				expect(layout.daily.size.Y >= DAILY_MIN_HEIGHT_PX).to.equal(true)
				for _, panel in { layout.daily, layout.season, layout.quests } do
					expect(panel.position.X >= 0 and panel.position.Y >= 0).to.equal(true)
					expect(panel.position.X + panel.size.X <= size.X).to.equal(true)
					expect(panel.position.Y + panel.size.Y <= size.Y).to.equal(true)
				end
			end
		end)
	end)

	describe("Phone progression readability", function()
		it("fits category targets and a readable daily card on narrow landscape phones", function()
			for _, size in { Vector2.new(750, 304), Vector2.new(600, 302) } do
				local config = landscapePanels()
				local layout = Layout.splashPanels(size, config, 1, 500)
				local stack = assert(layout.progressStack)
				expect(layout.tabbed).to.equal(true)
				expect((stack.size.X - config.GapPx * 2) / 3 - 6 >= 44).to.equal(true)
				expect(stack.size.Y - 44 - 12 >= config.DailyMinHeightPx).to.equal(true)
				expect(stack.size.Y - 44 - 12 >= 138).to.equal(true)
				expect(stack.position.Y + stack.size.Y).to.equal(size.Y - 12)
			end
		end)
		it("keeps every category visible when an intermediate home has room for a vertical column", function()
			local config = landscapePanels()
			for _, size in { Vector2.new(1158, 600), Vector2.new(1158, 662), Vector2.new(1158, 719) } do
				local layout = Layout.splashPanels(size, config, 1, 500)
				local stack = assert(layout.progressStack)
				expect(layout.tabbed).to.equal(false)
				expect(stack.position.Y + stack.size.Y).to.equal(size.Y - 24)
				-- Two card gaps plus the column's top/bottom padding must also fit.
				local questContentBudget = stack.size.Y
					- layout.season.size.Y
					- layout.daily.size.Y
					- config.GapPx * 3.5
				expect(layout.season.size.Y >= 88).to.equal(true)
				expect(layout.daily.size.Y >= config.DailyMinHeightPx).to.equal(true)
				expect(questContentBudget >= config.Landscape.QuestsMinHeightPx).to.equal(true)
			end
		end)
		it("returns to fixed desktop cards only when all cards and actions fit", function()
			local config = landscapePanels()
			local intermediate = Layout.splashPanels(Vector2.new(1158, 719), config, 1, 500)
			local stack = assert(intermediate.progressStack)
			expect(intermediate.tabbed).to.equal(false)
			expect(stack.position.Y + stack.size.Y).to.equal(719 - 24)
			local desktop = Layout.splashPanels(Vector2.new(1158, 725), config, 1, 500)
			expect(desktop.progressStack).to.equal(nil)
			expect(desktop.daily.size.Y >= 140).to.equal(true)
			expect(desktop.quests.size.Y >= config.Landscape.QuestsMinHeightPx).to.equal(true)
			expect(desktop.quests.position.Y + desktop.quests.size.Y <= 725 - config.Landscape.ActionsReservePx).to.equal(
				true
			)
		end)
		it("uses the phone right column to its bottom margin independently of left-side actions", function()
			local config = landscapePanels()
			for _, size in
				{ Vector2.new(666, 258), Vector2.new(666, 316), Vector2.new(750, 303), Vector2.new(820, 500) }
			do
				local layout = Layout.splashPanels(size, config, 1, 500)
				local stack = assert(layout.progressStack)
				expect(stack.position.Y).to.equal(layout.season.position.Y)
				expect(layout.tabbed).to.equal(true)
				expect(stack.position.Y + stack.size.Y).to.equal(size.Y - 12)
				expect(stack.position.X >= 0 and stack.position.X + stack.size.X <= size.X).to.equal(true)
				expect(stack.size.X - config.GapPx * 2 >= layout.season.size.X).to.equal(true)
				expect(stack.size.Y - 44 - 12 >= 44).to.equal(true)
			end
		end)
		it("leaves roomy desktop progression unstacked", function()
			for _, size in { Vector2.new(820, 725), Vector2.new(1158, 725) } do
				expect(Layout.splashPanels(size, landscapePanels(), 1, 500).progressStack).to.equal(nil)
			end
		end)
		it("reserves a real portrait world window above the progression tabs and action dock", function()
			for _, size in { Vector2.new(375, 586), Vector2.new(390, 844), Vector2.new(440, 802) } do
				local config = landscapePanels()
				local panels = Layout.splashPanels(size, config, 1, 500)
				local stack = assert(panels.progressStack)
				local world = Layout.splashWorldWindow(size, {
					Splash = { ProgressPanels = config },
					PortraitMaxAspect = 1,
					ShortLandscapeMaxHeightPx = 500,
				})
				expect(panels.tabbed).to.equal(true)
				expect(world.size.X > 1 and world.size.Y > 1).to.equal(true)
				expect(world.position.Y + world.size.Y < stack.position.Y).to.equal(true)
				expect(stack.position.Y + stack.size.Y < size.Y - 24 - SPLASH_ACTIONS_HEIGHT_PX).to.equal(true)
				expect(stack.size.Y - 56 >= 140).to.equal(true)
			end
		end)
		it("reserves a full quest title and readable daily amounts in portrait", function()
			local layout = Layout.splashPanels(Vector2.new(374, 618), SPLASH_PANELS, PORTRAIT_MAX_ASPECT, 500)
			expect(layout.quests.size.Y - 56 >= 42).to.equal(true)
			expect(layout.daily.size.Y >= 98).to.equal(true)
			expect(overlaps(layout.daily.position, layout.daily.size, layout.quests.position, layout.quests.size)).to.equal(
				false
			)
		end)
	end)
end
