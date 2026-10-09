--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Audio = require(ReplicatedStorage.Config.Infra.Audio)
local GameAudio = require(StarterPlayer.StarterPlayerScripts.Client.Modules.Presentation.GameAudio)

return function()
	describe("GameAudio required cue validation", function()
		local original: any

		beforeEach(function()
			original = Audio.Gameplay.CB051TestCue
		end)

		afterEach(function()
			Audio.Gameplay.CB051TestCue = original
		end)

		it("rejects a missing named cue with its config path", function()
			Audio.Gameplay.CB051TestCue = nil
			local ok, err = pcall(GameAudio.play, "CB051TestCue")
			expect(ok).to.equal(false)
			expect(string.find(tostring(err), "Config.Infra.Audio.Gameplay.CB051TestCue", 1, true) ~= nil).to.equal(
				true
			)
		end)

		it("rejects an empty asset array before playback", function()
			Audio.Gameplay.CB051TestCue = { Scope = "Local", Volume = 0.5, AssetIds = {} }
			local ok, err = pcall(GameAudio.play, "CB051TestCue")
			expect(ok).to.equal(false)
			expect(string.find(tostring(err), "Config.Infra.Audio.Gameplay.CB051TestCue.AssetIds", 1, true) ~= nil).to.equal(
				true
			)
		end)

		it("rejects a malformed member even when another asset ID is valid", function()
			Audio.Gameplay.CB051TestCue = { Scope = "Local", Volume = 0.5, AssetIds = { "rbxassetid://1", "bad" } }
			local ok, err = pcall(GameAudio.play, "CB051TestCue")
			expect(ok).to.equal(false)
			expect(string.find(tostring(err), "Config.Infra.Audio.Gameplay.CB051TestCue.AssetIds[2]", 1, true) ~= nil).to.equal(
				true
			)
		end)

		it("rejects malformed volume before creating playback objects", function()
			Audio.Gameplay.CB051TestCue = { Scope = "World", Volume = -1, AssetIds = { "rbxassetid://1" } }
			local ok, err = pcall(GameAudio.play, "CB051TestCue", Vector3.zero)
			expect(ok).to.equal(false)
			expect(string.find(tostring(err), "Config.Infra.Audio.Gameplay.CB051TestCue.Volume", 1, true) ~= nil).to.equal(
				true
			)
		end)

		it("requires a World host after validating its cue", function()
			Audio.Gameplay.CB051TestCue = { Scope = "World", Volume = 0.5, AssetIds = { "rbxassetid://1" } }
			local ok, err = pcall(GameAudio.play, "CB051TestCue")
			expect(ok).to.equal(false)
			expect(string.find(tostring(err), "Config.Infra.Audio.Gameplay.CB051TestCue", 1, true) ~= nil).to.equal(
				true
			)
			expect(string.find(tostring(err), "World cue requires", 1, true) ~= nil).to.equal(true)
		end)
	end)
end
