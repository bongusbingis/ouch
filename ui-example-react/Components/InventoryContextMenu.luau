---> module declaration
local InventoryContextMenu = {}
InventoryContextMenu.Prototype = {}

---> services
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

---> dependencies
local Knit = require(ReplicatedStorage:WaitForChild("Knit"))
local GoodSignal = require(Knit.Util.GoodSignal)
local Promise = require(Knit.Util.Promise)
local Janitor = require(Knit.Util.Janitor)
local Suffix = require(Knit.Util.Suffix)

---> globals
local Player = Players.LocalPlayer
local PlayerMouse = Player:GetMouse()
local PlayerGui: PlayerGui = Player:WaitForChild("PlayerGui")
local UI = PlayerGui:WaitForChild("MainGUI")

local SharedStorage: Folder = ReplicatedStorage:WaitForChild("SharedStorage")
local UISharedStorage = SharedStorage:WaitForChild("UI")
local InventoryContextMenuTemplate: Frame = UISharedStorage:WaitForChild("InventoryContextMenuTemplate")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = Shared:WaitForChild("UI"):WaitForChild("Components")
local Classes = Shared:WaitForChild("Classes")

local GlowButton = require(Components:WaitForChild("GlowButton"))
local LoadingFrameThread: thread?

---> constants
local START_SIZE = UDim2.fromScale(0, 0)
local FULL_SIZE: UDim2 = InventoryContextMenuTemplate.Holder.Size
local RESIZE_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back)

---> types
type _self = {
	_base: typeof(InventoryContextMenuTemplate),
	_holder: ImageLabel,
	_buttons: { GlowButton.glowButton },
	_loading_wheel: ImageLabel,
	_janitor: Janitor.Janitor,
}

export type inventoryContextMenu = typeof(setmetatable({} :: _self, { __index = InventoryContextMenu.Prototype }))

---> methods
function InventoryContextMenu.Prototype.AddButton(self: inventoryContextMenu, glowButton: GlowButton.glowButton)
	glowButton:Mount(self._holder.List)
	local uiListLayout = self._holder.List.UIListLayout
	local yOffset = #self._buttons
	--glowButton:SetSize(UDim2.new(self._holder.List.Size.X.Scale, 0, 0, 100))
	table.insert(self._buttons, glowButton)
end

function InventoryContextMenu.Prototype.MountAtMousePosition(self: inventoryContextMenu, xOffsetLeft: number?)
	self._base.Position = UDim2.new(-xOffsetLeft / 2, PlayerMouse.X, 0, PlayerMouse.Y)
	self._base.Parent = UI
	self._base.Visible = true

	local buttonCount = #self._buttons
	local containerHeight = self._base.AbsoluteSize.Y
	local usableHeight = containerHeight * 0.75
	local rawHeight = usableHeight / buttonCount
	local maxHeight = containerHeight * 0.3
	for _, button: GlowButton.glowButton in self._buttons do
		button:SetSize(UDim2.new(0.9, 0, 0, math.min(rawHeight, maxHeight)))
	end
	
	local size = UDim2.new(FULL_SIZE.X.Scale, 0, 0, self._holder.ItemName.AbsoluteSize.Y + self._holder.List.AbsoluteSize.Y + (#self._buttons * 15))
	TweenService:Create(self._holder, RESIZE_TWEEN_INFO, { Size = size }):Play()
	self._holder.Size = START_SIZE
	pcall(ContentProvider.PreloadAsync, ContentProvider, { self._holder })
end

function InventoryContextMenu.Prototype.SetTitle(self: inventoryContextMenu, title: string)
	local textSize = TextService:GetTextSize(title, self._holder.ItemName.TextSize, self._holder.ItemName.Font, self._holder.ItemName.AbsoluteSize)
	self._holder.ItemName.Text = title
	self._holder.ItemName.Size = UDim2.fromOffset(textSize.X, textSize.Y)
end

function InventoryContextMenu.Prototype.Destroy(self: inventoryContextMenu, tweenBeforeDestruction: boolean?)
	task.defer(function()
        self._janitor:Cleanup()
		if tweenBeforeDestruction then
            self._holder.AnchorPoint = Vector2.new(0.5, 0.5)
            self._holder.Position = UDim2.fromScale(0.5, 0.5)
            local destroyTween = TweenService:Create(self._holder, TweenInfo.new(RESIZE_TWEEN_INFO.Time / 3), { Size = START_SIZE })
            destroyTween:Play()
            destroyTween.Completed:Wait()
		end
		print("destroy")
		self._base:Destroy()
		table.clear(self)
		setmetatable(self, nil)
	end)
end

---> constructors
function InventoryContextMenu.New(originSlot)
	local newInventoryContextMenu = InventoryContextMenuTemplate:Clone()

	return setmetatable(
		{
			Origin = originSlot,
			_base = newInventoryContextMenu,
			_holder = newInventoryContextMenu.Holder,
			_buttons = {},
			_janitor = Janitor.new(),
		} :: _self,
		{ __index = InventoryContextMenu.Prototype }
	)
end

return InventoryContextMenu
