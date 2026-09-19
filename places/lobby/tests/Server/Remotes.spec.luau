-- Description: In-place spec that the lobby's party remotes are materialized with their declared classes at startup.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EXPECTED_REMOTES = {
	PartyRequest = "RemoteFunction",
	PartyPacket = "RemoteEvent",
	TeleportPresentationReady = "RemoteEvent",
	TeleportStatus = "RemoteEvent",
}

return function()
	describe("Lobby remotes", function()
		it("materializes the party remotes with their declared classes", function()
			if not RunService:IsServer() then
				return
			end
			local folder = ReplicatedStorage:FindFirstChild("Remotes")
			if not folder then
				require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
				folder = ReplicatedStorage:WaitForChild("Remotes", 5)
			end
			expect(folder).to.be.ok()

			for name, className in EXPECTED_REMOTES do
				local remote = (folder :: Folder):FindFirstChild(name)
				expect(remote).to.be.ok()
				expect((remote :: Instance):IsA(className)).to.equal(true)
			end
		end)
	end)
end
