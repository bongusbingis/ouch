-- Description: Spec for the live config allowlist: every key names a real config leaf with a usable range, projects onto a distinct attribute name within the length limit, and stays within the cloud key limit.

--!strict

local T = require(script.Parent.TestKit)
local LiveConfig = require(script.Parent.Parent.Parent.Config.LiveConfig)
local ConfigOverrides = require(script.Parent.Parent.Game.Config.ConfigOverrides)

T.describe("LiveConfig registry", function()
	T.it("declares a module, a leaf path, and a usable range for every key", function()
		for _, entry in LiveConfig.Entries do
			local moduleName, path = ConfigOverrides.parseKey(entry.Key)
			T.expect(moduleName):toBeTruthy()
			T.expect(#(path :: { string }) > 0):toBeTruthy()
			if entry.Minimum and entry.Maximum then
				T.expect(entry.Minimum <= entry.Maximum):toBeTruthy()
			end
		end
	end)

	T.it("projects every key onto a distinct attribute name within the length limit", function()
		local seen: { [string]: string } = {}
		for _, entry in LiveConfig.Entries do
			local name = ConfigOverrides.projectedName(entry.Key)
			T.expect(string.find(name, ".", 1, true)):toBeNil()
			T.expect(#name <= 50):toBeTruthy()
			T.expect(seen[name]):toBeNil()
			seen[name] = entry.Key
		end
	end)

	T.it("points every key at a config leaf that actually exists", function()
		local modules = LiveConfig.loadModules("arena")
		for _, entry in LiveConfig.Entries do
			local moduleName, path = ConfigOverrides.parseKey(entry.Key)
			if moduleName == "Matchmaking" then
				continue
			end
			T.expect(modules[moduleName]):toBeTruthy()
			local leaf = ConfigOverrides.readPath(modules[moduleName], path :: { string })
			T.expect(leaf ~= nil):toBeTruthy()
			T.expect(typeof(leaf)):toEqual(entry.Type)
		end
	end)

	T.it("preserves each place's override scope with unique ordered module names", function()
		T.expect(table.concat(LiveConfig.moduleNames("arena"), ","))
			:toEqual("AimAssist,Combat,Crates,GameModes,MapFeatures,Modes,Shop")
		T.expect(table.concat(LiveConfig.moduleNames("lobby"), ",")):toEqual("Crates,GameModes,Matchmaking,Shop")
		T.expect(#LiveConfig.moduleNames()):toEqual(8)
	end)

	T.it("stays within the Open Cloud repository key limit", function()
		T.expect(#LiveConfig.Entries <= 100):toBeTruthy()
	end)
end)

return true
