--!nonstrict
-- Cloud port of the SidebarController spec: ordered button creation from
-- MenuRegistry and open/toggle routing through a real MenuManager over real
-- view Frames. The button element stays injected — real GuiButton events
-- cannot be fired without a client.

local StarterPlayer = game:GetService("StarterPlayer")

local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local UI = Client:WaitForChild("Modules"):WaitForChild("UI")
local MenuManager = require(UI:WaitForChild("MenuManager"))
local MenuRegistry = require(UI:WaitForChild("MenuRegistry"))
local SidebarController = require(UI:WaitForChild("SidebarController"))

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

return function()
	describe("SidebarController", function()
		local created = {}

		local function makeViews(): Folder
			local views = Instance.new("Folder")
			views.Name = "Views"
			table.insert(created, views)
			for menuId, definition in MenuRegistry do
				local view = Instance.new("Frame")
				view.Name = definition.viewName or menuId
				view.Parent = views
			end
			return views
		end

		beforeEach(function()
			SidebarController._resetForTest()
			MenuManager._resetForTest()
		end)

		afterEach(function()
			SidebarController._resetForTest()
			MenuManager._resetForTest()
			for _, instance in created do
				instance:Destroy()
			end
			table.clear(created)
		end)

		it("creates ordered menu buttons and routes activation through MenuManager", function()
			MenuManager.start(makeViews())

			local mounted = {}
			local fakeButtonElement = {
				mount = function(_parent, props)
					local instance = Instance.new("ImageButton")
					instance.Name = props.name
					table.insert(created, instance)
					local handle = {
						instance = instance,
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

			local side = Instance.new("Frame")
			side.Name = "Side"
			table.insert(created, side)

			SidebarController.start(side, {
				buttonElement = fakeButtonElement,
			})

			local entries = sidebarMenus()
			local first = entries[1]

			expect(#mounted).to.equal(#entries)
			local mountedByName = {}
			for _, handle in mounted do
				mountedByName[handle.instance.Name] = handle
				expect(handle.instance:IsA("ImageButton")).to.equal(true)
			end
			expect(mountedByName.QuestsButton).to.be.ok()
			expect(mountedByName.ShopButton).to.be.ok()
			expect(mountedByName.InventoryButton).to.be.ok()

			expect(mounted[1].props.text).to.equal(first.definition.label or first.definition.id)
			expect(mounted[1].props.layoutOrder).to.equal(first.definition.sidebarOrder)

			mounted[1].props.activated()
			expect(MenuManager.getOpenMenu()).to.equal(first.id)
			expect(mounted[1].selected).to.equal(true)

			mounted[1].props.activated()
			expect(MenuManager.getOpenMenu()).never.to.be.ok()
			expect(mounted[1].selected).to.equal(false)

			SidebarController._resetForTest()
			expect(mounted[1].destroyed).to.equal(true)
		end)

		it("keeps exactly one sidebar button selected across switches", function()
			MenuManager.start(makeViews())

			local mounted = {}
			SidebarController.start(Instance.new("Frame"), {
				buttonElement = {
					mount = function(_parent, props)
						local handle = {
							props = props,
							selected = props.selected == true,
							instance = { Name = props.name },
						}
						function handle:setSelected(selected: boolean)
							self.selected = selected
						end
						function handle:setEnabled(_enabled: boolean) end
						function handle:add(cleanup)
							return cleanup
						end
						function handle:destroy() end
						function handle:isDestroyed()
							return false
						end
						table.insert(mounted, handle)
						return handle
					end,
				},
			})

			local entries = sidebarMenus()
			if #entries < 2 then
				return
			end

			mounted[1].props.activated()
			mounted[2].props.activated()

			local selectedCount = 0
			for _, handle in mounted do
				if handle.selected then
					selectedCount += 1
				end
			end
			expect(selectedCount).to.equal(1)
			expect(mounted[2].selected).to.equal(true)
		end)
	end)
end
