-- Description: In-place spec that a server without a fixed-mode session keeps the arena venue standing: the venue service starts, reports Arena, leaves the authored interior in the Workspace and hears no swap.

--!nonstrict

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local VenueService = require(Modules:WaitForChild("VenueService"))

return function()
	describe("VenueService", function()
		it("keeps the arena venue when no fixed-mode session has been established", function()
			VenueService.start()
			expect(VenueService.venue()).to.equal("Arena")
			expect(VenueService.parkedInterior()).to.equal(nil)

			local arena = Workspace:FindFirstChild("Assets") and Workspace.Assets:FindFirstChild("Arena")
			expect(arena).to.be.ok()
			expect(arena:FindFirstChild("Scriptables")).to.be.ok()
			expect(arena:FindFirstChild("PlayerSpawns")).to.be.ok()
			expect(arena:GetAttribute("Venue")).never.to.equal("Splashdown")

			local heard = 0
			local disconnect = VenueService.onChanged(function()
				heard += 1
			end)
			expect(heard).to.equal(0)
			disconnect()
		end)
	end)
end
