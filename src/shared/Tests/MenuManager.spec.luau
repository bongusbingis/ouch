--!strict

local T = require(script.Parent.TestKit)

local Client = script.Parent.Parent.Parent.Parent.StarterPlayer.StarterPlayerScripts.Client
local MenuManager = require(Client.Modules.UI.MenuManager)

type FakeGui = {
	Name: string,
	ClassName: string,
	Visible: boolean,
	_children: { [string]: FakeGui },
	_order: { FakeGui },
	FindFirstChild: (self: FakeGui, name: string) -> FakeGui?,
	GetChildren: (self: FakeGui) -> { FakeGui },
	IsA: (self: FakeGui, className: string) -> boolean,
}

local function fakeGui(name: string, className: string): FakeGui
	local gui = {
		Name = name,
		ClassName = className,
		Visible = true,
		_children = {},
		_order = {},
	} :: any

	function gui:FindFirstChild(childName: string): FakeGui?
		return self._children[childName]
	end

	function gui:GetChildren(): { FakeGui }
		return self._order
	end

	function gui:IsA(className: string): boolean
		return self.ClassName == className or (className == "GuiObject" and self.ClassName == "Frame")
	end

	return gui :: FakeGui
end

local function addChild(parent: FakeGui, child: FakeGui): FakeGui
	parent._children[child.Name] = child
	table.insert(parent._order, child)
	return child
end

local function makeViews(includeInventory: boolean?): (FakeGui, FakeGui, FakeGui?)
	local views = fakeGui("Views", "Folder")
	local shop = addChild(views, fakeGui("Shop", "Frame"))
	local inventory = if includeInventory == false then nil else addChild(views, fakeGui("Inventory", "Frame"))
	return views, shop, inventory
end

T.describe("MenuManager", function()
	T.it("start hides all registered menu frames", function()
		MenuManager._resetForTest()
		local views, shop, inventory = makeViews()

		MenuManager.start(views :: any)

		T.expect(shop.Visible):toEqual(false)
		T.expect((inventory :: FakeGui).Visible):toEqual(false)
		T.expect(MenuManager.isOpen()):toEqual(false)
	end)

	T.it("opens one menu at a time", function()
		MenuManager._resetForTest()
		local views, shop, inventory = makeViews()
		MenuManager.start(views :: any)

		T.expect(MenuManager.open("Shop")):toEqual(true)
		T.expect(shop.Visible):toEqual(true)
		T.expect((inventory :: FakeGui).Visible):toEqual(false)
		T.expect(MenuManager.getOpenMenu()):toEqual("Shop")

		T.expect(MenuManager.open("Inventory")):toEqual(true)
		T.expect(shop.Visible):toEqual(false)
		T.expect((inventory :: FakeGui).Visible):toEqual(true)
		T.expect(MenuManager.getOpenMenu()):toEqual("Inventory")
	end)

	T.it("opening the active menu toggles it closed", function()
		MenuManager._resetForTest()
		local views, shop = makeViews()
		MenuManager.start(views :: any)

		T.expect(MenuManager.open("Shop")):toEqual(true)
		T.expect(MenuManager.open("Shop")):toEqual(false)

		T.expect(shop.Visible):toEqual(false)
		T.expect(MenuManager.getOpenMenu()):toBeNil()
	end)

	T.it("close is idempotent", function()
		MenuManager._resetForTest()
		local views, shop = makeViews()
		MenuManager.start(views :: any)

		T.expect(MenuManager.close()):toEqual(false)
		MenuManager.open("Shop")
		T.expect(MenuManager.close()):toEqual(true)
		T.expect(MenuManager.close()):toEqual(false)
		T.expect(shop.Visible):toEqual(false)
	end)

	T.it("missing registered views fail without corrupting state", function()
		MenuManager._resetForTest()
		local views, shop = makeViews(false)
		MenuManager.start(views :: any)

		T.expect(MenuManager.open("Shop")):toEqual(true)
		T.expect(MenuManager.open("Inventory")):toEqual(false)

		T.expect(shop.Visible):toEqual(true)
		T.expect(MenuManager.getOpenMenu()):toEqual("Shop")
	end)

	T.it("onChanged fires once for each real transition", function()
		MenuManager._resetForTest()
		local views = makeViews()
		MenuManager.start(views :: any)
		local events = {}
		MenuManager.onChanged(function(newMenu, oldMenu, reason)
			table.insert(events, {
				newMenu = newMenu,
				oldMenu = oldMenu,
				reason = reason,
			})
		end)

		MenuManager.open("Shop")
		MenuManager.open("Inventory")
		MenuManager.open("Inventory")
		MenuManager.close()

		T.expect(#events):toEqual(3)
		T.expect(events[1].newMenu):toEqual("Shop")
		T.expect(events[1].oldMenu):toBeNil()
		T.expect(events[2].newMenu):toEqual("Inventory")
		T.expect(events[2].oldMenu):toEqual("Shop")
		T.expect(events[2].reason):toEqual("Switch")
		T.expect(events[3].newMenu):toBeNil()
		T.expect(events[3].oldMenu):toEqual("Inventory")
		T.expect(events[3].reason):toEqual("Toggle")
	end)
end)

return true
