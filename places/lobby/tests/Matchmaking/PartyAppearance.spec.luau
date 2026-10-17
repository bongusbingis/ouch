--!nonstrict

local Modules = game:GetService("ServerScriptService").Server.Modules.Matchmaking
local PartyService = require(Modules.PartyService)
local PartyModel = require(Modules.PartyModel)

return function()
	describe("Party appearance projection", function()
		it("updates color and complete costume together and rejects stale member updates", function()
			local players = {}
			local attributes = { Equip_CharacterColor = "CharacterColorBlue", Equip_CostumeAssets = "RainHopper" }
			local player = {
				UserId = 10,
				Parent = players,
				GetAttribute = function(_self, name)
					return attributes[name]
				end,
			}
			local record = {
				partyId = "party",
				revision = 1,
				members = { { userId = 10 }, { userId = 20, costumeId = "FoamLeague" } },
			}
			local repository = {
				UpdateParty = function(_self, _id, transform)
					local nextRecord = transform(record)
					if nextRecord then
						record = nextRecord
					end
					return nextRecord
				end,
			}
			local service = PartyService.new(repository, {}, {}, {}, {}, {}, { players = players })
			service._localPartyByUser[10] = "party"
			service._appearanceRevisions[10] = 1
			local notifications = 0
			service.NotifyCommitted = function()
				notifications += 1
			end
			service:_syncMemberAppearance(player, 1)
			expect(record.members[1].characterColorId).to.equal("CharacterColorBlue")
			expect(record.members[1].costumeId).to.equal("RainHopper")
			expect(record.members[2].costumeId).to.equal("FoamLeague")
			local snapshot = PartyModel.toSnapshot(record)
			snapshot.members[1].costumeId = "Changed"
			expect(record.members[1].costumeId).to.equal("RainHopper")
			service:_syncMemberAppearance(player, 1)
			expect(notifications).to.equal(1)
			service._appearanceRevisions[10] = 2
			attributes.Equip_CostumeAssets = ""
			service:_syncMemberAppearance(player, 1)
			expect(record.members[1].costumeId).to.equal("RainHopper")
			service:_syncMemberAppearance(player, 2)
			expect(record.members[1].costumeId).to.equal("")
			expect(notifications).to.equal(2)
		end)
	end)
end
