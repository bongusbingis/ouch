-- The rendered claim callback must use the server's public quest identity.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestLogic = require(ReplicatedStorage.Shared.Game.Quests.QuestLogic)
local Quests = require(ReplicatedStorage.Config.Progression.Quests)
local Panel = require(ReplicatedStorage.Shared.UI.Components.QuestsPanel)

return function()
	describe("Quest panel contract", function()
		it("claims the public quest ID and projects its pending state", function()
			local definition = Quests.Definitions[1]
			local quest = QuestLogic.publicQuest(definition, { progress = definition.goal, claimed = false }, 1)
			local received = nil
			local element = Panel({
				State = { quests = { quest } },
				PendingClaims = { [quest.questId] = true },
				OnClaim = function(id)
					received = id
				end,
			})
			local row = element.props.children.QuestList.props.children.Quest1
			expect(row.props.Pending).to.equal(true)
			local rendered = row.type(row.props)
			local button = rendered.props.children.RightSection.props.children.ClaimButton
			expect(button.props.Enabled).to.equal(false)
			button.props.OnActivated()
			expect(received).to.equal(definition.id)
		end)
	end)
end
