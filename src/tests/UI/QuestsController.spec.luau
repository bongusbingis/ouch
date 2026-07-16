--!nonstrict
-- Cloud port of the QuestsController spec: lazy render on menu open, slot
-- ordering, claim routing, remount on state change, and cleanup on close.
-- Network, card element, and menu manager stay injected doubles — client
-- networking cannot be emulated in the cloud environment.

local StarterPlayer = game:GetService("StarterPlayer")

local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local QuestsController = require(Client:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("QuestsController"))

local function quest(questId: string, slot: number)
	return {
		slot = slot,
		questId = questId,
		title = questId,
		progress = 0,
		goal = 1,
		steps = 1,
		claimed = false,
		completed = false,
		reward = { kind = "Cash", amount = 10 },
	}
end

return function()
	describe("QuestsController", function()
		afterEach(function()
			QuestsController._resetForTest()
		end)

		it("renders state, routes claim, and updates reset text", function()
			QuestsController._resetForTest()

			local state = {
				dailyKey = "2026-07-13",
				resetAt = os.time(),
				quests = {
					quest("third", 3),
					quest("first", 1),
					quest("second", 2),
				},
			}
			local callbacks = {}
			local calls = {}
			local network = {
				on = function(name, callback)
					callbacks[name] = callback
				end,
				call = function(name, ...)
					table.insert(calls, { name = name, args = { ... } })
					if name == "GetQuestState" then
						return state
					end
					return true, state
				end,
			}
			local mounted = {}
			local cardElement = {
				mount = function(parent, props)
					table.insert(mounted, {
						parent = parent,
						props = props,
						destroyed = false,
					})
					local handle = mounted[#mounted]
					function handle:destroy()
						self.destroyed = true
					end
					return handle
				end,
			}
			local holder = { Name = "Holder" }
			local resetsIn = { Text = "" }
			local menuCallbacks = {}
			local isOpen = false
			local menuManager = {
				isOpen = function(menuId)
					return isOpen and menuId == "Quests"
				end,
				onChanged = function(callback)
					table.insert(menuCallbacks, callback)
					return function() end
				end,
			}

			QuestsController.start({
				network = network,
				cardElement = cardElement,
				menuManager = menuManager,
				holder = holder,
				resetsIn = resetsIn,
			})

			expect(#mounted).to.equal(0)
			expect(resetsIn.Text).to.equal("Quests reset in: 00:00:00")

			isOpen = true
			menuCallbacks[1]("Quests")

			expect(#mounted).to.equal(3)
			expect(mounted[1].props.data.questId).to.equal("first")
			expect(mounted[2].props.data.questId).to.equal("second")
			expect(mounted[3].props.data.questId).to.equal("third")

			mounted[1].props.claim("first")
			expect(calls[#calls].name).to.equal("ClaimQuest")
			expect(calls[#calls].args[1]).to.equal("first")
			expect(#mounted).to.equal(6)

			isOpen = false
			menuCallbacks[1](nil)
			expect(mounted[4].destroyed).to.equal(true)
			expect(mounted[5].destroyed).to.equal(true)
			expect(mounted[6].destroyed).to.equal(true)

			callbacks.QuestStateChanged({
				dailyKey = "2026-07-13",
				resetAt = os.time(),
				quests = { quest("fresh", 1) },
			})
			expect(#mounted).to.equal(6)

			isOpen = true
			menuCallbacks[1]("Quests")
			expect(#mounted).to.equal(7)
			expect(mounted[7].props.data.questId).to.equal("fresh")
		end)
	end)
end
