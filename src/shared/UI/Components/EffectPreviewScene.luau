--!strict

-- Full-scene audition controls. The portal stays visible while the underlying
-- menu is suspended, preserving its item selection and back stack.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local PreviewClient = require(script.Parent.Parent.Services.CosmeticPreviewClient)
local DeviceClass = require(script.Parent.Parent.Parent.Game.Input.DeviceClass)
local useExternalStore = require(script.Parent.Parent.Hooks.useExternalStore)
local ResponsiveText = require(script.Parent.ResponsiveText)
local PriceButton = require(script.Parent.Shop.ShopPriceButton)
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
		MeasurementFont = if heading then Enum.Font.LuckiestGuy else UIConfig.Text.BodyFont,
		MaxTextSize = maximum,
		Wrapped = true,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Font = if heading then Enum.Font.LuckiestGuy else UIConfig.Text.BodyFont,
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeColor3 = colors.Ink,
			TextStrokeTransparency = if heading then 1 else 0.35,
		},
	}, {
		Outline = if heading
			then c("UIStroke", {
				Color = colors.Ink,
				Thickness = 0.045,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			})
			else nil,
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
					if mounted and DeviceClass.current() == "Gamepad" and Selection.isSelectable(backRef.current) then
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
				DeviceClass.current() == "Gamepad"
				and (selected == nil or (screen ~= nil and selected:IsDescendantOf(screen)))
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
		elseif not snapshot.ready then "PREPARING PREVIEW…"
		else nil
	local controlsHeight = if message then 114 else 68
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
					Size = UDim2.new(0.9, 0, 0, controlsHeight),
					BackgroundColor3 = colors.Panel,
					BorderSizePixel = 0,
					SelectionGroup = true,
					SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
					SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
					SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
					SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
				}, {
					Constraint = c("UISizeConstraint", { MaxSize = Vector2.new(560, controlsHeight) }),
					Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Radius.Control) }),
					Outline = c("UIStroke", { Color = colors.White, Thickness = 2 }),
					Message = if message
						then textLabel(message, UDim2.fromOffset(14, 6), UDim2.new(1, -28, 0, 40), 17, false)
						else nil,
					Replay = c(PriceButton, {
						Enabled = snapshot.ready and snapshot.canReplay,
						Red = true,
						Compact = true,
						OnActivated = PreviewClient.replay,
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0.04, 0, 1, -12),
						Size = UDim2.new(0.44, 0, 0, 48),
						Text = if isSound
							then "PLAY SOUND"
							elseif snapshot.replayRevision == 0 then "PLAY EFFECT"
							else "PLAY AGAIN",
						TextSize = 21,
					}),
					Back = c(PriceButton, {
						ButtonRef = backRef,
						Compact = true,
						OnActivated = function()
							if sessionRef.current then
								PreviewClient.close(sessionRef.current)
							else
								closeRef.current()
							end
						end,
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0.52, 0, 1, -12),
						Size = UDim2.new(0.44, 0, 0, 48),
						Text = "BACK",
						TextSize = 21,
					}),
				}),
			}),
		}),
		Players.LocalPlayer:WaitForChild("PlayerGui")
	)
end
