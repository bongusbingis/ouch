--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local GameModeCard = require(script.Parent.GameModeCard)
local ResponsiveText = require(script.Parent.ResponsiveText)
local VoteLoadingBar = require(script.Parent.VoteLoadingBar)
local Motion = require(script.Parent.Parent.Motion)
local TextMetrics = require(script.Parent.Parent.TextMetrics)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)

local c = React.createElement
local REFERENCE_VIEWPORT = Vector2.new(1890, 1200)
local VOTE_TEXT_BOUNDS = TextMetrics.scaleBounds(REFERENCE_VIEWPORT, Vector2.new(0.967519, 0.0574598))
	- Vector2.new(2, 2)
local VOTE_TEXT_STROKE = TextMetrics.scaledTextStroke(3.8, "Vote for a game mode!", Enum.Font.Highway, VOTE_TEXT_BOUNDS)

export type Props = {
	Active: boolean,
	Modes: { GameModeCard.Mode },
	EndsAt: number,
	DurationSeconds: number,
	OnVote: (string) -> (),
}

return function(props: Props)
	local present, setPresent = React.useState(props.Active)
	local revision = React.useRef(0)
	local focusRevision = React.useRef(0)
	local firstButtonRef = React.useRef(nil)
	local previousSelection = React.useRef(nil)
	local reducedMotion = useReducedMotion()
	local styles, api = ReactSpring.useSpring(function()
		return {
			Position = UDim2.fromScale(0, 0.06),
		}
	end)

	React.useEffect(function()
		revision.current += 1
		local currentRevision = revision.current
		if props.Active then
			setPresent(true)
			api.start({
				Position = UDim2.fromScale(0, 0),
				config = Motion.Modal,
				immediate = reducedMotion,
			})
		else
			api.start({
				Position = UDim2.fromScale(0, 0.06),
				config = Motion.Modal,
				immediate = reducedMotion,
			}):andThen(function()
				if revision.current == currentRevision then
					setPresent(false)
				end
			end)
		end
		return function()
			revision.current += 1
		end
	end, { props.Active, reducedMotion })

	React.useEffect(function()
		focusRevision.current += 1
		local currentFocusRevision = focusRevision.current
		if props.Active then
			if previousSelection.current == nil then
				previousSelection.current = GuiService.SelectedObject
			end
			task.defer(function()
				if focusRevision.current ~= currentFocusRevision then
					return
				end
				local button = firstButtonRef.current
				if button and button.Parent and button.Visible and button.Selectable then
					GuiService.SelectedObject = button
				end
			end)
		else
			local selection = previousSelection.current
			previousSelection.current = nil
			if selection and selection.Parent and selection.Visible and selection.Selectable then
				GuiService.SelectedObject = selection
			end
		end
		return function()
			focusRevision.current += 1
		end
	end, { props.Active })

	React.useEffect(function()
		return function()
			api.stop()
		end
	end, {})

	if not present then
		return nil
	end

	local cards = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index, mode in props.Modes do
		cards[mode.Id] = c(GameModeCard, {
			Mode = mode,
			Enabled = props.Active,
			OnVote = props.OnVote,
			ButtonRef = if index == 1 then firstButtonRef else nil,
		})
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Position = styles.Position,
		SelectionGroup = true,
		SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
		SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
		SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
		Size = UDim2.fromScale(1, 1),
	}, {
		Logo = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = "rbxassetid://78333957912633",
			Position = UDim2.fromScale(0, -0.000749383),
			Size = UDim2.fromScale(0.321542, 0.301659),
		}, {
			UIAspectRatioConstraint = c("UIAspectRatioConstraint", {
				AspectRatio = 1.55,
			}),
		}),
		VoteText = c(ResponsiveText, {
			HostName = "VoteText",
			MeasurementFont = Enum.Font.Highway,
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/HighwayGothic.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.522751, 0.300167),
				Size = UDim2.fromScale(0.967519, 0.0574598),
				Text = "Vote for a game mode!",
				TextColor3 = Color3.new(1, 1, 1),
			},
		}, {
			UIStroke = c("UIStroke", {
				Color = Color3.fromRGB(77, 77, 77),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = VOTE_TEXT_STROKE,
			}),
		}),
		ModesHolder = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.573),
			Size = UDim2.fromScale(0.944456, 0.562031),
		}, cards),
		LoadingBar = c(VoteLoadingBar, {
			Active = props.Active,
			EndsAt = props.EndsAt,
			DurationSeconds = props.DurationSeconds,
		}),
	})
end
