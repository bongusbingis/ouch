-- Description: The full loading screen: progress, status copy, rotating tips, and the retry and continue actions, rendered purely from the props its adapter supplies.

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local ActivityDots = require(script.Parent.ActivityDots)
local AnimatedButton = require(script.Parent.AnimatedButton)
local LoadingBackdrop = require(script.Parent.LoadingBackdrop)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Selection = require(script.Parent.Parent.Services.Selection)

local c = React.createElement

local BLUE_BUTTON = "rbxassetid://136021539696619"
local RED_BUTTON = "rbxassetid://94748581468730"
local PANEL_IMAGE = "rbxassetid://124751224634629"
local LOGO_IMAGE = "rbxassetid://78333957912633"
local DARK = Color3.fromRGB(24, 41, 48)
local COMPLETION = Color3.fromRGB(255, 211, 51)

export type LoadingAction = {
	Text: string,
	Color: "Blue" | "Red",
	OnActivated: () -> (),
}

export type Props = {
	Visible: boolean,
	Title: string,
	Detail: string?,
	Tip: string?,
	Progress: number?,
	PrimaryAction: LoadingAction?,
	SecondaryAction: LoadingAction?,
	OnPresented: (() -> ())?,
	Static: boolean?,
	ParentScreenInsets: Enum.ScreenInsets?,
}

local function textStroke(thickness: number)
	return c("UIStroke", {
		Color = DARK,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = thickness,
		Transparency = 0.08,
	})
end

local function actionButton(action: LoadingAction, layoutOrder: number, actionCount: number, buttonRef: any?)
	return c(AnimatedButton, {
		ButtonRef = buttonRef,
		Native = {
			BackgroundTransparency = 1,
			Image = if action.Color == "Red" then RED_BUTTON else BLUE_BUTTON,
			LayoutOrder = layoutOrder,
			ScaleType = Enum.ScaleType.Slice,
			Size = if actionCount == 1 then UDim2.fromScale(0.46, 1) else UDim2.fromScale(0.42, 1),
			SliceCenter = Rect.new(198, 228, 841, 468),
			SliceScale = 0.14,
			ZIndex = 105,
		},
		OnActivated = action.OnActivated,
	}, {
		TextLabel = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 32,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.5, 0.56),
				Size = UDim2.fromScale(0.82, 0.62),
				Text = action.Text,
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 106,
			},
		}, {
			UIStroke = textStroke(0.05),
		}),
		UIAspectRatioConstraint = c("UIAspectRatioConstraint", {
			AspectRatio = 3.1,
		}),
	})
end

return function(props: Props)
	local safeArea = useSafeArea(props.ParentScreenInsets or Enum.ScreenInsets.CoreUISafeInsets)
	local panelSize = ResponsiveLayout.panelSize(
		safeArea.size,
		UIConfig.Layout.Panels.Loading,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local reducedMotion = useReducedMotion()
	local present, setPresent = React.useState(props.Visible)
	local rootRef = React.useRef(nil)
	local transitionRevision = React.useRef(0)
	local focusRevision = React.useRef(0)
	local firstActionRef = React.useRef(nil)
	local previousSelection = React.useRef(nil)
	local onPresentedRef = React.useRef(props.OnPresented)
	onPresentedRef.current = props.OnPresented
	local hasActions = props.PrimaryAction ~= nil or props.SecondaryAction ~= nil
	local styles, api = ReactSpring.useSpring(function()
		return {
			Transparency = if props.Visible then 0 else 1,
		}
	end)
	local progressStyles = ReactSpring.useSpring({
		Progress = math.clamp(props.Progress or 0, 0, 1),
		config = Motion.Modal,
		immediate = reducedMotion or props.Static == true,
	})

	React.useEffect(function()
		transitionRevision.current += 1
		local revision = transitionRevision.current
		local immediate = reducedMotion or props.Static == true
		if props.Visible then
			setPresent(true)
			api.start({
				Transparency = 0,
				config = Motion.Modal,
				immediate = immediate,
			})
		else
			api.start({
				Transparency = 1,
				config = Motion.Modal,
				immediate = immediate,
			}):andThen(function()
				if transitionRevision.current == revision then
					setPresent(false)
				end
			end)
		end
		return function()
			transitionRevision.current += 1
		end
	end, { props.Visible, props.Static, reducedMotion })

	React.useEffect(function()
		if not props.Visible or not present then
			return
		end
		local cancelled = false
		task.defer(function()
			if cancelled or rootRef.current == nil then
				return
			end
			local onPresented = onPresentedRef.current
			if onPresented then
				onPresented()
			end
		end)
		return function()
			cancelled = true
		end
	end, { props.Visible, present })

	React.useEffect(function()
		return function()
			transitionRevision.current += 1
			api.stop()
		end
	end, {})

	React.useEffect(function()
		if not props.Visible or props.Static == true then
			return
		end
		previousSelection.current = GuiService.SelectedObject
		GuiService.SelectedObject = nil
		return function()
			local selection = previousSelection.current
			previousSelection.current = nil
			if Selection.isSelectable(selection) then
				GuiService.SelectedObject = selection
			end
		end
	end, { props.Visible, props.Static })

	React.useEffect(function()
		focusRevision.current += 1
		local revision = focusRevision.current
		if props.Visible and props.Static ~= true and hasActions then
			task.defer(function()
				local button = firstActionRef.current
				if focusRevision.current == revision and Selection.isSelectable(button) then
					GuiService.SelectedObject = button
				end
			end)
		end
		return function()
			focusRevision.current += 1
		end
	end, { props.Visible, props.Static, hasActions })

	if not present then
		return nil
	end

	local actions = {}
	if props.PrimaryAction then
		table.insert(actions, props.PrimaryAction)
	end
	if props.SecondaryAction then
		table.insert(actions, props.SecondaryAction)
	end
	local showActivity = not hasActions and props.Progress == nil and props.Static ~= true
	local showProgress = not hasActions and props.Progress ~= nil
	local actionChildren = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.04, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index, action in actions do
		actionChildren[`Action{index}`] =
			actionButton(action, index, #actions, if index == 1 then firstActionRef else nil)
	end

	return c(LoadingBackdrop, {
		Native = {
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			SelectionGroup = hasActions,
		},
		RootRef = rootRef,
		Transparency = styles.Transparency,
	}, {
		SafeArea = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(safeArea.position.X, safeArea.position.Y),
			Size = UDim2.fromOffset(safeArea.size.X, safeArea.size.Y),
			ZIndex = 101,
		}, {
			Logo = c("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = LOGO_IMAGE,
				Position = UDim2.fromScale(0.5, 0.19),
				Size = UDim2.fromScale(0.23, 0.23),
				ZIndex = 101,
			}, {
				UIAspectRatioConstraint = c("UIAspectRatioConstraint", {
					AspectRatio = 1.55,
				}),
				UISizeConstraint = c("UISizeConstraint", {
					MaxSize = Vector2.new(500, 323),
					MinSize = Vector2.new(math.min(170, safeArea.size.X * 0.7), math.min(110, safeArea.size.Y * 0.2)),
				}),
			}),
			StatusPanel = c("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = PANEL_IMAGE,
				Position = UDim2.fromScale(0.5, 0.56),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
				SliceCenter = Rect.new(31, 41, 978, 620),
				SliceScale = 0.35,
				ZIndex = 102,
			}, {
				Title = c(ResponsiveText, {
					HostName = "Title",
					MeasurementFont = Enum.Font.LuckiestGuy,
					MaxTextSize = 62,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						Position = UDim2.fromScale(0.5, if props.Detail then 0.3 else 0.43),
						Size = UDim2.fromScale(0.82, 0.25),
						Text = props.Title,
						TextColor3 = Color3.new(1, 1, 1),
						ZIndex = 103,
					},
				}, {
					UIStroke = textStroke(0.045),
				}),
				Detail = if props.Detail
					then c(ResponsiveText, {
						HostName = "Detail",
						MeasurementFont = Enum.Font.Highway,
						MaxTextSize = 38,
						Native = {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/HighwayGothic.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.5, if props.Static then 0.61 else 0.51),
							Size = UDim2.fromScale(0.84, 0.18),
							Text = props.Detail,
							TextColor3 = Color3.new(1, 1, 1),
							ZIndex = 103,
						},
					}, {
						UIStroke = textStroke(0.025),
					})
					else nil,
				ActivityDots = if showActivity
					then c(ActivityDots, {
						Active = props.Visible,
						Native = {
							Position = UDim2.fromScale(0.5, 0.72),
							Size = UDim2.fromScale(0.12, 0.13),
							ZIndex = 103,
						},
					})
					else nil,
				Progress = if showProgress
					then c("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = DARK,
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, 0.72),
						Size = UDim2.fromScale(0.66, 0.075),
						ZIndex = 103,
					}, {
						UICorner = c("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),
						UIPadding = c("UIPadding", {
							PaddingBottom = UDim.new(0.17, 0),
							PaddingLeft = UDim.new(0.012, 0),
							PaddingRight = UDim.new(0.012, 0),
							PaddingTop = UDim.new(0.17, 0),
						}),
						InnerBar = c("Frame", {
							BackgroundColor3 = COMPLETION,
							BorderSizePixel = 0,
							Size = progressStyles.Progress:map(function(value: number)
								return UDim2.fromScale(value, 1)
							end),
							ZIndex = 104,
						}, {
							UICorner = c("UICorner", {
								CornerRadius = UDim.new(1, 0),
							}),
						}),
					})
					else nil,
				Actions = if hasActions
					then c("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.76),
						Size = UDim2.fromScale(0.82, 0.22),
						ZIndex = 104,
					}, actionChildren)
					else nil,
			}),
			Tip = if props.Tip and not props.Static
				then c(ResponsiveText, {
					HostName = "Tip",
					MeasurementFont = Enum.Font.Highway,
					MaxTextSize = 30,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/HighwayGothic.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0.5, 0.84),
						Size = UDim2.fromScale(0.78, 0.07),
						Text = props.Tip,
						TextColor3 = Color3.new(1, 1, 1),
						ZIndex = 101,
					},
				}, {
					UIStroke = textStroke(0.022),
				})
				else nil,
		}),
	})
end
