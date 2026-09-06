-- Hidden ancestor screens cannot receive restored gamepad focus after a phase transition.
--!nonstrict

local Selection = require(game.ReplicatedStorage.Shared.UI.Services.Selection)

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
	end)
end
