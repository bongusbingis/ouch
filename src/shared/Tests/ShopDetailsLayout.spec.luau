--!strict
local T = require(script.Parent.TestKit)
local Layout = require(script.Parent.Parent.UI.Models.ShopDetailsLayout)
local I = require(script.Parent.Parent.UI.Tokens).Inspection

local function single(size: Vector2, overrides)
	local content = {
		detailsHeight = 160,
		listRows = 0,
		actionCount = 1,
		hasWallet = true,
		hasStatus = false,
	}
	for key, value in overrides or {} do
		content[key] = value
	end
	local frame = Layout.frame(size)
	return frame, Layout.resolve(frame, content)
end

T.describe("Shop inspection composition", function()
	T.it("sizes a single desktop item to its content instead of the viewport", function()
		local frame, layout = single(Vector2.new(1920, 1018))
		T.expect(frame.width):toEqual(I.MaxWidth)
		T.expect(frame.compact):toBeFalsy()
		T.expect(frame.stacked):toBeFalsy()
		T.expect(layout.art):toEqual(I.Art)
		T.expect(layout.scroll):toBeFalsy()
		T.expect(layout.walletRowOnTop):toBeFalsy()
		T.expect(layout.columns):toEqual(1)
		T.expect(layout.actionWidth):toEqual(I.ActionWidth)
		T.expect(layout.height)
			:toEqual(I.HeaderHeight + I.ContentInset * 2 + I.Art + I.FooterGap + I.ButtonHeight + I.Inset)
		T.expect(layout.height < 480):toBeTruthy()
	end)
	T.it("keeps the wallet beside two actions and wraps only when status needs the room", function()
		local _, layout = single(Vector2.new(1920, 1018), { actionCount = 2 })
		T.expect(layout.walletRowOnTop):toBeFalsy()
		T.expect(layout.columns):toEqual(2)
		T.expect(layout.actionWidth):toEqual(I.ActionWidth)
		T.expect(layout.footerHeight):toEqual(I.ButtonHeight)
		local _, wrapped = single(Vector2.new(1920, 1018), { actionCount = 2, hasStatus = true })
		T.expect(wrapped.walletRowOnTop):toBeTruthy()
		T.expect(wrapped.columns):toEqual(2)
		T.expect(wrapped.footerHeight):toEqual(I.ChipHeight + I.FooterGap + I.ButtonHeight)
	end)
	T.it("lists bundle pieces beside the art and scrolls past four rows", function()
		local frame, layout = single(Vector2.new(1920, 1018), { detailsHeight = 150, listRows = 3, hasWallet = false })
		local listHeight = 3 * frame.listRowHeight + 2 * I.ListGap
		T.expect(layout.listHeight):toEqual(listHeight)
		T.expect(layout.listScrolls):toBeFalsy()
		T.expect(layout.listTop):toEqual(frame.contentInset + 150 + frame.gap)
		T.expect(layout.detailsBlock):toEqual(150 + frame.gap + I.ListCaptionHeight + I.ListGap + listHeight)
		T.expect(layout.wellHeight):toEqual(frame.contentInset * 2 + layout.detailsBlock)
		local _, long = single(Vector2.new(1920, 1018), { detailsHeight = 150, listRows = 8, hasWallet = false })
		T.expect(long.listScrolls):toBeTruthy()
		T.expect(long.listHeight):toEqual(I.ListMaxRows * frame.listRowHeight + (I.ListMaxRows - 1) * I.ListGap)
	end)
	T.it("stacks the piece list under the art row and wraps actions on phones", function()
		local frame, layout =
			single(Vector2.new(402, 778), { detailsHeight = 150, listRows = 3, actionCount = 2, hasStatus = true })
		T.expect(frame.compact):toBeTruthy()
		T.expect(frame.stacked):toBeTruthy()
		T.expect(frame.width):toEqual(402 - I.CompactEdge * 2)
		T.expect(frame.art >= I.ArtMin and frame.art < I.Art):toBeTruthy()
		T.expect(layout.walletRowOnTop):toBeTruthy()
		T.expect(layout.columns):toEqual(2)
		T.expect(layout.actionWidth >= I.ActionMinWidth):toBeTruthy()
		T.expect(layout.listTop):toEqual(frame.contentInset + layout.rowHeight + frame.gap)
		T.expect(layout.footerHeight):toEqual(frame.chipHeight + frame.footerGap + frame.buttonHeight)
		T.expect(layout.height <= frame.maxHeight):toBeTruthy()
		T.expect(layout.scroll):toBeFalsy()
	end)
	T.it("uses the short landscape budget with one footer row", function()
		local frame, layout = single(Vector2.new(1024, 440), { detailsHeight = 140, hasStatus = true })
		T.expect(frame.short):toBeTruthy()
		T.expect(frame.art):toEqual(I.ShortArt)
		T.expect(frame.headerHeight):toEqual(I.ShortHeaderHeight)
		T.expect(layout.walletRowOnTop):toBeFalsy()
		T.expect(layout.footerHeight):toEqual(I.ShortButtonHeight)
		T.expect(layout.height <= frame.maxHeight):toBeTruthy()
		T.expect(layout.scroll):toBeFalsy()
	end)
	T.it("scrolls the well instead of growing past the safe area", function()
		local frame, layout =
			single(Vector2.new(402, 600), { detailsHeight = 200, listRows = 6, actionCount = 2, hasStatus = true })
		T.expect(layout.scroll):toBeTruthy()
		T.expect(layout.height):toEqual(frame.maxHeight)
		T.expect(layout.wellCanvas > layout.wellHeight):toBeTruthy()
		T.expect(layout.art <= layout.wellHeight - frame.contentInset * 2):toBeTruthy()
		T.expect(layout.footerTop + layout.footerHeight + frame.inset):toEqual(layout.height)
	end)
	T.it("keeps every target at least 44 px and the panel inside the viewport", function()
		for _, size in
			{
				Vector2.new(1920, 1018),
				Vector2.new(1246, 806),
				Vector2.new(1176, 806),
				Vector2.new(960, 540),
				Vector2.new(750, 304),
				Vector2.new(590, 400),
				Vector2.new(402, 778),
				Vector2.new(360, 640),
			}
		do
			for _, rows in { 0, 2, 5 } do
				for actions = 0, 3 do
					local frame, layout = single(size, {
						detailsHeight = 180,
						listRows = rows,
						actionCount = actions,
						hasWallet = actions > 0,
						hasStatus = actions > 0,
					})
					T.expect(frame.buttonHeight >= 44 and frame.listRowHeight >= 44):toBeTruthy()
					T.expect(frame.width <= size.X - frame.edge * 2):toBeTruthy()
					T.expect(layout.height <= frame.maxHeight):toBeTruthy()
					T.expect(frame.detailsWidth >= I.DetailsMinWidth):toBeTruthy()
					if actions > 0 then
						T.expect(layout.actionWidth >= I.ActionMinWidth):toBeTruthy()
						T.expect(layout.columns * layout.buttonRows >= actions):toBeTruthy()
					else
						T.expect(layout.footerHeight):toEqual(0)
					end
					T.expect(
						layout.wellTop
							+ layout.wellHeight
							+ (if layout.footerHeight > 0 then frame.footerGap + layout.footerHeight else 0)
							+ frame.inset
					):toEqual(layout.height)
				end
			end
		end
	end)
end)

return true
