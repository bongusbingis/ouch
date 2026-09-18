-- Description: Modal for entering a six-digit party join code, with per-digit boxes, focus handling, validation, and error feedback.

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local CandyPanel = require(script.Parent.CandyPanel)
local CandyTitle = require(script.Parent.CandyTitle)
local CandySurface = require(script.Parent.CandySurface)
local PuffyButton = require(script.Parent.PuffyButton)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local JoinCodeLayout = require(script.Parent.Parent.Models.JoinCodeLayout)
local ScrollFrame = require(script.Parent.ScrollFrame)
local Well = require(script.Parent.Well)
local T = require(script.Parent.Parent.Tokens)

local modalSurface = require(script.Parent.ModalSurface)

local c = React.createElement
local C, J = T.Colors, T.JoinCode
local CODE_LENGTH = 6
local HELP_TEXT = ""

local function keyboardSnapshot()
	return {
		visible = UserInputService.OnScreenKeyboardVisible,
		position = UserInputService.OnScreenKeyboardPosition,
		size = UserInputService.OnScreenKeyboardSize,
	}
end

local function sanitize(text: string): string
	return string.sub(string.gsub(text, "%D", ""), 1, CODE_LENGTH)
end

local function DigitBox(props)
	local entered, setEntered = React.useState(false)
	local revision = React.useRef(0)
	local reducedMotion = useReducedMotion()
	local styles = ReactSpring.useSpring({
		Scale = if entered then 1 else 0.82,
		config = Motion.Modal,
		immediate = reducedMotion,
	})
	React.useEffect(function()
		revision.current += 1
		local current = revision.current
		task.delay(props.Delay, function()
			if revision.current == current then
				setEntered(true)
			end
		end)
		return function()
			revision.current += 1
		end
	end, { props.Delay })
	return c("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(0.95 / CODE_LENGTH, -J.DigitGap, 1, 0),
		ZIndex = 106,
	}, {
		EntranceScale = c("UIScale", { Scale = styles.Scale }),
		Maximum = c("UISizeConstraint", { MaxSize = Vector2.new(math.huge, J.DigitHeight) }),
		Surface = c(CandySurface, {
			Color = if props.Active then C.Yellow else C.SurfaceWarm,
			LipColor = if props.Active then C.Yellow:Lerp(C.Ink, 0.22) else C.WellLine,
			Radius = J.DigitRadius,
			Shadow = false,
			ZIndex = 106,
		}),
		Char = c(ResponsiveText, {
			HostName = "Char",
			MeasurementFont = T.Type.Display,
			MaxTextSize = J.DigitTextSize,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = T.Type.Display,
				Position = UDim2.new(0.5, 0, 0.5, -T.Shape.LipHeight / 2),
				Size = UDim2.fromScale(0.8, 0.8),
				Text = props.Character,
				TextColor3 = C.Ink,
				ZIndex = 111,
			},
		}),
	})
end

export type Props = {
	Open: boolean,
	FocusEnabled: boolean?,
	OnClose: () -> (),
	OnSubmit: (string) -> (boolean, string?),
}

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local preferredSize = ResponsiveLayout.panelSize(
		safeArea.size,
		UIConfig.Layout.Panels.JoinCode,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local rootPosition, setRootPosition = React.useState(Vector2.zero)
	local keyboard, setKeyboard = React.useState(keyboardSnapshot)
	local keyboardDismissInput = React.useRef(nil)
	local layout = JoinCodeLayout.resolve(safeArea, preferredSize, rootPosition, keyboard)
	local panelSize = layout.size
	local inputRef = React.useRef(nil)
	local formScrollRef = React.useRef(nil)
	local scrollTargetRef = React.useRef(layout.scrollY)
	scrollTargetRef.current = layout.scrollY
	local previousSelection = React.useRef(nil)
	local focusRevision = React.useRef(0)
	local errorRevision = React.useRef(0)
	local submitRevision = React.useRef(0)
	local openRef = React.useRef(props.Open)
	local focusAllowedRef = React.useRef(props.Open and props.FocusEnabled ~= false)
	local closingRef = React.useRef(false)
	local resumeFocusRef = React.useRef(true)
	local submittingRef = React.useRef(false)
	local aliveRef = React.useRef(true)
	openRef.current = props.Open
	focusAllowedRef.current = props.Open and props.FocusEnabled ~= false
	local code, setCode = React.useState("")
	local inputFocused, setInputFocused = React.useState(false)
	local errorText, setErrorText = React.useState(HELP_TEXT)
	local errorColor, setErrorColor = React.useState(C.InkSoft)
	local submitting, setSubmitting = React.useState(false)
	local reducedMotion = useReducedMotion()
	local modalStyles = ReactSpring.useSpring({
		Scale = if props.Open then 1 else 0.82,
		config = Motion.Modal,
		immediate = reducedMotion,
	})

	local function positionForm(scroll: ScrollingFrame)
		-- ScrollFrame owns its ref; native geometry events provide the actual host.
		formScrollRef.current = scroll
		if not scroll.Parent or not openRef.current or closingRef.current then
			return
		end
		local maximum = math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y)
		scroll.CanvasPosition = Vector2.new(0, math.min(scrollTargetRef.current, maximum))
	end

	local function scheduleFocus(delay: number?)
		focusRevision.current += 1
		local revision = focusRevision.current
		task.delay(delay or 0.1, function()
			local input = inputRef.current
			if
				revision == focusRevision.current
				and focusAllowedRef.current
				and resumeFocusRef.current
				and not closingRef.current
				and input
				and not input:IsFocused()
			then
				input:CaptureFocus()
			end
		end)
	end

	local function showError(message: string)
		errorRevision.current += 1
		local revision = errorRevision.current
		setErrorText(message)
		setErrorColor(C.PinkLip)
		task.delay(3, function()
			if revision == errorRevision.current then
				setErrorText(HELP_TEXT)
				setErrorColor(C.InkSoft)
			end
		end)
	end

	local function close()
		closingRef.current = true
		resumeFocusRef.current = false
		submittingRef.current = false
		focusRevision.current += 1
		errorRevision.current += 1
		submitRevision.current += 1
		local input = inputRef.current
		if input and input:IsFocused() then
			input:ReleaseFocus()
		end
		setCode("")
		setErrorText(HELP_TEXT)
		setErrorColor(C.InkSoft)
		setSubmitting(false)
		props.OnClose()
		local selection = previousSelection.current
		if selection and selection.Parent and selection.Visible and selection.Selectable then
			GuiService.SelectedObject = selection
		end
	end

	local function submit()
		if submittingRef.current or not focusAllowedRef.current or closingRef.current or #code ~= CODE_LENGTH then
			return
		end
		submittingRef.current = true
		setSubmitting(true)
		submitRevision.current += 1
		local revision = submitRevision.current
		task.spawn(function()
			local callOk, success, message = pcall(props.OnSubmit, code)
			if not callOk then
				success = false
				message = "Connection failed. Please try again."
			end
			if not aliveRef.current or revision ~= submitRevision.current then
				return
			end
			submittingRef.current = false
			setSubmitting(false)
			if success then
				close()
			elseif openRef.current then
				if message then
					showError(message)
				end
			end
		end)
	end

	React.useEffect(function()
		if not props.Open then
			closingRef.current = true
			resumeFocusRef.current = false
			submittingRef.current = false
			setSubmitting(false)
			submitRevision.current += 1
			return
		end
		closingRef.current = false
		resumeFocusRef.current = true
		submittingRef.current = false
		setSubmitting(false)
		previousSelection.current = GuiService.SelectedObject
		setCode("")
		setErrorText(HELP_TEXT)
		setErrorColor(C.InkSoft)
		scheduleFocus(0)
		return function()
			focusRevision.current += 1
			local previous = previousSelection.current
			if previous and previous.Parent and previous.Visible and previous.Selectable then
				GuiService.SelectedObject = previous
			end
			local input = inputRef.current
			if input and input:IsFocused() then
				input:ReleaseFocus()
			end
		end
	end, { props.Open })

	React.useEffect(function()
		if not props.Open then
			return
		end
		if props.FocusEnabled == false then
			focusRevision.current += 1
			local input = inputRef.current
			if input and input:IsFocused() then
				resumeFocusRef.current = true
				input:ReleaseFocus()
			end
		elseif resumeFocusRef.current then
			closingRef.current = false
			scheduleFocus(0)
		end
	end, { props.Open, props.FocusEnabled })

	React.useEffect(function()
		local scroll = formScrollRef.current
		if scroll then
			positionForm(scroll)
		end
	end, { props.Open, layout.scrollY, layout.contentHeight, panelSize.Y })

	React.useEffect(function()
		if not props.Open then
			return
		end
		local active = true
		local function update()
			local snapshot = keyboardSnapshot()
			-- A tap may dismiss the keyboard before its button receives Activated.
			-- Keep that button in place until the same gesture has finished.
			if active and (snapshot.visible or keyboardDismissInput.current == nil) then
				setKeyboard(snapshot)
			end
		end
		local connections = {}
		for _, property in { "OnScreenKeyboardVisible", "OnScreenKeyboardPosition", "OnScreenKeyboardSize" } do
			table.insert(connections, UserInputService:GetPropertyChangedSignal(property):Connect(update))
		end
		table.insert(
			connections,
			UserInputService.InputEnded:Connect(function(input)
				if input == keyboardDismissInput.current then
					task.defer(function()
						if active and input == keyboardDismissInput.current then
							keyboardDismissInput.current = nil
							update()
						end
					end)
				end
			end)
		)
		table.insert(
			connections,
			UserInputService.WindowFocusReleased:Connect(function()
				keyboardDismissInput.current = nil
				update()
			end)
		)
		update()
		return function()
			active = false
			keyboardDismissInput.current = nil
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { props.Open })

	React.useEffect(function()
		aliveRef.current = true
		return function()
			aliveRef.current = false
			focusRevision.current += 1
			errorRevision.current += 1
			submitRevision.current += 1
		end
	end, {})

	if not props.Open then
		return nil
	end

	local digits = {
		Dash = c(ResponsiveText, {
			HostName = "Dash",
			MeasurementFont = T.Type.Display,
			MaxTextSize = J.DigitTextSize,
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = 4,
				Size = UDim2.fromScale(0.05, 1),
				Text = "-",
				Font = T.Type.Display,
				TextColor3 = C.InkSoft,
				ZIndex = 106,
			},
		}),
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, J.DigitGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index = 1, CODE_LENGTH do
		digits[`Digit{index}`] = c(DigitBox, {
			LayoutOrder = if index <= 3 then index else index + 1,
			Delay = (index - 1) * 0.025,
			Character = string.sub(code, index, index),
			Active = inputFocused and not submitting and props.FocusEnabled ~= false and index == #code + 1,
		})
	end

	local canSubmit = #code == CODE_LENGTH and not submitting and props.FocusEnabled ~= false
	local compact = panelSize.X < J.CompactWidth
	return modalSurface({
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.35,
		Selectable = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		[React.Change.AbsolutePosition] = function(root: GuiObject)
			setRootPosition(root.AbsolutePosition)
		end,
	}, {
		Panel = c(CandyPanel, {
			Active = true,
			ZIndex = 101,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = if layout.position
				then UDim2.fromOffset(layout.position.X, layout.position.Y)
				else UDim2.fromScale(0.5, 0.534555),
			SelectionGroup = true,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
			Visible = true,
		}, {
			ModalScale = c("UIScale", { Scale = modalStyles.Scale }),
			FormScroll = c(ScrollFrame, {
				Active = true,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				CanvasSize = UDim2.fromOffset(0, layout.contentHeight),
				[React.Change.AbsoluteCanvasSize] = positionForm,
				[React.Change.AbsoluteWindowSize] = positionForm,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollingEnabled = layout.scrolling,
				Selectable = layout.scrolling,
				ScrollBarThickness = if layout.scrolling then J.ScrollBar else 0,
				ScrollBarImageColor3 = C.Pink,
				ZIndex = 104,
			}, {
				Content = c("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, layout.contentHeight),
					ZIndex = 104,
				}, {
					-- The title scrolls with the form so it never covers the entry
					-- or actions when the native keyboard leaves only a short viewport.
					Title = c(CandyTitle, {
						Text = "JOIN PARTY",
						TextSize = if compact then J.CompactTitleSize else J.TitleSize,
						Native = {
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.fromScale(0.05, J.TitleCenter),
							Size = UDim2.new(
								0.9,
								0,
								0,
								math.min(J.TitleHeight, layout.contentHeight * J.TitleHeightScale)
							),
							ZIndex = 106,
						},
					}),
					Instruction = c(ResponsiveText, {
						MeasurementFont = T.Type.Label,
						MaxTextSize = T.Type.Minimum,
						MinTextSize = 14,
						Native = {
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundTransparency = 1,
							Font = T.Type.Label,
							Position = UDim2.fromScale(0.05, J.InstructionCenter),
							Size = UDim2.fromScale(0.9, 0.08),
							Text = "Enter your friend's 6-digit party code.",
							TextColor3 = C.InkSoft,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 105,
						},
					}),
					EntryBox = c(Well, {
						Candy = true,
						Native = {
							Position = UDim2.fromScale(0.05, JoinCodeLayout.EntryTop),
							Size = UDim2.fromScale(0.9, J.EntryHeightScale),
							ZIndex = 105,
						},
					}, {
						Holder = c("Frame", {
							BackgroundTransparency = 1,
							Position = UDim2.fromOffset(J.EntryInset, J.EntryInset),
							Size = UDim2.new(1, -J.EntryInset * 2, 1, -J.EntryInset * 2),
							ZIndex = 106,
						}, digits),
						InputCapture = c("TextBox", {
							ref = inputRef,
							BackgroundTransparency = 1,
							ClearTextOnFocus = false,
							FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
							MultiLine = false,
							ShowNativeInput = true,
							Size = UDim2.fromScale(1, 1),
							Text = code,
							TextColor3 = Color3.new(),
							TextEditable = not submitting and props.FocusEnabled ~= false,
							TextSize = 14,
							TextTransparency = 1,
							ZIndex = 112,
							[React.Change.Text] = function(input: TextBox)
								local nextCode = sanitize(input.Text)
								setCode(nextCode)
								if input.Text ~= nextCode then
									input.Text = nextCode
									input.CursorPosition = #nextCode + 1
								end
							end,
							[React.Event.FocusLost] = function(
								_input: TextBox,
								enterPressed: boolean,
								input: InputObject?
							)
								setInputFocused(false)
								if
									input
									and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1)
									and input.UserInputState ~= Enum.UserInputState.End
									and input.UserInputState ~= Enum.UserInputState.Cancel
								then
									keyboardDismissInput.current = input
								end
								focusRevision.current += 1
								if focusAllowedRef.current then
									resumeFocusRef.current = false
								end
								if enterPressed then
									submit()
								end
							end,
							[React.Event.Focused] = function()
								setInputFocused(true)
								resumeFocusRef.current = true
							end,
							[React.Event.ReturnPressedFromOnScreenKeyboard] = submit,
						}),
					}),
					Buttons = c("Frame", {
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, JoinCodeLayout.ActionBottom),
						Size = UDim2.new(
							0.9,
							0,
							0,
							math.max(T.Layout.MinTarget, layout.contentHeight * J.ActionHeightScale)
						),
						ZIndex = 105,
					}, {
						UIListLayout = c("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Padding = UDim.new(0, J.ActionGap),
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						Confirm = c(PuffyButton, {
							Color = C.Pink,
							Shadow = false,
							Enabled = canSubmit,
							Text = if submitting then "JOINING…" else "JOIN PARTY",
							TextColor = if canSubmit then C.Surface else C.Ink,
							TextSize = if compact then T.Type.Minimum else T.Type.TileLabel,
							EntranceDelay = 0.025,
							Native = {
								LayoutOrder = 2,
								Size = UDim2.new(0.5, -J.ActionGap / 2, 1, 0),
								ZIndex = 106,
							},
							OnActivated = submit,
						}),
						Cancel = c(PuffyButton, {
							Enabled = props.FocusEnabled ~= false,
							Text = if submitting then "CLOSE" else "CANCEL",
							TextSize = if compact then T.Type.Minimum else T.Type.TileLabel,
							TextColor = C.Ink,
							Color = C.SurfaceWarm,
							LipColor = C.WellLine,
							Shadow = false,
							Native = {
								LayoutOrder = 1,
								Size = UDim2.new(0.5, -J.ActionGap / 2, 1, 0),
								ZIndex = 106,
							},
							OnActivated = close,
						}),
					}),
					ErrorText = c(ResponsiveText, {
						HostName = "ErrorText",
						MeasurementFont = T.Type.Label,
						MaxTextSize = T.Type.Minimum,
						MinTextSize = 14,
						Wrapped = true,
						Native = {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Font = T.Type.Label,
							Position = UDim2.fromScale(0.5, J.ErrorCenter),
							Size = UDim2.new(0.9, 0, 0, math.max(28, layout.contentHeight * 0.0741377)),
							Text = errorText,
							TextColor3 = errorColor,
							TextWrapped = true,
							ZIndex = 105,
						},
					}),
				}),
			}),
		}),
	})
end
