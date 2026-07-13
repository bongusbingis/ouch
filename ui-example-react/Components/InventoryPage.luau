---> module declaration
local InventoryPage = {}
InventoryPage.Prototype = {}
InventoryPage.__index = InventoryPage.Prototype

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

---> dependencies
local Knit = require(ReplicatedStorage:WaitForChild("Knit"))
local Promise = require(Knit.Util.Promise)
local Janitor = require(Knit.Util.Janitor)

---> types
type _self = {
	Name: string,
	ClassName: string,
	PageJanitor: Janitor.Janitor,
	_parent_frame: UIBase,
	_page_frame: Frame,
}

type outToInFrom = {
	outTo: UDim2,
	inFrom: UDim2,
}

export type inventoryPage = typeof(setmetatable({} :: _self, InventoryPage))

---> globals
local Player = Players.LocalPlayer
local PlayerGui: PlayerGui = Player:WaitForChild("PlayerGui")

local Shared: Folder = ReplicatedStorage:WaitForChild("Shared")
local UIComponents: Folder = Shared:WaitForChild("UI"):WaitForChild("Components")
local Classes: Folder = Shared:WaitForChild("Classes")

---> locals
local currentPage: inventoryPage = nil
local arePagesCurrentlyMoving: boolean = false

---> constants
local PAGE_TWEEN_INFO = TweenInfo.new(0.5)
local OUT_OF_FRAME_TOP = UDim2.fromScale(0.5, 1.25)
local OUT_OF_FRAME_BOTTOM = UDim2.fromScale(0.5, -1.25)
local IN_FRAME = UDim2.fromScale(0.5, 0.5)

---> private functions

---> methods

function InventoryPage.Prototype._cleanupAndHide(self: inventoryPage): ()
	self.PageJanitor:Cleanup()
	self._page_frame.Visible = false
end

function InventoryPage.Prototype._getLayoutOrder(self: inventoryPage): number
	return self._page_frame.LayoutOrder
end

function InventoryPage.Prototype:_getOutAndInPositionsForPage(self: inventoryPage): outToInFrom
	local returnPositions: outToInFrom = {
		outTo = OUT_OF_FRAME_TOP,
		inFrom = OUT_OF_FRAME_BOTTOM,
	}
	if self:_getLayoutOrder() > currentPage:_getLayoutOrder() then
		returnPositions.outTo = OUT_OF_FRAME_BOTTOM
		returnPositions.inFrom = OUT_OF_FRAME_TOP
	end
	return returnPositions
end

function InventoryPage.Prototype._tweenTo(self: inventoryPage, position: UDim2): RBXScriptSignal
	local pageTween = TweenService:Create(self._page_frame, PAGE_TWEEN_INFO, {Position = position})
	pageTween:Play()
	return pageTween.Completed
end

--[[
    Switches the current page to the one associated with self, and cleans up all slots and connections from the previous page. The
    promise returned by this function will be resolved once all slots are loaded

    @return Promise -> nil
--]]
function InventoryPage.Prototype.Render(self: inventoryPage): Promise.TypedPromise
	return Promise.new(function(resolve, _)
		if currentPage == self or arePagesCurrentlyMoving then
			return
		elseif not currentPage then
			self._page_frame.Visible = true
		end
		
		local outToInFrom: outToInFrom = self:_getOutAndInPositionsForPage()
		self._page_frame.Position = outToInFrom.inFrom
		self._page_frame.Visible = true
		currentPage:_tweenTo(outToInFrom.outTo)
		self:_tweenTo(IN_FRAME):Once(function()
			currentPage = self
		end)
	end)
end

---> constructors

--[[
    Constructs a new inventory page

    @param parentFrame - The holder frame that all pages will be stored under; must have a UIPageLayout parented
    @param pageFrame - The frame being wrapped by this function that the slots will be parented under
    @param className - The name of the class that slots will be generated from in the corresponding shared module
    @return inventoryPage
--]]
function InventoryPage.New(parentFrame: UIBase, pageFrame: Frame, itemType: string): inventoryPage
	local itemTypeModuleScript: ModuleScript = Classes:FindFirstChild(itemType .. "Class")
	--assert(itemTypeModuleScript, "Couldn't find an associated class module for this class name")
	--pageFrame.Visible = false
	return setmetatable(
		{
			Name = parentFrame.Name,
			ItemType = itemType,
			PageJanitor = Janitor,
			_parent_frame = parentFrame,
			_page_frame = pageFrame,
		} :: _self,
		InventoryPage
	)
end

return InventoryPage
