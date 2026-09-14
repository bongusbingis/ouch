-- Name: ModeBallSupply.spec.luau
-- Author: Jack C.
-- Description: Spec for what each mode hands a player on spawn, and for Infection scoring both sides by headcount instead of by eliminations.
-- Created: 2026-09-12

--!strict

local T = require(script.Parent.TestKit)
local ModeRegistry = require(script.Parent.Parent.Game.Modes.ModeRegistry)
local Infection = require(script.Parent.Parent.Game.Modes.Infection)

type Fake = {
	ctx: any,
	granted: { [string]: number },
	players: { any },
}

local function fake(names: { string }): Fake
	local granted: { [string]: number } = {}
	local teams: { [string]: string? } = {}
	local players = {}
	for _, name in names do
		granted[name] = 0
		table.insert(players, { Name = name })
	end
	local ctx = {
		balls = {
			grantHeldBall = function(player: any)
				granted[player.Name] += 1
				return true
			end,
			clearAll = function() end,
		},
		getPlayers = function()
			return players
		end,
		getPlayerTeam = function(player: any)
			return teams[player.Name]
		end,
		getPlayerById = function()
			return nil
		end,
		setPlayerTeam = function(player: any, teamId: string?)
			teams[player.Name] = teamId
		end,
		finishMatch = function() end,
	}
	return { ctx = ctx, granted = granted, players = players }
end

-- Infection picks patient zero through a live Random, which the headless loader
-- has no answer for, so it is started through its injected-chooser seam instead.
local function startMatch(mode: any, ctx: any)
	if mode.id == "Infection" then
		Infection.assignSides(ctx, function()
			return 1
		end)
	else
		mode.onMatchStart(ctx)
	end
end

T.describe("Mode ball supply", function()
	T.it("arms every player at the start of a match", function()
		for _, mode in ModeRegistry.all() do
			local harness = fake({ "a", "b", "c" })
			startMatch(mode, harness.ctx)
			for _, player in harness.players do
				T.expect(harness.granted[player.Name] >= 1):toBeTruthy()
			end
		end
	end)

	T.it("arms a player on a later spawn, not only their first", function()
		for _, mode in ModeRegistry.all() do
			local harness = fake({ "a", "b" })
			startMatch(mode, harness.ctx)
			local before = harness.granted.a
			mode.onPlayerSpawned(harness.ctx, harness.players[1] :: any, false)
			T.expect(harness.granted.a > before):toBeTruthy()
		end
	end)

	T.it("arms patient zero, who has to start the chain", function()
		local harness = fake({ "a", "b", "c", "d" })
		Infection.assignSides(harness.ctx, function()
			return 2
		end)
		local infected = nil
		for _, player in harness.players do
			if harness.ctx.getPlayerTeam(player) == Infection.InfectedTeam then
				infected = player
			end
		end
		T.expect(infected ~= nil):toBeTruthy()
		T.expect(harness.granted[(infected :: any).Name] >= 1):toBeTruthy()
	end)
end)

T.describe("Infection scoring", function()
	T.it("scores each side by how many players are on it", function()
		local harness = fake({ "a", "b", "c", "d" })
		Infection.assignSides(harness.ctx, function()
			return 1
		end)
		local survivors = Infection.teamScore(harness.ctx, Infection.SurvivorTeam)
		local infected = Infection.teamScore(harness.ctx, Infection.InfectedTeam)
		T.expect(infected):toEqual(1)
		T.expect(survivors):toEqual(3)
		T.expect(survivors + infected):toEqual(#harness.players)
	end)

	T.it("moves the score when a survivor is converted, and not when one is merely bonked", function()
		local harness = fake({ "a", "b", "c" })
		Infection.assignSides(harness.ctx, function()
			return 1
		end)
		local before = Infection.teamScore(harness.ctx, Infection.SurvivorTeam)

		-- A survivor knocking an infected player down changes no side, which is
		-- exactly why it must not move the scoreboard either.
		T.expect(Infection.isConversion(Infection.SurvivorTeam, Infection.InfectedTeam)):toEqual(false)
		T.expect(Infection.teamScore(harness.ctx, Infection.SurvivorTeam)):toEqual(before)

		for _, player in harness.players do
			if harness.ctx.getPlayerTeam(player) == Infection.SurvivorTeam then
				harness.ctx.setPlayerTeam(player, Infection.InfectedTeam)
				break
			end
		end
		T.expect(Infection.teamScore(harness.ctx, Infection.SurvivorTeam)):toEqual(before - 1)
	end)

	T.it("owns its scoreboard, so eliminations are not counted into it", function()
		T.expect(Infection.teamScore ~= nil):toBeTruthy()
		for _, mode in ModeRegistry.all() do
			if mode.id ~= "Infection" then
				T.expect(mode.teamScore):toBeNil()
			end
		end
	end)
end)

return true
