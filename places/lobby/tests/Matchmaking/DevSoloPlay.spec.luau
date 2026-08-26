-- Name: DevSoloPlay.spec.luau
-- Author: Jack C.
-- Description: In-place spec that the developer solo-play gate admits only sufficiently ranked group members and rejects players whose rank cannot be read.
-- Created: 2026-08-20

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevSoloPlay =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("DevSoloPlay"))

local function rankPlayer(rank: number)
	return {
		GetRankInGroup = function(_self, groupId: number)
			expect(groupId).to.equal(291738800)
			return rank
		end,
	}
end

local function brokenPlayer()
	return {
		GetRankInGroup = function()
			error("group unavailable")
		end,
	}
end

return function()
	describe("Dev solo play gate", function()
		it("allows only rank 254+ in the configured group", function()
			expect(DevSoloPlay.canUse(rankPlayer(254))).to.equal(true)
			expect(DevSoloPlay.canUse(rankPlayer(300))).to.equal(true)
			expect(DevSoloPlay.canUse(rankPlayer(253))).to.equal(false)
		end)

		it("rejects players that cannot report a group rank", function()
			expect(DevSoloPlay.canUse(brokenPlayer())).to.equal(false)
			expect(DevSoloPlay.canUse({})).to.equal(false)
		end)
	end)
end
