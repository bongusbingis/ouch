-- Receipt acknowledgement reads the saved profile snapshot, never the mutable grant marker alone.
--!nonstrict

local PlayerData = require(
	game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("PlayerData")
)

return function()
	describe("Receipt persistence", function()
		local player = { UserId = -772001 }
		afterEach(function()
			PlayerData._profiles[player.UserId] = nil
		end)

		it("waits for the receipt to appear in LastSavedData", function()
			local profile = { Data = { Receipts = { purchase = 1 } }, LastSavedData = { Receipts = {} } }
			profile.IsActive = function()
				return true
			end
			profile.Save = function()
				task.defer(function()
					profile.LastSavedData = { Receipts = { purchase = 1 } }
				end)
			end
			PlayerData._profiles[player.UserId] = { Profile = profile }
			expect(PlayerData.confirmReceiptSaved(player, "purchase")).to.equal(true)
			expect(profile.LastSavedData.Receipts.purchase).to.equal(1)
		end)

		it("leaves an unsaved grant unacknowledged after session loss", function()
			local profile = {
				Data = { Receipts = { purchase = 1 } },
				LastSavedData = { Receipts = {} },
				IsActive = function()
					return false
				end,
				Save = function()
					error("inactive profile must not be saved")
				end,
			}
			PlayerData._profiles[player.UserId] = { Profile = profile }
			expect(PlayerData.confirmReceiptSaved(player, "purchase")).to.equal(false)
		end)
	end)
end
