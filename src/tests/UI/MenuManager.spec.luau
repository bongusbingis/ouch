--!nonstrict
-- Cloud port of the MenuManager spec on real Instances: single-open invariant,
-- toggle/close semantics, missing-view isolation, and transition callbacks —
-- plus a pass over the real Studio-authored Views container. Passing a root
-- override disables animations, so views need not be CanvasGroups here.

local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local MenuManager = require(Client:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("MenuManager"))
local MenuRegistry = require(Client:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("MenuRegistry"))
local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))

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

return function()
	describe("MenuManager", function()
		local created = {}

		-- Test doubles for the views container contract (real Frames, never part
		-- of any player-facing UI); the authored container is exercised below.
		local function makeViews(omitMenuId: string?): (Folder, { [string]: Frame })
			local views = Instance.new("Folder")
			views.Name = "Views"
			table.insert(created, views)
			local byId = {}
			for _, entry in registeredMenus() do
				if entry.id ~= omitMenuId then
					local view = Instance.new("Frame")
					view.Name = entry.viewName
					view.Visible = true
					view.Parent = views
					byId[entry.id] = view
				end
			end
			return views, byId
		end

		beforeEach(function()
			MenuManager._resetForTest()
		end)

		afterEach(function()
			MenuManager._resetForTest()
			for _, instance in created do
				instance:Destroy()
			end
			table.clear(created)
		end)

		it("start hides all registered menu frames", function()
			local views, byId = makeViews()

			MenuManager.start(views)

			for _, view in byId do
				expect(view.Visible).to.equal(false)
			end
			expect(MenuManager.isOpen()).to.equal(false)
		end)

		it("opens one menu at a time", function()
			local menus = registeredMenus()
			local first = menus[1].id
			local second = if menus[2] then menus[2].id else nil
			local views, byId = makeViews()
			MenuManager.start(views)

			expect(MenuManager.open(first)).to.equal(true)
			expect(byId[first].Visible).to.equal(true)
			expect(MenuManager.getOpenMenu()).to.equal(first)

			if second then
				expect(MenuManager.open(second)).to.equal(true)
				expect(byId[first].Visible).to.equal(false)
				expect(byId[second].Visible).to.equal(true)
				expect(MenuManager.getOpenMenu()).to.equal(second)
			end
		end)

		it("opening the active menu toggles it closed", function()
			local first = registeredMenus()[1].id
			local views, byId = makeViews()
			MenuManager.start(views)

			expect(MenuManager.open(first)).to.equal(true)
			expect(MenuManager.open(first)).to.equal(false)

			expect(byId[first].Visible).to.equal(false)
			expect(MenuManager.getOpenMenu()).never.to.be.ok()
		end)

		it("close is idempotent", function()
			local first = registeredMenus()[1].id
			local views, byId = makeViews()
			MenuManager.start(views)

			expect(MenuManager.close()).to.equal(false)
			MenuManager.open(first)
			expect(MenuManager.close()).to.equal(true)
			expect(MenuManager.close()).to.equal(false)
			expect(byId[first].Visible).to.equal(false)
		end)

		it("missing registered views fail without corrupting state", function()
			local menus = registeredMenus()
			local first = menus[1].id
			local missing = if menus[2] then menus[2].id else first
			local views, byId = makeViews(missing)
			MenuManager.start(views)

			if missing ~= first then
				expect(MenuManager.open(first)).to.equal(true)
				expect(MenuManager.open(missing)).to.equal(false)

				expect(byId[first].Visible).to.equal(true)
				expect(MenuManager.getOpenMenu()).to.equal(first)
			else
				expect(MenuManager.open(first)).to.equal(false)
				expect(MenuManager.getOpenMenu()).never.to.be.ok()
			end
		end)

		it("onChanged fires once for each real transition", function()
			local menus = registeredMenus()
			local first = menus[1].id
			local second = if menus[2] then menus[2].id else nil
			local views = makeViews()
			MenuManager.start(views)
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

			expect(#events).to.equal(if second then 3 else 2)
			expect(events[1].newMenu).to.equal(first)
			expect(events[1].oldMenu).never.to.be.ok()
			if second then
				expect(events[2].newMenu).to.equal(second)
				expect(events[2].oldMenu).to.equal(first)
				expect(events[2].reason).to.equal("Switch")
				expect(events[3].newMenu).never.to.be.ok()
				expect(events[3].oldMenu).to.equal(second)
				expect(events[3].reason).to.equal("Toggle")
			else
				expect(events[2].newMenu).never.to.be.ok()
				expect(events[2].oldMenu).to.equal(first)
				expect(events[2].reason).to.equal("Toggle")
			end
		end)

		it("drives the real Studio-authored Quests view", function()
			local authoredViews = TestAssets.get(StarterGui, "MainGui", "BaseClip", "Views")
			local views = authoredViews:Clone()
			table.insert(created, views)

			local questsView = views:FindFirstChild(MenuRegistry.Quests.viewName)
			assert(questsView ~= nil, "[MenuManager.spec] authored Views must contain the Quests view")
			expect(questsView:IsA("GuiObject")).to.equal(true)

			MenuManager.start(views)
			expect(questsView.Visible).to.equal(false)

			expect(MenuManager.open("Quests")).to.equal(true)
			expect(questsView.Visible).to.equal(true)
			expect(MenuManager.getOpenMenu()).to.equal("Quests")

			expect(MenuManager.close()).to.equal(true)
			expect(questsView.Visible).to.equal(false)
		end)
	end)
end
