--!strict

local T = require(script.Parent.TestKit)

local Client = script.Parent.Parent.Parent.Parent.StarterPlayer.StarterPlayerScripts.Client
local MenuManager = require(Client.Modules.UI.MenuManager)
local MenuRegistry = require(Client.Modules.UI.MenuRegistry)
local SidebarController = require(Client.Modules.UI.SidebarController)

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
			or (className == "GuiObject" and (self.ClassName == "Frame" or self.ClassName == "ImageButton"))
	end

	return gui :: FakeGui
end

local function addChild(parent: FakeGui, child: FakeGui): FakeGui
	parent._children[child.Name] = child
	table.insert(parent._order, child)
	return child
end

local function sidebarMenus()
	local entries = {}
	for menuId, definition in MenuRegistry do
		if definition.showInSidebar ~= false then
			table.insert(entries, {
				id = menuId,
				definition = definition,
			})
		end
	end
	table.sort(entries, function(left, right)
		local leftOrder = left.definition.sidebarOrder or 0
		local rightOrder = right.definition.sidebarOrder or 0
		if leftOrder == rightOrder then
			return left.id < right.id
		end
		return leftOrder < rightOrder
	end)
	return entries
end

local function makeViews(): FakeGui
	local views = fakeGui("Views", "Folder")
	for menuId, definition in MenuRegistry do
		addChild(views, fakeGui(definition.viewName or menuId, "Frame"))
	end
	return views
end

T.describe("SidebarController", function()
	T.it("creates ordered menu buttons and routes activation through MenuManager", function()
		SidebarController._resetForTest()
		MenuManager._resetForTest()
		MenuManager.start(makeViews() :: any)

		local mounted = {}
		local fakeButtonElement = {
			mount = function(_parent, props)
				local handle = {
					instance = fakeGui(props.name, "ImageButton"),
					props = props,
					selected = props.selected == true,
					destroyed = false,
				}
				function handle:setSelected(selected: boolean)
					self.selected = selected
				end
				function handle:setEnabled(_enabled: boolean) end
				function handle:add(cleanup)
					return cleanup
				end
				function handle:destroy()
					self.destroyed = true
				end
				function handle:isDestroyed(): boolean
					return self.destroyed
				end
				table.insert(mounted, handle)
				return handle
			end,
		}

		SidebarController.start(fakeGui("Side", "Frame") :: any, {
			buttonElement = fakeButtonElement :: any,
		})

		local entries = sidebarMenus()
		local first = entries[1]

		T.expect(#mounted):toEqual(#entries)
		local mountedByName = {}
		for _, handle in mounted do
			mountedByName[handle.instance.Name] = handle
			T.expect(handle.instance:IsA("ImageButton")):toEqual(true)
		end
		T.expect(mountedByName.QuestsButton ~= nil):toEqual(true)
		T.expect(mountedByName.ShopButton ~= nil):toEqual(true)
		T.expect(mountedByName.InventoryButton ~= nil):toEqual(true)

		T.expect(mounted[1].props.text):toEqual(first.definition.label or first.definition.id)
		T.expect(mounted[1].props.layoutOrder):toEqual(first.definition.sidebarOrder)

		mounted[1].props.activated()
		T.expect(MenuManager.getOpenMenu()):toEqual(first.id)
		T.expect(mounted[1].selected):toEqual(true)

		mounted[1].props.activated()
		T.expect(MenuManager.getOpenMenu()):toBeNil()
		T.expect(mounted[1].selected):toEqual(false)

		SidebarController._resetForTest()
		T.expect(mounted[1].destroyed):toEqual(true)
	end)
end)

return true
