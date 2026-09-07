--!strict

-- Full-scene audition controls. The portal stays visible while the underlying
-- menu is suspended, preserving its item selection and back stack.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local Cosmetics = require(ReplicatedStorage.Config.Cosmetics.Cosmetics)
local UIConfig = require(ReplicatedStorage.Config.Interface.UI)
local PreviewClient = require(script.Parent.Parent.Services.CosmeticPreviewClient)
local DeviceClass = require(script.Parent.Parent.Parent.Game.Input.DeviceClass)
local useExternalStore = require(script.Parent.Parent.Hooks.useExternalStore)
local ResponsiveText = require(script.Parent.ResponsiveText)
local AnimatedButton = require(script.Parent.AnimatedButton)
local Selection = require(script.Parent.Parent.Services.Selection)

local c = React.createElement
local colors = UIConfig.ProgressionStyle

export type Props = {
	ItemId: string?,
	Category: string?,
	Enabled: boolean?,
	OnClose: () -> (),
}

local function textLabel(text: string, position: UDim2, size: UDim2, maximum: number, heading: boolean)
	return c(ResponsiveText, {
		MeasurementFont = if heading then Enum.Font.LuckiestGuy else Enum.Font.SourceSansBold,
		MaxTextSize = maximum,
		Wrapped = true,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Font = if heading then Enum.Font.LuckiestGuy else Enum.Font.SourceSansBold,
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeColor3 = colors.Ink,
			TextStrokeTransparency = if heading then 0.15 else 0.5,
		},
	})
end

return function(props: Props)
	local enabled = if props.Enabled ~= nil then props.Enabled else props.ItemId ~= nil
	local snapshot = useExternalStore(PreviewClient.getSnapshot, PreviewClient.subscribe)
	local closeRef = React.useRef(props.OnClose)
	closeRef.current = props.OnClose
	local backRef = React.useRef(nil)
	local screenRef = React.useRef(nil)
	local sessionRef = React.useRef(nil :: number?)
	React.useEffect(function()
		if not enabled then
			return
		end
		local sessionId = PreviewClient.open(props.ItemId, props.Category)
		sessionRef.current = sessionId
		local notified = false
		local function update(value)
			if value.sessionId == sessionId and not value.active and not notified then
				notified = true
				closeRef.current()
			end
		end
		local disconnect = PreviewClient.subscribe(update)
		update(PreviewClient.getSnapshot())
		return function()
			disconnect()
			sessionRef.current = nil
			PreviewClient.close(sessionId)
		end
	end, { enabled, props.ItemId, props.Category })

	React.useEffect(function()
		if not enabled then
			return
		end
		local previous = GuiService.SelectedObject
		local screen = screenRef.current
		local mounted = true
		local disconnect = DeviceClass.observe(function(input)
			if input == "Gamepad" then
				task.defer(function()
					if mounted and Selection.isSelectable(backRef.current) then
						GuiService.SelectedObject = backRef.current
					end
				end)
			end
		end)
		return function()
			mounted = false
			disconnect()
			local selected = GuiService.SelectedObject
			if
				(selected == nil or (screen ~= nil and selected:IsDescendantOf(screen)))
				and Selection.isSelectable(previous)
			then
				GuiService.SelectedObject = previous
			end
		end
	end, { enabled })

	if not enabled then
		return nil
	end
	local item = if props.ItemId then Cosmetics.Items[props.ItemId] else Cosmetics.Defaults[props.Category or ""]
	local isSound = item and item.ElimEffect ~= nil
	local title = if item then item.DisplayName else "PREVIEW"
	local message = if snapshot.error and snapshot.error ~= ""
		then snapshot.error
		elseif not snapshot.ready then "PREPARING PREVIEW"
		elseif isSound then "PLAY TO HEAR YOUR ELIMINATION SOUND"
		else "PLAY AGAIN TO SEE THE EFFECT IN ACTION"
	return ReactRoblox.createPortal(
		c("ScreenGui", {
			ref = screenRef,
			DisplayOrder = 180,
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			Root = c("Frame", {
				BackgroundTransparency = if snapshot.ready then 1 else 0,
				BackgroundColor3 = colors.Ink,
				Size = UDim2.fromScale(1, 1),
				Active = true,
			}, {
				Title = textLabel(
					string.upper(title),
					UDim2.fromScale(0.06, 0.045),
					UDim2.fromScale(0.88, 0.13),
					40,
					true
				),
				Controls = c("Frame", {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -16),
					Size = UDim2.new(0.9, 0, 0, 118),
					BackgroundColor3 = colors.Ink,
					BackgroundTransparency = 0.08,
					SelectionGroup = true,
					SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
					SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
					SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
					SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
				}, {
					Constraint = c("UISizeConstraint", { MaxSize = Vector2.new(560, 118) }),
					Corner = c("UICorner", { CornerRadius = UDim.new(0, 16) }),
					Message = textLabel(message, UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 44), 17, false),
					Replay = c(AnimatedButton, {
						Enabled = snapshot.ready and snapshot.canReplay,
						Style = "Primary",
						OnActivated = PreviewClient.replay,
						Native = {
							Position = UDim2.new(0.04, 0, 0, 58),
							Size = UDim2.new(0.44, 0, 0, 46),
							BackgroundColor3 = colors.Cyan,
						},
					}, {
						Corner = c("UICorner", { CornerRadius = UDim.new(0, 10) }),
						Label = textLabel(
							if isSound
								then "PLAY SOUND"
								elseif snapshot.replayRevision == 0 then "PLAY EFFECT"
								else "PLAY AGAIN",
							UDim2.new(),
							UDim2.fromScale(1, 1),
							21,
							true
						),
					}),
					Back = c(AnimatedButton, {
						ButtonRef = backRef,
						OnActivated = function()
							if sessionRef.current then
								PreviewClient.close(sessionRef.current)
							else
								closeRef.current()
							end
						end,
						Native = {
							Position = UDim2.new(0.52, 0, 0, 58),
							Size = UDim2.new(0.44, 0, 0, 46),
							BackgroundColor3 = colors.Raised,
						},
					}, {
						Corner = c("UICorner", { CornerRadius = UDim.new(0, 10) }),
						Label = textLabel("BACK", UDim2.new(), UDim2.fromScale(1, 1), 21, true),
					}),
				}),
			}),
		}),
		Players.LocalPlayer:WaitForChild("PlayerGui")
	)
end
