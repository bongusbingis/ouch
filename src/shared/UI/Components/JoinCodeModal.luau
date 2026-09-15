-- Description: Modal for entering a six-digit party join code, with per-digit boxes, focus handling, validation, and error feedback.

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local PriceButton = require(script.Parent.Shop.ShopPriceButton)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local JoinCodeLayout = require(script.Parent.Parent.Models.JoinCodeLayout)
local ScrollFrame = require(script.Parent.ScrollFrame)
local Well = require(script.Parent.Well)

local modalSurface = require(script.Parent.ModalSurface)

local c = React.createElement
local Palette = UIConfig.ProgressionStyle
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
		BackgroundColor3 = Palette.PanelRaised,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Position = UDim2.fromScale(0.409565, 0.0598802),
		Size = UDim2.new(0.95 / 6, -8, 1, 0),
	}, {
		EntranceScale = c("UIScale", { Scale = styles.Scale }),
		UIAspectRatioConstraint = c("UIAspectRatioConstraint"),
		UICorner = c("UICorner", {
			CornerRadius = UDim.new(0, UIConfig.Radius.Tile),
		}),
		UIStroke = c("UIStroke", {
			Color = Palette.White,
			Thickness = 2,
		}),
		Char = c(ResponsiveText, {
			HostName = "Char",
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 50,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				LayoutOrder = 3,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.8),
				Text = props.Character,
				TextColor3 = Palette.White,
			},
		}, {
			Outline = c("UIStroke", {
				Color = Palette.Ink,
				Thickness = 0.045,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			}),
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
	local errorText, setErrorText = React.useState(HELP_TEXT)
	local errorColor, setErrorColor = React.useState(Color3.new(1, 1, 1))
	local submitting, setSubmitting = React.useState(false)
	local reducedMotion = useReducedMotion()
	local modalStyles = ReactSpring.useSpring({
		Scale = if props.Open then 1 else 0.82,
		Rotation = if props.Open then 0 else -2,
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
		setErrorColor(Palette.Yellow)
		task.delay(3, function()
			if revision == errorRevision.current then
				setErrorText(HELP_TEXT)
				setErrorColor(Color3.new(1, 1, 1))
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
		setErrorColor(Color3.new(1, 1, 1))
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
		setErrorColor(Color3.new(1, 1, 1))
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
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 42,
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = 4,
				Position = UDim2.fromScale(0.500703, 0.109386),
				Size = UDim2.fromScale(0.05, 1),
				Text = "-",
				Font = Enum.Font.LuckiestGuy,
				TextColor3 = Palette.White,
			},
		}, {
			Outline = c("UIStroke", {
				Color = Palette.Ink,
				Thickness = 0.045,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			}),
		}),
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index = 1, CODE_LENGTH do
		digits[`Digit{index}`] = c(DigitBox, {
			LayoutOrder = if index <= 3 then index else index + 1,
			Delay = (index - 1) * 0.025,
			Character = string.sub(code, index, index),
		})
	end

	local canSubmit = #code == CODE_LENGTH and not submitting and props.FocusEnabled ~= false
	return modalSurface({
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.35,
		Selectable = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		[React.Change.AbsolutePosition] = function(root: GuiObject)
			setRootPosition(root.AbsolutePosition)
		end,
	}, {
		Panel = c("ImageLabel", {
			Active = true,
			ZIndex = 101,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = UIConfig.Layout.PageSurface.Image,
			Position = if layout.position
				then UDim2.fromOffset(layout.position.X, layout.position.Y)
				else UDim2.fromScale(0.5, 0.534555),
			Rotation = if layout.position then 0 else modalStyles.Rotation,
			ScaleType = Enum.ScaleType.Slice,
			SelectionGroup = true,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
			SliceCenter = UIConfig.Layout.PageSurface.SliceCenter,
			SliceScale = UIConfig.Layout.PageSurface.SliceScale,
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
				ScrollBarThickness = if layout.scrolling then 6 else 0,
				ScrollBarImageColor3 = Palette.White,
			}, {
				Content = c("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, layout.contentHeight),
				}, {
					Title = c(ResponsiveText, {
						HostName = "Title",
						MeasurementFont = Enum.Font.LuckiestGuy,
						MaxTextSize = 46,
						Native = {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
							Position = UDim2.fromScale(0.5, 0.147601),
							Size = UDim2.fromScale(0.9, 0.144798),
							Text = "ENTER PARTY CODE",
							TextColor3 = Color3.new(1, 1, 1),
							ZIndex = 2,
						},
					}, {
						Outline = c("UIStroke", {
							Color = Palette.Ink,
							Thickness = 0.045,
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						}),
					}),
					Frame = c("Frame", {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BorderColor3 = Color3.new(),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, 0.202036),
						Size = UDim2.new(0.8, 0, 0, 2),
					}),
					EntryBox = c(Well, {
						Native = {
							Position = UDim2.fromScale(0.05, JoinCodeLayout.EntryTop),
							Size = UDim2.fromScale(0.9, 0.34441),
						},
					}, {
						Holder = c("Frame", {
							BackgroundTransparency = 1,
							Position = UDim2.fromOffset(
								UIConfig.Spacing.CompactInsetPx,
								UIConfig.Spacing.CompactInsetPx
							),
							Size = UDim2.new(
								1,
								-UIConfig.Spacing.CompactInsetPx * 2,
								1,
								-UIConfig.Spacing.CompactInsetPx * 2
							),
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
								resumeFocusRef.current = true
							end,
							[React.Event.ReturnPressedFromOnScreenKeyboard] = submit,
						}),
					}),
					Buttons = c("Frame", {
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, JoinCodeLayout.ActionBottom),
						Size = UDim2.fromScale(0.8, 0.158129),
					}, {
						UIListLayout = c("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Padding = UDim.new(0.03, 0),
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						Confirm = c(PriceButton, {
							Color = Palette.Pink,
							Enabled = canSubmit,
							Text = if submitting then "JOINING…" else "JOIN PARTY",
							TextSize = 24,
							EntranceDelay = 0.025,
							LayoutOrder = 3,
							AnchorPoint = Vector2.zero,
							Size = UDim2.fromScale(0.4, 1),
							OnActivated = submit,
						}),
						Cancel = c(PriceButton, {
							Enabled = props.FocusEnabled ~= false,
							Text = if submitting then "CLOSE" else "CANCEL",
							TextSize = 24,
							Color = Palette.Cyan,
							LayoutOrder = 2,
							AnchorPoint = Vector2.zero,
							Size = UDim2.fromScale(0.4, 1),
							OnActivated = close,
						}),
					}),
					ErrorText = c(ResponsiveText, {
						HostName = "ErrorText",
						MeasurementFont = UIConfig.Text.BodyFont,
						Native = {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Font = UIConfig.Text.BodyFont,
							Position = UDim2.fromScale(0.495, 0.73),
							Size = UDim2.fromScale(0.9, 0.0741377),
							Text = errorText,
							TextColor3 = errorColor,
							TextStrokeColor3 = Palette.Ink,
							TextStrokeTransparency = 0.35,
							ZIndex = 2,
						},
					}),
				}),
			}),
		}),
	})
end
