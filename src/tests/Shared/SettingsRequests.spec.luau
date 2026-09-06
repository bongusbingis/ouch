--!nonstrict

local Game = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Game")
local SettingsStore = require(Game.Settings.SettingsStore)

local function fixture(call)
	local onNew
	local profile = { Data = { Settings = { CameraShake = true } } }
	profile.OnChange = function()
		return { Disconnect = function() end }
	end
	SettingsStore.start({
		replica = {
			OnNew = function(_token, callback)
				onNew = callback
				return { Disconnect = function() end }
			end,
		},
		network = { call = call },
	})
	return function()
		onNew(profile)
	end
end

return function()
	describe("Settings acknowledgements", function()
		afterEach(SettingsStore.stop)
		it("notifies consumers when persisted settings arrive", function()
			local arrive = fixture(function() end)
			local count = 0
			SettingsStore.subscribe(function()
				count += 1
			end)
			arrive()
			expect(count > 0).to.equal(true)
		end)
		it("restores the persisted value when the server rejects a write", function()
			fixture(function()
				return false, "no_profile"
			end)()
			SettingsStore.set("CameraShake", false)
			SettingsStore.commit("CameraShake")
			task.wait(0.1)
			expect(SettingsStore.get("CameraShake")).to.equal(true)
			expect(SettingsStore.status("CameraShake")).to.equal("failed")
		end)
		it("serializes rapid commits and keeps the newest accepted value", function()
			local calls = {}
			fixture(function(name, id, value)
				expect(name).to.equal("SetClientSettingRequest")
				expect(id).to.equal("CameraShake")
				table.insert(calls, value)
				task.wait(0.05)
				return true, nil, value
			end)()
			SettingsStore.set("CameraShake", false)
			SettingsStore.commit("CameraShake")
			SettingsStore.set("CameraShake", true)
			SettingsStore.commit("CameraShake")
			task.wait(0.2)
			expect(#calls).to.equal(2)
			expect(SettingsStore.get("CameraShake")).to.equal(true)
			expect(SettingsStore.status("CameraShake")).to.equal(nil)
		end)
		it("ignores acknowledgement after the store stops", function()
			fixture(function()
				task.wait(0.05)
				return true, nil, false
			end)()
			SettingsStore.set("CameraShake", false)
			SettingsStore.commit("CameraShake")
			SettingsStore.stop()
			task.wait(0.1)
			expect(SettingsStore.get("CameraShake")).to.equal(true)
		end)
	end)
end
