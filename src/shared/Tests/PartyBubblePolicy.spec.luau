--!strict

local T = require(script.Parent.TestKit)
local Policy = require(script.Parent.Parent.UI.Models.PartyBubblePolicy)

T.describe("PartyBubblePolicy", function()
	local publicChannel = {}
	local characters = { [10] = {}, [20] = {} }
	local players = {
		GetPlayerByUserId = function(_self, userId)
			return if userId == 10 or userId == 30 then {} else nil
		end,
	}
	local function delivered(overrides)
		local message = {
			TextChannel = publicChannel,
			Status = Enum.TextChatMessageStatus.Success,
			Text = "viewer-filtered text",
			TextSource = { UserId = 10 },
		}
		for key, value in overrides or {} do
			message[key] = value
		end
		return message
	end

	T.it("accepts a delivered public message from a party member in this server", function()
		T.expect(Policy.senderId(delivered(), publicChannel, characters, players)):toEqual(10)
	end)
	T.it("rejects a party preview whose player is in another server", function()
		T.expect(Policy.senderId(delivered({ TextSource = { UserId = 20 } }), publicChannel, characters, players))
			:toBeNil()
	end)
	T.it("rejects a server player outside the party", function()
		T.expect(Policy.senderId(delivered({ TextSource = { UserId = 30 } }), publicChannel, characters, players))
			:toBeNil()
	end)
	T.it("does not expose whisper, team, global, or other channels on the party stage", function()
		for _, name in { "RBXWhisper:10_20", "RBXTeam", "RBXGlobal", "Custom" } do
			T.expect(Policy.senderId(delivered({ TextChannel = { Name = name } }), publicChannel, characters, players))
				:toBeNil()
		end
	end)
	T.it("rejects unconfirmed, failed, empty, and system messages", function()
		for _, status in
			{
				Enum.TextChatMessageStatus.Sending,
				Enum.TextChatMessageStatus.TextFilterFailed,
				Enum.TextChatMessageStatus.InvalidPrivacySettings,
			}
		do
			T.expect(Policy.senderId(delivered({ Status = status }), publicChannel, characters, players)):toBeNil()
		end
		T.expect(Policy.senderId(delivered({ Text = "" }), publicChannel, characters, players)):toBeNil()
		local system = delivered()
		system.TextSource = nil
		T.expect(Policy.senderId(system, publicChannel, characters, players)):toBeNil()
		T.expect(Policy.senderId(delivered(), nil, characters, players)):toBeNil()
	end)
end)

return true
