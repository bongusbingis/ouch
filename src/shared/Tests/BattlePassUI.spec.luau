--!strict

local T = require(script.Parent.TestKit)

local Client = script.Parent.Parent.Parent.Parent.StarterPlayer.StarterPlayerScripts.Client
local BattlePassController = require(Client.Modules.UI.BattlePassController)

local function fakeElement()
	local mounted = {}
	local element = {}
	function element.mount(parent, props)
		local handle = {
			parent = parent,
			props = props,
			enabled = true,
			destroyed = false,
			instance = {},
		}
		function handle:setEnabled(value)
			self.enabled = value
		end
		function handle:destroy()
			self.destroyed = true
		end
		table.insert(mounted, handle)
		return handle
	end
	return element, mounted
end

-- render() destroys and remounts every handle each pass, so assertions must
-- look at what is currently mounted rather than everything ever mounted.
local function live(handles: { any }): { any }
	local result = {}
	for _, handle in handles do
		if not handle.destroyed then
			table.insert(result, handle)
		end
	end
	return result
end

local function fakeMenu()
	local callbacks = {}
	local menu = { open = nil :: string? }
	function menu.isOpen(menuId)
		return menu.open == menuId
	end
	function menu.onChanged(callback)
		table.insert(callbacks, callback)
		return function() end
	end
	function menu.close() end
	function menu:setOpen(menuId: string?)
		self.open = menuId
		for _, callback in callbacks do
			callback(menuId)
		end
	end
	return menu
end

local function nodes()
	return {
		title = { Text = "" },
		status = { Text = "" },
		tierLabel = { Text = "" },
		progressFill = { Size = nil },
		claimAllMount = { Name = "ClaimAllMount" },
		premiumMount = { Name = "PremiumMount" },
		holder = { Name = "TierHolder" },
	}
end

local function state(overrides: any)
	local base = {
		active = true,
		seasonId = "S1",
		displayName = "Season One",
		startsAt = 0,
		endsAt = os.time() + 86400,
		xp = 150,
		tier = 1,
		tierCount = 3,
		xpIntoTier = 50,
		xpForNextTier = 150,
		hasPremium = false,
		premiumProductId = 5150,
		tiers = {
			{
				tier = 1,
				unlocked = true,
				freeReward = { kind = "Cash", amount = 50 },
				premiumReward = { kind = "Cash", amount = 200 },
				freeClaimed = false,
				premiumClaimed = false,
			},
			{
				tier = 2,
				unlocked = false,
				freeReward = { kind = "Cash", amount = 75 },
				premiumReward = nil,
				freeClaimed = false,
				premiumClaimed = false,
			},
		},
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function startWith(initial: any, calls: { any }?)
	BattlePassController._resetForTest()
	local node = nodes()
	local menu = fakeMenu()
	local buttonElement, buttons = fakeElement()
	local tierElement, tiers = fakeElement()
	BattlePassController.start({
		network = {
			on = function() end,
			call = function(name, ...)
				if calls then
					table.insert(calls, { name = name, args = { ... } })
				end
				return initial
			end,
		},
		menuManager = menu,
		buttonElement = buttonElement,
		tierElement = tierElement,
		marketplace = {},
		player = { UserId = 1 },
		viewNodes = node,
		runAsync = function(callback)
			callback()
		end,
	})
	menu:setOpen("BattlePass")
	return { node = node, buttons = live(buttons), tiers = live(tiers), menu = menu }
end

T.describe("BattlePassController", function()
	T.it("renders one row per tier with both track rewards", function()
		local f = startWith(state(nil))
		T.expect(#f.tiers):toEqual(2)
		T.expect(f.tiers[1].props.data.title):toEqual("TIER 1")
		T.expect(f.tiers[1].props.data.actionText):toEqual("CLAIM FREE")
		T.expect(f.tiers[1].props.data.actionEnabled):toEqual(true)
		T.expect(f.node.tierLabel.Text):toEqual("TIER 1 / 3")
	end)

	T.it("locks tiers the player has not reached", function()
		local f = startWith(state(nil))
		T.expect(f.tiers[2].props.data.actionText):toEqual("LOCKED")
		T.expect(f.tiers[2].props.data.actionEnabled):toEqual(false)
	end)

	T.it("never offers premium rewards without the pass", function()
		local f = startWith(state({
			tiers = {
				{
					tier = 1,
					unlocked = true,
					freeReward = nil,
					premiumReward = { kind = "Cash", amount = 200 },
					freeClaimed = false,
					premiumClaimed = false,
				},
			},
		}))
		T.expect(f.tiers[1].props.data.actionText):toEqual("PREMIUM ONLY")
		T.expect(f.tiers[1].props.data.actionEnabled):toEqual(false)
	end)

	T.it("offers premium rewards once the pass is owned", function()
		local f = startWith(state({
			hasPremium = true,
			tiers = {
				{
					tier = 1,
					unlocked = true,
					freeReward = nil,
					premiumReward = { kind = "Cash", amount = 200 },
					freeClaimed = false,
					premiumClaimed = false,
				},
			},
		}))
		T.expect(f.tiers[1].props.data.actionText):toEqual("CLAIM PREMIUM")
		T.expect(f.tiers[1].props.data.actionEnabled):toEqual(true)
	end)

	T.it("routes a claim through the server with the right tier and track", function()
		local calls = {}
		local f = startWith(state(nil), calls)
		f.tiers[1].props.activated("1")
		local last = calls[#calls]
		T.expect(last.name):toEqual("ClaimSeasonTier")
		T.expect(last.args[1]):toEqual(1)
		T.expect(last.args[2]):toEqual("Free")
	end)

	T.it("counts claimable rewards on the claim-all button", function()
		local f = startWith(state(nil))
		local claimAll = f.buttons[1]
		T.expect(claimAll.props.text):toEqual("CLAIM 1")
		T.expect(claimAll.enabled):toEqual(true)
	end)

	T.it("disables claim-all when nothing is pending", function()
		local f = startWith(state({
			tiers = {
				{
					tier = 1,
					unlocked = true,
					freeReward = { kind = "Cash", amount = 50 },
					premiumReward = nil,
					freeClaimed = true,
					premiumClaimed = false,
				},
			},
		}))
		T.expect(f.buttons[1].enabled):toEqual(false)
	end)

	T.it("offers the premium upsell only while unowned and purchasable", function()
		local unowned = startWith(state(nil))
		T.expect(unowned.buttons[2].props.text):toEqual("GET PREMIUM")
		T.expect(unowned.buttons[2].enabled):toEqual(true)

		local owned = startWith(state({ hasPremium = true }))
		T.expect(owned.buttons[2].props.text):toEqual("OWNED")
		T.expect(owned.buttons[2].enabled):toEqual(false)

		local pending = state(nil)
		pending.premiumProductId = nil
		local unlisted = startWith(pending)
		T.expect(unlisted.buttons[2].props.text):toEqual("SOON")
		T.expect(unlisted.buttons[2].enabled):toEqual(false)
	end)

	T.it("shows a neutral state when no season is live", function()
		-- Also covers the window before the very first season opens, which must
		-- not be described as a season having ended.
		local f = startWith({ active = false, seasonId = "", tiers = {} })
		T.expect(f.node.title.Text):toEqual("NO ACTIVE SEASON")
		T.expect(#f.tiers):toEqual(0)
	end)

	T.it("fetches state on first open rather than at startup", function()
		local calls = {}
		startWith(state(nil), calls)
		T.expect(calls[1].name):toEqual("GetSeasonPassState")
		BattlePassController._resetForTest()
	end)
end)

return true
