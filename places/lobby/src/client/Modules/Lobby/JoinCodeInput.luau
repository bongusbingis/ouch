local CODE_LENGTH = 6
local DISABLED_COLOR = Color3.fromRGB(110, 110, 110)
local ERROR_COLOR = Color3.fromRGB(255, 0, 0)
local ERROR_DURATION = 3
local FOCUS_RETRY_DELAY = 0.1
local HELP_TEXT = "Ex: 123-456"
local HELP_TEXT_COLOR = Color3.fromRGB(255, 255, 255)

local JoinCodeInput = {}
JoinCodeInput.__index = JoinCodeInput

local function sanitize(text)
	return string.sub(string.gsub(text, "%D", ""), 1, CODE_LENGTH)
end

function JoinCodeInput.new(modal, onConfirm)
	local buttons = modal:WaitForChild("Buttons")
	local entryBox = modal:WaitForChild("EntryBox")
	local holder = entryBox:WaitForChild("Holder")
	local confirmButton = buttons:WaitForChild("Confirm")
	local cancelButton = buttons:WaitForChild("Cancel")
	local errorText = modal:WaitForChild("ErrorText")
	local inputCapture = entryBox:WaitForChild("InputCapture")

	local self = setmetatable({
		_modal = modal,
		_holder = holder,
		_template = holder:WaitForChild("DigitBoxTemplate"),
		_dash = holder:WaitForChild("Dash"),
		_inputCapture = inputCapture,
		_confirmButton = confirmButton,
		_cancelButton = cancelButton,
		_errorText = errorText,
		_confirmColor = confirmButton.ImageColor3,
		_digits = {},
		_onConfirm = onConfirm,
		_errorRevision = 0,
		_isOpen = false,
		_updatingText = false,
		_submitting = false,
	}, JoinCodeInput)

	self._template.Visible = false
	self._dash.LayoutOrder = 4
	self._holder:WaitForChild("UIListLayout").SortOrder = Enum.SortOrder.LayoutOrder
	self._inputCapture.ClearTextOnFocus = false
	self._inputCapture.MultiLine = false
	self._inputCapture.ShowNativeInput = true
	self._inputCapture.TextEditable = true

	self._inputCapture:GetPropertyChangedSignal("Text"):Connect(function()
		self:_onTextChanged()
	end)
	self._inputCapture.FocusLost:Connect(function(enterPressed)
		self:_scheduleFocus()
		if enterPressed then
			self:_submit()
		end
	end)
	self._inputCapture.ReturnPressedFromOnScreenKeyboard:Connect(function()
		self:_submit()
	end)
	self._confirmButton.MouseButton1Click:Connect(function()
		self:_submit()
	end)
	self._cancelButton.MouseButton1Click:Connect(function()
		self:Close()
	end)

	return self
end

function JoinCodeInput:_destroyDigits()
	for _, digit in self._digits do
		digit.box:Destroy()
	end

	table.clear(self._digits)
end

function JoinCodeInput:_buildDigits()
	self:_destroyDigits()
	self._dash.LayoutOrder = 4
	self._dash.Visible = true

	for index = 1, CODE_LENGTH do
		local digitBox = self._template:Clone()
		digitBox.Name = ("Digit%d"):format(index)
		digitBox.LayoutOrder = index
		digitBox.Visible = true
		digitBox.Parent = self._holder

		table.insert(self._digits, {
			box = digitBox,
			character = digitBox:WaitForChild("Char"),
		})
	end
end

function JoinCodeInput:_setConfirmEnabled(enabled)
	self._confirmButton.Active = enabled
	self._confirmButton.Selectable = enabled
	self._confirmButton.AutoButtonColor = enabled
	self._confirmButton.ImageColor3 = if enabled then self._confirmColor else DISABLED_COLOR
end

function JoinCodeInput:_scheduleFocus(delay)
	task.delay(delay or FOCUS_RETRY_DELAY, function()
		if self._isOpen and self._modal.Visible and not self._inputCapture:IsFocused() then
			self._inputCapture:CaptureFocus()
		end
	end)
end

function JoinCodeInput:_resetError()
	self._errorRevision += 1
	self._errorText.Text = HELP_TEXT
	self._errorText.TextColor3 = HELP_TEXT_COLOR
end

function JoinCodeInput:ShowError(message)
	self._errorRevision += 1
	local revision = self._errorRevision
	self._errorText.Text = message
	self._errorText.TextColor3 = ERROR_COLOR

	task.delay(ERROR_DURATION, function()
		if revision == self._errorRevision then
			self:_resetError()
		end
	end)
end

function JoinCodeInput:_render()
	local code = self._inputCapture.Text

	for index, digit in self._digits do
		digit.character.Text = string.sub(code, index, index)
	end

	self:_setConfirmEnabled(#code == CODE_LENGTH and not self._submitting)
end

function JoinCodeInput:_onTextChanged()
	if self._updatingText then
		return
	end

	local sanitized = sanitize(self._inputCapture.Text)
	if sanitized ~= self._inputCapture.Text then
		self._updatingText = true
		self._inputCapture.Text = sanitized
		self._inputCapture.CursorPosition = #sanitized + 1
		self._inputCapture.SelectionStart = -1
		self._updatingText = false
	end

	self:_render()
end

function JoinCodeInput:_submit()
	local code = self._inputCapture.Text
	if self._submitting or #code ~= CODE_LENGTH then
		return
	end

	self._submitting = true
	self:_render()
	self._cancelButton.Active = false

	local shouldClose, errorMessage = self._onConfirm(code)

	self._submitting = false
	self._cancelButton.Active = true
	if shouldClose then
		self:Close()
	elseif self._isOpen then
		if errorMessage then
			self:ShowError(errorMessage)
		end
		self:_render()
		self:_scheduleFocus()
	end
end

function JoinCodeInput:Open()
	self._isOpen = true
	self:_buildDigits()
	self:_resetError()
	self._inputCapture.Text = ""
	self._modal.Visible = true
	self:_render()

	self:_scheduleFocus(0)
end

function JoinCodeInput:Close()
	self._isOpen = false
	self._inputCapture:ReleaseFocus()
	self._modal.Visible = false
	self:_resetError()
	self._inputCapture.Text = ""
	self:_destroyDigits()
end

return JoinCodeInput
