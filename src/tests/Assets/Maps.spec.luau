--!nonstrict
-- Validates every enabled map in Config.Maps.Pool against the authored assets under
-- ReplicatedStorage.Assets.Maps: the Scriptables hierarchy MapService clones
-- and flattens must exist with populated spawn pools.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Maps = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Maps"))
local TestAssets = require(ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers"):WaitForChild("TestAssets"))

local function basePartCount(folder: Instance): number
	local count = 0
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

return function()
	describe("Map assets", function()
		it("has a non-empty pool", function()
			expect(#Maps.Pool > 0).to.equal(true)
		end)

		it("has unique map ids", function()
			local seen = {}
			for _, entry in Maps.Pool do
				if not entry.Enabled then
					continue
				end
				expect(seen[entry.Id]).never.to.be.ok()
				seen[entry.Id] = true
			end
		end)

		it("authors every enabled map with populated spawn pools", function()
			for _, entry in Maps.Pool do
				if not entry.Enabled then
					continue
				end
				local map = TestAssets.get(ReplicatedStorage, "Assets", "Maps", entry.AssetName)
				local scriptables = TestAssets.get(map, "Scriptables")

				local ballSpawns = TestAssets.get(scriptables, "BallSpawns")
				local playerSpawns = TestAssets.get(scriptables, "PlayerSpawns")
				expect(basePartCount(ballSpawns) > 0).to.equal(true)
				expect(basePartCount(playerSpawns) > 0).to.equal(true)

				-- BouncePads/FoamPits are optional, but when authored they must
				-- contain parts (MapFeatureService iterates direct BasePart children).
				for _, optionalName in { "BouncePads", "FoamPits" } do
					local optionalFolder = scriptables:FindFirstChild(optionalName)
					if optionalFolder then
						expect(basePartCount(optionalFolder) > 0).to.equal(true)
					end
				end
			end
		end)
	end)
end
