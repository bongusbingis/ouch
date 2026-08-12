--!strict

local T = require(script.Parent.TestKit)
local ProfileMigrations = require(script.Parent.Parent.Game.Data.ProfileMigrations)
local DataConfig = require(script.Parent.Parent.Parent.Config.Data)

local function migrations(): { any }
	return {
		{
			version = 1,
			apply = function(data)
				data.a = (data.a or 0) + 1
			end,
		},
		{
			version = 2,
			apply = function(data)
				data.b = (data.b or 0) + 1
			end,
		},
		{
			version = 3,
			apply = function(data)
				data.c = (data.c or 0) + 1
			end,
		},
	}
end

T.describe("ProfileMigrations", function()
	T.it("runs every pending step in order and records the version reached", function()
		local list = migrations()
		local data = {}
		local ok, reached = ProfileMigrations.apply(data, 3, list)
		T.expect(ok):toEqual(true)
		T.expect(reached):toEqual(3)
		T.expect(data.SchemaVersion):toEqual(3)
		T.expect(data.a):toEqual(1)
		T.expect(data.b):toEqual(1)
		T.expect(data.c):toEqual(1)
	end)

	T.it("skips steps the profile has already passed", function()
		local list = migrations()
		local data = { SchemaVersion = 2 }
		ProfileMigrations.apply(data, 3, list)
		T.expect(data.a):toBeNil()
		T.expect(data.b):toBeNil()
		T.expect(data.c):toEqual(1)
	end)

	T.it("is a no-op when already at the target", function()
		local list = migrations()
		local data = { SchemaVersion = 3 }
		local ok, reached = ProfileMigrations.apply(data, 3, list)
		T.expect(ok):toEqual(true)
		T.expect(reached):toEqual(3)
		T.expect(data.a):toBeNil()
	end)

	T.it("never migrates downward, so an old server cannot destroy newer data", function()
		local list = migrations()
		local data = { SchemaVersion = 5, keep = true }
		local ok, reached = ProfileMigrations.apply(data, 3, list)
		T.expect(ok):toEqual(true)
		T.expect(reached):toEqual(5)
		T.expect(data.SchemaVersion):toEqual(5)
		T.expect(data.keep):toEqual(true)
	end)

	T.it("stops at the last completed version when a step throws", function()
		local list = migrations()
		list[2].apply = function()
			error("boom")
		end
		local data = {}
		local ok, reached, err = ProfileMigrations.apply(data, 3, list)
		T.expect(ok):toEqual(false)
		T.expect(reached):toEqual(1)
		T.expect(data.SchemaVersion):toEqual(1)
		T.expect(err ~= nil):toBeTruthy()
		-- The step after the failure must not have run.
		T.expect(data.c):toBeNil()
	end)

	T.it("resumes from the recorded version after a failure", function()
		local list = migrations()
		local shouldFail = true
		list[2].apply = function(data)
			if shouldFail then
				error("boom")
			end
			data.b = (data.b or 0) + 1
		end
		local data = {}
		ProfileMigrations.apply(data, 3, list)
		T.expect(data.SchemaVersion):toEqual(1)

		shouldFail = false
		local ok = ProfileMigrations.apply(data, 3, list)
		T.expect(ok):toEqual(true)
		T.expect(data.SchemaVersion):toEqual(3)
		-- Version 1 must not have run twice.
		T.expect(data.a):toEqual(1)
		T.expect(data.b):toEqual(1)
	end)

	T.it("keeps steps idempotent when the same version is applied twice", function()
		local list = migrations()
		local data = {}
		ProfileMigrations.apply(data, 1, list)
		ProfileMigrations.apply(data, 1, list)
		T.expect(data.a):toEqual(1)
	end)

	T.it("ships a template sentinel below the configured target", function()
		-- If the template carried the target, Reconcile would back-fill legacy
		-- profiles to it and every migration would be skipped forever.
		T.expect(DataConfig.Template.SchemaVersion):toEqual(0)
		T.expect(DataConfig.SchemaVersion >= 1):toBeTruthy()
		T.expect(ProfileMigrations.targetVersion()):toEqual(DataConfig.SchemaVersion)
	end)

	T.it("numbers shipped migrations contiguously from one", function()
		for index, migration in ProfileMigrations.List do
			T.expect(migration.version):toEqual(index)
		end
	end)
end)

return true
