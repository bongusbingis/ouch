-- Name: JoinCodeModal.luau
-- Author: Jack C.
-- Description: Modal for entering a six-digit party join code, with per-digit boxes, focus handling, validation, and error feedback.
-- Created: 2026-08-17

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)

local c = React.createElement
local CODE_LENGTH = 6
local HELP_TEXT = "Ex: 123-456"

local function sanitize(text: string): string
	return string.sub(string.gsub(text, "%D", ""), 1, CODE_LENGTH)
end

local function actionText(text: string, position: UDim2, size: UDim2)
	return c(ResponsiveText, {
		MeasurementFont = Enum.Font.LuckiestGuy,
		MaxTextSize = 32,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
			Position = position,
			Size = size,
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 2,
		},
	})
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
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.4,
		LayoutOrder = props.LayoutOrder,
		Position = UDim2.fromScale(0.409565, 0.0598802),
		Size = UDim2.fromScale(0.8, 0.8),
	}, {
		EntranceScale = c("UIScale", { Scale = styles.Scale }),
		UIAspectRatioConstraint = c("UIAspectRatioConstraint"),
		UICorner = c("UICorner", {
			BottomLeftRadius = UDim.new(0, 20),
			BottomRightRadius = UDim.new(0, 20),
			TopLeftRadius = UDim.new(0, 20),
			TopRightRadius = UDim.new(0, 20),
		}),
		UIStroke = c("UIStroke", {
			Color = Color3.fromRGB(171, 171, 171),
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.01,
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
				Position = UDim2.fromScale(0.5, 0.599059),
				Size = UDim2.fromScale(0.8, 0.8),
				Text = props.Character,
				TextColor3 = Color3.fromRGB(63, 63, 63),
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
	local panelSize = ResponsiveLayout.panelSize(
		safeArea.size,
		UIConfig.Layout.Panels.JoinCode,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local inputRef = React.useRef(nil)
	local previousSelection = React.useRef(nil)
	local focusRevision = React.useRef(0)
	local errorRevision = React.useRef(0)
	local submitRevision = React.useRef(0)
	local openRef = React.useRef(props.Open)
	local focusAllowedRef = React.useRef(props.Open and props.FocusEnabled ~= false)
	local closingRef = React.useRef(false)
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

	local function scheduleFocus(delay: number?)
		focusRevision.current += 1
		local revision = focusRevision.current
		task.delay(delay or 0.1, function()
			local input = inputRef.current
			if
				revision == focusRevision.current
				and focusAllowedRef.current
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
		setErrorColor(Color3.fromRGB(255, 0, 0))
		task.delay(3, function()
			if revision == errorRevision.current then
				setErrorText(HELP_TEXT)
				setErrorColor(Color3.new(1, 1, 1))
			end
		end)
	end

	local function close()
		closingRef.current = true
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
		if submitting or #code ~= CODE_LENGTH then
			return
		end
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
			setSubmitting(false)
			if success then
				close()
			elseif openRef.current then
				if message then
					showError(message)
				end
				scheduleFocus()
			end
		end)
	end

	React.useEffect(function()
		if not props.Open then
			closingRef.current = true
			submitRevision.current += 1
			return
		end
		closingRef.current = false
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
				input:ReleaseFocus()
			end
		else
			closingRef.current = false
			scheduleFocus(0)
		end
	end, { props.Open, props.FocusEnabled })

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
			MeasurementFont = Enum.Font.SourceSans,
			MaxTextSize = 42,
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = 4,
				Position = UDim2.fromScale(0.500703, 0.109386),
				Size = UDim2.fromScale(0.0492974, 0.781228),
				Text = "-",
				TextColor3 = Color3.fromRGB(26, 194, 230),
			},
		}),
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0.01, 0),
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

	local canSubmit = #code == CODE_LENGTH and not submitting
	return c("TextButton", {
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.35,
		Selectable = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
	}, {
		Panel = c("ImageLabel", {
			Active = true,
			ZIndex = 101,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://124751224634629",
			Position = UDim2.fromScale(0.5, 0.534555),
			Rotation = modalStyles.Rotation,
			ScaleType = Enum.ScaleType.Slice,
			SelectionGroup = true,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
			SliceCenter = Rect.new(31, 41, 978, 620),
			SliceScale = 0.5,
			Visible = true,
		}, {
			ModalScale = c("UIScale", { Scale = modalStyles.Scale }),
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
			}),
			Frame = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderColor3 = Color3.new(),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.202036),
				Size = UDim2.fromScale(0.8, 0.015),
			}),
			Title2 = c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.Highway,
				MaxTextSize = 32,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
					Position = UDim2.fromScale(0.5, 0.275),
					Size = UDim2.fromScale(0.9, 0.0881433),
					Text = "Type the 6-digit code to join a party",
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 2,
				},
			}),
			EntryBox = c("ImageLabel", {
				BackgroundTransparency = 1,
				Image = "rbxassetid://130293277730649",
				Position = UDim2.fromScale(0.05, 0.333456),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(0.9, 0.34441),
				SliceCenter = Rect.new(61, 58, 958, 139),
				SliceScale = 0.5,
			}, {
				Holder = c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.0137874, -0.0459255),
					Size = UDim2.fromScale(0.962774, 1.04593),
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
					TextEditable = true,
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
					[React.Event.FocusLost] = function(_input: TextBox, enterPressed: boolean)
						if enterPressed then
							submit()
						end
						if focusAllowedRef.current and not closingRef.current then
							scheduleFocus()
						end
					end,
					[React.Event.ReturnPressedFromOnScreenKeyboard] = submit,
				}),
			}),
			Buttons = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.944206),
				Size = UDim2.fromScale(0.8, 0.158129),
			}, {
				UIListLayout = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.03, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				Confirm = c(AnimatedButton, {
					Enabled = canSubmit,
					EntranceDelay = 0.025,
					Native = {
						AutoButtonColor = canSubmit,
						BackgroundTransparency = 1,
						Image = "rbxassetid://136021539696619",
						ImageColor3 = if canSubmit then Color3.new(1, 1, 1) else Color3.fromRGB(110, 110, 110),
						LayoutOrder = 3,
						Position = UDim2.fromScale(0.153547, 0),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromScale(0.334921, 1),
						SliceCenter = Rect.new(198, 228, 841, 468),
						SliceScale = 0.2,
					},
					OnActivated = submit,
				}, {
					TextLabel = actionText(
						"CONFIRM",
						UDim2.fromScale(0.48792, 0.57964),
						UDim2.fromScale(0.685479, 0.6712)
					),
					UISizeConstraint = c("UISizeConstraint", {
						MinSize = Vector2.new(0, UIConfig.Interaction.MinTargetPx),
					}),
				}),
				Cancel = c(AnimatedButton, {
					Enabled = not submitting,
					EntranceDelay = 0,
					Native = {
						BackgroundTransparency = 1,
						Image = "rbxassetid://94748581468730",
						LayoutOrder = 2,
						Position = UDim2.fromScale(0.520694, 0),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromScale(0.277094, 1),
						SliceCenter = Rect.new(198, 228, 841, 468),
						SliceScale = 0.2,
					},
					OnActivated = close,
				}, {
					TextLabel = actionText(
						"CANCEL",
						UDim2.fromScale(0.463449, 0.57964),
						UDim2.fromScale(0.680654, 0.6712)
					),
					UISizeConstraint = c("UISizeConstraint", {
						MinSize = Vector2.new(0, UIConfig.Interaction.MinTargetPx),
					}),
				}),
			}),
			ErrorText = c(ResponsiveText, {
				HostName = "ErrorText",
				MeasurementFont = Enum.Font.Highway,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
					Position = UDim2.fromScale(0.495, 0.73),
					Size = UDim2.fromScale(0.9, 0.0741377),
					Text = errorText,
					TextColor3 = errorColor,
					ZIndex = 2,
				},
			}),
		}),
	})
end
