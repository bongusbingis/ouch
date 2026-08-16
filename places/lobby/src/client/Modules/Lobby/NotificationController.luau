local NotificationController = {}
NotificationController.__index = NotificationController

function NotificationController.new(screenGui)
	local modal = screenGui:WaitForChild("BaseClip"):WaitForChild("Modals"):WaitForChild("Notification")
	local buttons = modal:WaitForChild("Buttons")
	local redButton = buttons:WaitForChild("RedButton")
	local blueButton = buttons:WaitForChild("BlueButton")

	local self = setmetatable({
		_modal = modal,
		_buttons = buttons,
		_title = modal:WaitForChild("Title"),
		_description = modal:WaitForChild("Description"),
		_templates = {
			Red = redButton,
			Blue = blueButton,
		},
		_clones = {},
		_callback = nil,
		_isOpen = false,
	}, NotificationController)

	buttons:WaitForChild("UIListLayout").SortOrder = Enum.SortOrder.LayoutOrder
	redButton.Visible = false
	redButton.Active = false
	blueButton.Visible = false
	blueButton.Active = false
	modal.Visible = false

	return self
end

function NotificationController:_clearButtons()
	for _, button in self._clones do
		button:Destroy()
	end

	table.clear(self._clones)
end

function NotificationController:_createButton(definition, layoutOrder)
	local template = self._templates[definition.color]
	if not template then
		error(("Unknown notification button color %s"):format(tostring(definition.color)))
	end

	local button = template:Clone()
	button.Name = ("NotificationButton%d"):format(layoutOrder)
	button.LayoutOrder = layoutOrder
	button:WaitForChild("TextLabel").Text = definition.text
	button.Visible = true
	button.Active = true
	button.Selectable = true
	button.Parent = self._buttons
	button.Activated:Connect(function()
		self:Close(definition.value)
	end)
	table.insert(self._clones, button)
end

function NotificationController:Show(options, callback)
	if self._isOpen then
		self:Close(nil)
	end
	if #options.buttons == 0 then
		error("A notification requires at least one button")
	end

	self:_clearButtons()
	self._title.Text = options.title
	self._description.Text = options.description
	self._callback = callback
	self._isOpen = true

	for layoutOrder, definition in options.buttons do
		self:_createButton(definition, layoutOrder)
	end

	self._modal.Visible = true
end

function NotificationController:Notify(options, callback)
	self:Show({
		title = options.title,
		description = options.description,
		buttons = {
			{
				color = "Blue",
				text = options.buttonText or "OK",
				value = true,
			},
		},
	}, callback)
end

function NotificationController:Confirm(options, callback)
	self:Show({
		title = options.title,
		description = options.description,
		buttons = {
			{
				color = "Red",
				text = options.confirmText or "CONFIRM",
				value = true,
			},
			{
				color = "Blue",
				text = options.cancelText or "CANCEL",
				value = false,
			},
		},
	}, callback)
end

function NotificationController:Close(result)
	if not self._isOpen then
		return
	end

	local callback = self._callback
	self._callback = nil
	self._isOpen = false
	self._modal.Visible = false
	self:_clearButtons()

	if callback then
		task.spawn(callback, result)
	end
end

return NotificationController
