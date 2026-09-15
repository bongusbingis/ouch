--!strict
local T = require(script.Parent.TestKit)
local Layout = require(script.Parent.Parent.UI.Models.SplashLayout)
local Header = require(script.Parent.Parent.UI.Models.LobbyHeaderLayout)
local Tokens = require(script.Parent.Parent.UI.Tokens)

T.describe("Splash composition", function()
	T.it("keeps a clear gap between progression tabs and their content", function()
		T.expect(Tokens.Splash.ProgressContentTop)
			:toEqual(Tokens.Splash.ProgressTabTop + Tokens.Splash.ProgressTabHeight + Tokens.Splash.ProgressContentGap)
		T.expect(Tokens.Splash.ProgressContentGap >= 12):toBeTruthy()
		T.expect(Tokens.Splash.CompactProgressContentTop):toEqual(
			Tokens.Splash.ProgressTabTop + Tokens.Splash.ProgressTabHeight + Tokens.Splash.CompactProgressContentGap
		)
		T.expect(Tokens.Splash.CompactProgressContentGap >= 8):toBeTruthy()
	end)
	T.it("keeps the desktop party camera clear of the control column", function()
		for _, size in { Vector2.new(1246, 802), Vector2.new(1366, 706), Vector2.new(1920, 1018) } do
			local layout = Layout.resolve(size)
			T.expect(layout.compact):toBeFalsy()
			T.expect(layout.world.position.X + layout.world.size.X < layout.body.position.X):toBeTruthy()
			T.expect(layout.world.position.Y >= Header.resolve(size).height):toBeTruthy()
			T.expect(layout.body.position.Y + layout.body.size.Y <= size.Y):toBeTruthy()
		end
	end)
	T.it("reserves reachable actions below progression on small screens", function()
		for _, size in { Vector2.new(750, 344), Vector2.new(600, 302), Vector2.new(960, 540), Vector2.new(390, 780) } do
			local layout = Layout.resolve(size)
			T.expect(layout.compact):toBeTruthy()
			T.expect(layout.body.size.Y > 44):toBeTruthy()
			T.expect(layout.body.position.Y + layout.body.size.Y < layout.footer.position.Y):toBeTruthy()
			T.expect(layout.footer.size.Y >= Tokens.Layout.MinTarget):toBeTruthy()
			T.expect(layout.footer.position.Y + layout.footer.size.Y <= size.Y):toBeTruthy()
			if layout.landscape then
				T.expect(layout.world.position.X + layout.world.size.X < layout.body.position.X):toBeTruthy()
			end
		end
	end)
	T.it("fits one complete quest above the phone actions", function()
		local layout = Layout.resolve(Vector2.new(750, 304), false, "QUESTS", false, 13)
		T.expect(layout.progressHeight - Tokens.Splash.CompactProgressContentTop - 4 >= 80):toBeTruthy()
	end)
	T.it("keeps the party and pinned actions clear across landscape phone sizes and progress tabs", function()
		for _, size in { Vector2.new(600, 280), Vector2.new(750, 304), Vector2.new(800, 338), Vector2.new(844, 344) } do
			local footerY = nil
			for _, tab in { "SEASON", "QUESTS", "DAILY" } do
				local layout = Layout.resolve(size, true, tab, true, 13)
				T.expect(layout.world.size.X >= 240 and layout.world.size.Y >= 150):toBeTruthy()
				T.expect(layout.world.position.X + layout.world.size.X < layout.body.position.X):toBeTruthy()
				T.expect(layout.world.position.Y + layout.world.size.Y < layout.footer.position.Y):toBeTruthy()
				T.expect(
					layout.body.position.Y + layout.body.size.Y + Tokens.LobbyLandscape.StatusHeight
						< layout.footer.position.Y
				):toBeTruthy()
				T.expect(layout.footer.position.Y + layout.footer.size.Y <= size.Y - 12):toBeTruthy()
				if footerY then
					T.expect(layout.footer.position.Y):toEqual(footerY)
				end
				footerY = layout.footer.position.Y
			end
		end
	end)
	T.it("gives desktop quests most of the column and reserves a separate action card", function()
		for _, queued in { false, true } do
			local layout = Layout.resolve(Vector2.new(1246, 802), queued, "QUESTS")
			T.expect(layout.progressHeight > layout.body.size.Y * 0.6):toBeTruthy()
			T.expect(layout.progressHeight + Tokens.Splash.Gap + layout.actionHeight <= layout.body.size.Y):toBeTruthy()
		end
	end)
end)
return true
