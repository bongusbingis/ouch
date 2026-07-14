--!strict

local T = require(script.Parent.TestKit)

local Client = script.Parent.Parent.Parent.Parent.StarterPlayer.StarterPlayerScripts.Client
local QuestsController = require(Client.Modules.UI.QuestsController)

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

T.describe("QuestsController", function()
	T.it("renders state, routes claim, and updates reset text", function()
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
			holder = holder :: any,
			resetsIn = resetsIn :: any,
		})

		T.expect(#mounted):toEqual(0)
		T.expect(resetsIn.Text):toEqual("Quests reset in: 00:00:00")

		isOpen = true
		menuCallbacks[1]("Quests")

		T.expect(#mounted):toEqual(3)
		T.expect(mounted[1].props.data.questId):toEqual("first")
		T.expect(mounted[2].props.data.questId):toEqual("second")
		T.expect(mounted[3].props.data.questId):toEqual("third")

		mounted[1].props.claim("first")
		T.expect(calls[#calls].name):toEqual("ClaimQuest")
		T.expect(calls[#calls].args[1]):toEqual("first")
		T.expect(#mounted):toEqual(6)

		isOpen = false
		menuCallbacks[1](nil)
		T.expect(mounted[4].destroyed):toEqual(true)
		T.expect(mounted[5].destroyed):toEqual(true)
		T.expect(mounted[6].destroyed):toEqual(true)

		callbacks.QuestStateChanged({
			dailyKey = "2026-07-13",
			resetAt = os.time(),
			quests = { quest("fresh", 1) },
		})
		T.expect(#mounted):toEqual(6)

		isOpen = true
		menuCallbacks[1]("Quests")
		T.expect(#mounted):toEqual(7)
		T.expect(mounted[7].props.data.questId):toEqual("fresh")

		QuestsController._resetForTest()
	end)
end)

return true
