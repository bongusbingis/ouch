-- Only project successful public TextChannel deliveries onto party previews in this server.
--!strict

local PartyBubblePolicy = {}

function PartyBubblePolicy.senderId(message: any, publicChannel: any, characters: any, players: any): number?
	if
		publicChannel == nil
		or message.TextChannel ~= publicChannel
		or message.Status ~= Enum.TextChatMessageStatus.Success
		or message.Text == ""
		or message.TextSource == nil
	then
		return nil
	end
	local userId = message.TextSource.UserId
	if characters[userId] == nil or players:GetPlayerByUserId(userId) == nil then
		return nil
	end
	return userId
end

return table.freeze(PartyBubblePolicy)
