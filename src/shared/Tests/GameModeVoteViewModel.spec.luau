-- Description: Spec for the mode vote view model: vote count formatting and the clamped loading-bar fraction derived from server time.

--!strict

local T = require(script.Parent.TestKit)
local GameModeVoteViewModel = require(script.Parent.Parent.UI.Models.GameModeVoteViewModel)

local MAPS = {
	Maps = {
		Bowl = {
			Enabled = true,
			DisplayName = "CANDY BOWL",
			ShortName = "BOWL",
			ThumbnailId = "rbxassetid://1",
			SortOrder = 1,
			Accent = "Pink",
		},
		SecondMap = {
			Enabled = true,
			DisplayName = "BAMBOO ISLE",
			ShortName = "ISLE",
			ThumbnailId = "",
			SortOrder = 2,
			Accent = "Lime",
		},
		Off = {
			Enabled = false,
			DisplayName = "OFF",
			ShortName = "OFF",
			ThumbnailId = "",
			SortOrder = 3,
			Accent = "Cyan",
		},
	},
}
local function accent(_key: string): Color3
	return Color3.new(1, 0, 0)
end

T.describe("GameModeVoteViewModel", function()
	T.it("describes the resolved target instead of a stale configured sentence", function()
		T.expect(GameModeVoteViewModel.description({ ScoreTarget = 24 }, true))
			:toEqual("First team to 24 eliminations wins. Parties stay together.")
	end)
	T.it("labels vote counts and handles singular votes", function()
		T.expect(GameModeVoteViewModel.formatVoteCount(0)):toEqual("0 VOTES")
		T.expect(GameModeVoteViewModel.formatVoteCount(1)):toEqual("1 VOTE")
		T.expect(GameModeVoteViewModel.formatVoteCount(20)):toEqual("20 VOTES")
	end)

	T.it("derives a clamped loading-bar fraction from server time", function()
		T.expect(GameModeVoteViewModel.progress(10, 20, 10)):toEqual(1)
		T.expect(GameModeVoteViewModel.progress(15, 20, 10)):toEqual(0.5)
		T.expect(GameModeVoteViewModel.progress(25, 20, 10)):toEqual(0)
		T.expect(GameModeVoteViewModel.progress(10, 20, 0)):toEqual(0)
	end)

	T.it("builds map chips: drops unknown and disabled ids, sorts, and carries counts and the pick", function()
		local chips = GameModeVoteViewModel.mapChips(
			{
				mapOptions = { "SecondMap", "Mystery", "Off", "Bowl", "Bowl" },
				mapVoteCounts = { Bowl = 3 },
				selectedMapId = "SecondMap",
			},
			MAPS,
			accent,
			function(value)
				return value
			end
		)
		T.expect(#chips):toEqual(2)
		T.expect(chips[1].Id):toEqual("Bowl")
		T.expect(chips[2].Id):toEqual("SecondMap")
		T.expect(chips[1].VoteCount):toEqual(3)
		T.expect(chips[2].VoteCount):toEqual(0)
		T.expect(chips[1].Selected):toEqual(false)
		T.expect(chips[2].Selected):toEqual(true)
		T.expect(chips[1].ThumbnailId):toEqual("rbxassetid://1")
	end)

	T.it("returns no chips when fewer than two maps are offered", function()
		T.expect(#GameModeVoteViewModel.mapChips({ mapOptions = { "Bowl" } }, MAPS, accent)):toEqual(0)
		T.expect(#GameModeVoteViewModel.mapChips({ mapOptions = { "Bowl", "Mystery" } }, MAPS, accent)):toEqual(0)
		T.expect(#GameModeVoteViewModel.mapChips({}, MAPS, accent)):toEqual(0)
	end)

	T.it("lays the dock out at every supported size", function()
		local sizes = {
			Vector2.new(1920, 1080),
			Vector2.new(1366, 768),
			Vector2.new(1024, 768),
			Vector2.new(844, 390),
			Vector2.new(667, 375),
		}
		for _, size in sizes do
			local layout = GameModeVoteViewModel.dockLayout(size, 2)
			T.expect(layout.chipHeight >= 44):toEqual(true)
			T.expect(layout.barHeight >= 44):toEqual(true)
			T.expect(layout.stacked):toEqual(false)
			T.expect(layout.holderShrink):toEqual(0)
			T.expect(layout.barWidth >= 200):toEqual(true)
			local total = 2 * layout.chipWidth + 2 * layout.gap + layout.barWidth
			T.expect(total <= size.X * 0.94):toEqual(true)
		end
		T.expect(GameModeVoteViewModel.dockLayout(Vector2.new(1920, 1080), 2).chipHeight):toEqual(96)
		T.expect(GameModeVoteViewModel.dockLayout(Vector2.new(1366, 768), 2).chipHeight):toEqual(69)
		T.expect(GameModeVoteViewModel.dockLayout(Vector2.new(844, 390), 2).chipHeight):toEqual(48)
	end)

	T.it("stacks the dock in portrait, for many maps, or when the bar would be too narrow", function()
		for _, size in { Vector2.new(390, 844), Vector2.new(768, 1024) } do
			local layout = GameModeVoteViewModel.dockLayout(size, 2)
			T.expect(layout.stacked):toEqual(true)
			T.expect(layout.chipHeight >= 44):toEqual(true)
			T.expect(layout.holderShrink):toEqual(layout.chipHeight + layout.gap)
			T.expect(2 * layout.chipWidth + layout.gap <= size.X * 0.94):toEqual(true)
		end
		T.expect(GameModeVoteViewModel.dockLayout(Vector2.new(1920, 1080), 4).stacked):toEqual(true)
		T.expect(GameModeVoteViewModel.dockLayout(Vector2.new(667, 375), 3).stacked):toEqual(true)
	end)

	T.it("titles the ballot by whether a map is on offer", function()
		T.expect(GameModeVoteViewModel.title(true)):toEqual("VOTE MODE & MAP")
		T.expect(GameModeVoteViewModel.title(false)):toEqual("VOTE FOR A MODE")
	end)
end)

return true
