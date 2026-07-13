--!strict

local T = require(script.Parent.TestKit)

local Client = script.Parent.Parent.Parent.Parent.StarterPlayer.StarterPlayerScripts.Client
local MenuManager = require(Client.Modules.UI.MenuManager)
local MenuRegistry = require(Client.Modules.UI.MenuRegistry)

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
		return self.ClassName == className
			or (className == "GuiObject" and (self.ClassName == "Frame" or self.ClassName == "CanvasGroup"))
	end

	return gui :: FakeGui
end

local function addChild(parent: FakeGui, child: FakeGui): FakeGui
	parent._children[child.Name] = child
	table.insert(parent._order, child)
	return child
end

local function registeredMenus()
	local entries = {}
	for menuId, definition in MenuRegistry do
		table.insert(entries, {
			id = menuId,
			viewName = definition.viewName,
		})
	end
	table.sort(entries, function(left, right)
		return left.id < right.id
	end)
	return entries
end

local function makeViews(omitMenuId: string?): (FakeGui, { [string]: FakeGui })
	local views = fakeGui("Views", "Folder")
	local byId = {}
	for _, entry in registeredMenus() do
		if entry.id ~= omitMenuId then
			byId[entry.id] = addChild(views, fakeGui(entry.viewName, "Frame"))
		end
	end
	return views, byId
end

T.describe("MenuManager", function()
	T.it("start hides all registered menu frames", function()
		MenuManager._resetForTest()
		local views, byId = makeViews()

		MenuManager.start(views :: any)

		for _, view in byId do
			T.expect(view.Visible):toEqual(false)
		end
		T.expect(MenuManager.isOpen()):toEqual(false)
	end)

	T.it("opens one menu at a time", function()
		MenuManager._resetForTest()
		local menus = registeredMenus()
		local first = menus[1].id
		local second = if menus[2] then menus[2].id else nil
		local views, byId = makeViews()
		MenuManager.start(views :: any)

		T.expect(MenuManager.open(first)):toEqual(true)
		T.expect(byId[first].Visible):toEqual(true)
		T.expect(MenuManager.getOpenMenu()):toEqual(first)

		if second then
			T.expect(MenuManager.open(second)):toEqual(true)
			T.expect(byId[first].Visible):toEqual(false)
			T.expect(byId[second].Visible):toEqual(true)
			T.expect(MenuManager.getOpenMenu()):toEqual(second)
		end
	end)

	T.it("opening the active menu toggles it closed", function()
		MenuManager._resetForTest()
		local first = registeredMenus()[1].id
		local views, byId = makeViews()
		MenuManager.start(views :: any)

		T.expect(MenuManager.open(first)):toEqual(true)
		T.expect(MenuManager.open(first)):toEqual(false)

		T.expect(byId[first].Visible):toEqual(false)
		T.expect(MenuManager.getOpenMenu()):toBeNil()
	end)

	T.it("close is idempotent", function()
		MenuManager._resetForTest()
		local first = registeredMenus()[1].id
		local views, byId = makeViews()
		MenuManager.start(views :: any)

		T.expect(MenuManager.close()):toEqual(false)
		MenuManager.open(first)
		T.expect(MenuManager.close()):toEqual(true)
		T.expect(MenuManager.close()):toEqual(false)
		T.expect(byId[first].Visible):toEqual(false)
	end)

	T.it("missing registered views fail without corrupting state", function()
		MenuManager._resetForTest()
		local menus = registeredMenus()
		local first = menus[1].id
		local missing = if menus[2] then menus[2].id else first
		local views, byId = makeViews(missing)
		MenuManager.start(views :: any)

		if missing ~= first then
			T.expect(MenuManager.open(first)):toEqual(true)
			T.expect(MenuManager.open(missing)):toEqual(false)

			T.expect(byId[first].Visible):toEqual(true)
			T.expect(MenuManager.getOpenMenu()):toEqual(first)
		else
			T.expect(MenuManager.open(first)):toEqual(false)
			T.expect(MenuManager.getOpenMenu()):toBeNil()
		end
	end)

	T.it("onChanged fires once for each real transition", function()
		MenuManager._resetForTest()
		local menus = registeredMenus()
		local first = menus[1].id
		local second = if menus[2] then menus[2].id else nil
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

		MenuManager.open(first)
		if second then
			MenuManager.open(second)
			MenuManager.open(second)
		else
			MenuManager.open(first)
		end
		MenuManager.close()

		T.expect(#events):toEqual(if second then 3 else 2)
		T.expect(events[1].newMenu):toEqual(first)
		T.expect(events[1].oldMenu):toBeNil()
		if second then
			T.expect(events[2].newMenu):toEqual(second)
			T.expect(events[2].oldMenu):toEqual(first)
			T.expect(events[2].reason):toEqual("Switch")
			T.expect(events[3].newMenu):toBeNil()
			T.expect(events[3].oldMenu):toEqual(second)
			T.expect(events[3].reason):toEqual("Toggle")
		else
			T.expect(events[2].newMenu):toBeNil()
			T.expect(events[2].oldMenu):toEqual(first)
			T.expect(events[2].reason):toEqual("Toggle")
		end
	end)
end)

return true
