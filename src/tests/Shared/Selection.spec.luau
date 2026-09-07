-- Hidden ancestor screens cannot receive restored gamepad focus after a phase transition.
--!nonstrict

local Selection = require(game.ReplicatedStorage.Shared.UI.Services.Selection)

local function scrollFixture(position, size)
	local scroller = {
		AbsolutePosition = Vector2.new(40, 100),
		AbsoluteWindowSize = Vector2.new(250, 120),
		AbsoluteCanvasSize = Vector2.new(400, 600),
		CanvasPosition = Vector2.new(12, 200),
		IsA = function(_, class)
			return class == "ScrollingFrame"
		end,
	}
	local button = {
		Parent = scroller,
		AbsolutePosition = Vector2.new(40, position),
		AbsoluteSize = Vector2.new(150, size),
	}
	return button, scroller
end

return function()
	describe("Selection", function()
		it("rejects hidden, disabled, unmounted and destroyed controls", function()
			local gui = Instance.new("ScreenGui")
			local frame = Instance.new("Frame")
			frame.Parent = gui
			local button = Instance.new("TextButton")
			button.Parent = frame
			expect(Selection.isSelectable(button)).to.equal(false)
			gui.Parent = game.ReplicatedStorage
			expect(Selection.isSelectable(button)).to.equal(true)
			frame.Visible = false
			expect(Selection.isSelectable(button)).to.equal(false)
			frame.Visible = true
			gui.Enabled = false
			expect(Selection.isSelectable(button)).to.equal(false)
			gui.Enabled = true
			button.Selectable = false
			expect(Selection.isSelectable(button)).to.equal(false)
			gui:Destroy()
			expect(Selection.isSelectable(button)).to.equal(false)
		end)
		it("reveals selected rewards beyond the viewport while preserving horizontal scroll", function()
			local button, scroller = scrollFixture(235, 44)
			Selection.scrollIntoView(button)
			expect(scroller.CanvasPosition).to.equal(Vector2.new(12, 259))
		end)
		it("reveals horizontal season rewards beyond the visible strip", function()
			local button, scroller = scrollFixture(110, 44)
			button.AbsolutePosition = Vector2.new(320, 110)
			Selection.scrollIntoView(button)
			expect(scroller.CanvasPosition).to.equal(Vector2.new(150, 200))
		end)
		it("does not move a fully visible selection", function()
			local button, scroller = scrollFixture(110, 44)
			Selection.scrollIntoView(button)
			expect(scroller.CanvasPosition).to.equal(Vector2.new(12, 200))
		end)
		it("reveals earlier selections and aligns an oversized selection at its top", function()
			local button, scroller = scrollFixture(80, 44)
			Selection.scrollIntoView(button)
			expect(scroller.CanvasPosition).to.equal(Vector2.new(12, 180))
			button, scroller = scrollFixture(240, 180)
			Selection.scrollIntoView(button)
			expect(scroller.CanvasPosition).to.equal(Vector2.new(12, 340))
		end)
	end)
end
