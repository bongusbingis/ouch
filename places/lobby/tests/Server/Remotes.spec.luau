--!strict
-- The lobby client cannot talk to the server without these, and they are created
-- by the shared Network module at startup rather than authored in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EXPECTED_REMOTES = {
	PartyRequest = "RemoteFunction",
	PartyPacket = "RemoteEvent",
}

return function()
	describe("Lobby remotes", function()
		it("materializes the party remotes with their declared classes", function()
			local folder = ReplicatedStorage:FindFirstChild("Remotes")
			-- If the test environment hasn't run server startup code that
			-- requires the shared Network module, require it here so the
			-- remotes folder is materialized. This keeps the spec robust in
			-- cloud/headless runs.
			if not folder then
				pcall(function()
					require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
				end)
				folder = ReplicatedStorage:FindFirstChild("Remotes")
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
