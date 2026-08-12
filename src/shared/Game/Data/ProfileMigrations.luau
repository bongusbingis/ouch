--!strict

-- Ordered, idempotent profile migrations.
--
-- The template deliberately holds SchemaVersion = 0 as a sentinel and the real
-- target lives in Config.Data.SchemaVersion. Putting the target in the template
-- would let ProfileStore's Reconcile back-fill legacy profiles straight to it,
-- silently skipping every migration forever.
--
-- Each step must be idempotent: a crash part-way leaves the profile at the last
-- completed version, so the failed step re-runs on the next join.

local ProfileMigrations = {}

export type Migration = {
	version: number,
	apply: (data: any) -> (),
}

-- Version 1 exists to exercise the mechanism while every field added so far is
-- additive and handled by Reconcile. Real reshaping work starts at version 2.
local List: { Migration } = {
	{
		version = 1,
		apply = function(_data) end,
	},
}

ProfileMigrations.List = List

function ProfileMigrations.targetVersion(): number
	return #List
end

function ProfileMigrations.pending(current: number, target: number, list: { Migration }?): { Migration }
	local steps = {}
	for _, migration in list or List do
		if migration.version > current and migration.version <= target then
			table.insert(steps, migration)
		end
	end
	table.sort(steps, function(left, right)
		return left.version < right.version
	end)
	return steps
end

-- Returns whether every pending step succeeded, plus the version actually
-- reached. A profile already ahead of the target is left untouched: during a
-- rolling deploy an old server will see profiles written by a newer one, and
-- down-migrating would destroy data the newer build depends on.
function ProfileMigrations.apply(data: any, target: number, list: { Migration }?): (boolean, number, string?)
	local current = data.SchemaVersion or 0
	if current >= target then
		return true, current, nil
	end

	for _, migration in ProfileMigrations.pending(current, target, list) do
		local ok, err = pcall(migration.apply, data)
		if not ok then
			return false, current, tostring(err)
		end
		current = migration.version
		data.SchemaVersion = current
	end
	return true, current, nil
end

return ProfileMigrations
