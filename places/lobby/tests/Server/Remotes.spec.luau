-- Description: In-place spec that the lobby's party remotes are materialized with their declared classes at startup.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EXPECTED_REMOTES = {
	PartyRequest = "RemoteFunction",
	PartyPacket = "RemoteEvent",
	TeleportPresentationReady = "RemoteEvent",
	TeleportStatus = "RemoteEvent",
}

return function()
	describe("Lobby remotes", function()
		it("materializes the party remotes with their declared classes", function()
			local folder = ReplicatedStorage:FindFirstChild("Remotes")
			if not folder then
				pcall(function()
					require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
				end)
				folder = ReplicatedStorage:WaitForChild("Remotes", 3)
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
