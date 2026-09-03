-- Name: CrateRevealModal.luau
-- Author: Jack C.
-- Description: Animated crate reveal: a rarity-scaled shake and burst that resolves into the item a single open produced, or a staggered grid for a bulk open, with skip, replay and duplicate-refund reporting.
-- Created: 2026-08-23

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local InventoryConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory"))
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveText = require(script.Parent.ResponsiveText)
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local ShopPreview = require(script.Parent.Shop.ShopPreview)
local UIFeedback = require(script.Parent.Parent.Services.UIFeedback)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)

local c = React.createElement

-- Rarity drives the whole pacing of the reveal: a Common resolves almost
-- immediately, a Legendary is held back so the wait itself reads as a signal
-- that something good is coming. Shake amplitude is in panel-scale units.
local RARITY_TIERS = {
	Common = { shake = 0.5, amplitude = 0.006, rays = 8, punch = 1.06, tone = 0 },
	Rare = { shake = 0.9, amplitude = 0.011, rays = 12, punch = 1.12, tone = 1 },
	Legendary = { shake = 1.5, amplitude = 0.018, rays = 18, punch = 1.2, tone = 2 },
	Exclusive = { shake = 1.8, amplitude = 0.022, rays = 22, punch = 1.24, tone = 3 },
}
local DEFAULT_TIER = RARITY_TIERS.Common
local BURST_SECONDS = 0.42
local GRID_STAGGER = 0.09

local function tierFor(rarity: string?)
	return (if rarity then RARITY_TIERS[rarity] else nil) or DEFAULT_TIER
end

local function rarityColor(rarity: string?): Color3
	return (if rarity then InventoryConfig.RarityColors[rarity] else nil) or Color3.new(1, 1, 1)
end

-- Ranks a batch so the summary can lead with the best pull. Lower is better;
-- the order mirrors Config.Cosmetics rarity weights without importing them,
-- because this is presentation ordering only and never decides a reward.
local RARITY_RANK = { Exclusive = 1, Legendary = 2, Rare = 3, Common = 4 }

local function rankOf(rarity: string?): number
	return (if rarity then RARITY_RANK[rarity] else nil) or 99
end

local function bestEntry(results: { any }): any?
	local best = nil
	for _, entry in results do
		if best == nil or rankOf(entry.rarity) < rankOf(best.rarity) then
			best = entry
		end
	end
	return best
end

local function burstRays(tier, color: Color3, alpha: number, zIndex: number)
	local rays = {}
	for index = 1, tier.rays do
		local angle = (index / tier.rays) * math.pi * 2
		local reach = 0.16 + alpha * 0.42
		rays[`Ray{index}`] = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = math.clamp(alpha, 0, 1),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5 + math.cos(angle) * reach, 0.5 + math.sin(angle) * reach),
			Rotation = math.deg(angle),
			Size = UDim2.fromScale(0.06 + (1 - alpha) * 0.05, 0.012),
			ZIndex = zIndex,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
	end
	return rays
end

local function subtitleFor(entry: any): string
	if entry.isDupe then
		return if entry.bonksRefund > 0 then `DUPLICATE  •  +{entry.bonksRefund} BONKS` else "DUPLICATE"
	end
	return string.upper(entry.rarity)
end

local function gridCell(entry: any, index: number, revealedCount: number, zIndex: number)
	local shown = index <= revealedCount
	local color = rarityColor(entry.rarity)
	return c("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = if shown then 0.25 else 0.85,
		BorderSizePixel = 0,
		LayoutOrder = index,
		ZIndex = zIndex,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0.12, 0) }),
		Stroke = c("UIStroke", {
			Color = color,
			Thickness = if shown then 2 else 0,
			Transparency = if shown then 0.1 else 1,
		}),
		Preview = if shown
			then c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.1, 0.06),
				Size = UDim2.fromScale(0.8, 0.6),
				ZIndex = zIndex + 1,
			}, {
				Content = c(ShopPreview, {
					Items = if entry.preview then { entry.preview } else {},
					Thumbnail = "",
					ZIndex = zIndex + 1,
				}),
			})
			else nil,
		Label = if shown
			then c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				MaxTextSize = 18,
				Native = {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.5, 0.98),
					Size = UDim2.fromScale(0.92, 0.28),
					Text = if entry.isDupe then `+{entry.bonksRefund}` else string.upper(entry.displayName),
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = zIndex + 2,
				},
			})
			else nil,
	})
end

return function(props)
	local safeArea = useSafeArea(Enum.ScreenInsets.DeviceSafeInsets)
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
	local panelSize = ResponsiveLayout.panelSize(
		safeArea.size,
		UIConfig.Layout.Panels.CrateReveal,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local reveal = props.Reveal
	local buttonRef = React.useRef(nil)
	local previousSelection = React.useRef(nil)
	local reducedMotion = useReducedMotion()
	local generation = React.useRef(0)

	local results = if reveal then reveal.results else nil
	local count = if results then #results else 0
	local isBulk = count > 1
	local headline = if results then (if isBulk then bestEntry(results) else results[1]) else nil
	local tier = tierFor(if headline then headline.rarity else nil)
	local color = rarityColor(if headline then headline.rarity else nil)

	local phase, setPhase = React.useState("Idle")
	local revealedCount, setRevealedCount = React.useState(0)

	local shakeStyles, shakeApi = ReactSpring.useSpring(function()
		return { Offset = 0 }
	end)
	local burstStyles, burstApi = ReactSpring.useSpring(function()
		return { Alpha = 1 }
	end)
	local itemStyles, itemApi = ReactSpring.useSpring(function()
		return { Scale = 0.4, Glow = 1 }
	end)

	local finish = React.useCallback(function()
		generation.current += 1
		shakeApi.start({ Offset = 0, immediate = true })
		burstApi.start({ Alpha = 1, immediate = true })
		itemApi.start({ Scale = 1, Glow = 0, immediate = true })
		setPhase("Done")
		setRevealedCount(count)
	end, { count })

	React.useEffect(function()
		if reveal == nil then
			setPhase("Idle")
			setRevealedCount(0)
			return
		end

		generation.current += 1
		local run = generation.current
		local function alive()
			return generation.current == run
		end

		if reducedMotion then
			setPhase("Done")
			setRevealedCount(count)
			shakeApi.start({ Offset = 0, immediate = true })
			burstApi.start({ Alpha = 1, immediate = true })
			itemApi.start({ Scale = 1, Glow = 0, immediate = true })
			return
		end

		setPhase("Shake")
		setRevealedCount(0)
		shakeApi.start({ Offset = 0, immediate = true })
		burstApi.start({ Alpha = 1, immediate = true })
		itemApi.start({ Scale = 0.4, Glow = 1, immediate = true })

		local shakeThread = task.spawn(function()
			local elapsed = 0
			while alive() and elapsed < tier.shake do
				local ramp = elapsed / tier.shake
				shakeApi.start({ Offset = (math.random() * 2 - 1) * tier.amplitude * (0.35 + ramp), immediate = true })
				task.wait(0.035)
				elapsed += 0.035
			end
			if not alive() then
				return
			end
			shakeApi.start({ Offset = 0, immediate = true })
			UIFeedback.notification()
			setPhase("Burst")
			burstApi.start({ Alpha = 1, immediate = true })
			burstApi.start({ Alpha = 0, config = { duration = BURST_SECONDS } })
			itemApi.start({ Scale = tier.punch, Glow = 0, config = Motion.Control }):andThen(function()
				if alive() then
					itemApi.start({ Scale = 1, config = Motion.Control })
				end
			end)
			task.wait(BURST_SECONDS * 0.5)
			if not alive() then
				return
			end
			setPhase("Item")
			if not isBulk then
				setRevealedCount(1)
				return
			end
			for index = 1, count do
				if not alive() then
					return
				end
				setRevealedCount(index)
				UIFeedback.click()
				task.wait(GRID_STAGGER)
			end
			if alive() then
				setPhase("Done")
			end
		end)

		return function()
			generation.current += 1
			pcall(task.cancel, shakeThread)
		end
	end, { reveal, reducedMotion })

	React.useEffect(function()
		if reveal then
			if previousSelection.current == nil then
				previousSelection.current = GuiService.SelectedObject
			end
			task.defer(function()
				local button = buttonRef.current
				if button and button.Parent and button.Visible and button.Selectable then
					GuiService.SelectedObject = button
				end
			end)
		else
			local previous = previousSelection.current
			previousSelection.current = nil
			if previous and previous.Parent and previous.Visible and previous.Selectable then
				GuiService.SelectedObject = previous
			end
		end
	end, { reveal })

	React.useEffect(function()
		return function()
			generation.current += 1
			shakeApi.stop()
			burstApi.stop()
			itemApi.stop()
		end
	end, {})

	if reveal == nil or headline == nil then
		return nil
	end

	local settled = phase == "Done" or (phase == "Item" and revealedCount >= count)
	local building = phase == "Shake"
	local title = if building then "OPENING..." else if isBulk then `YOU GOT {count} ITEMS` else "YOU GOT"
	local refundLine = if isBulk and reveal.totalRefund > 0
		then `{reveal.totalRefund} BONKS REFUNDED FROM DUPLICATES`
		else nil

	return c("TextButton", {
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.28,
		Selectable = false,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 111,
		[React.Event.Activated] = function()
			if not settled then
				finish()
			end
		end,
	}, {
		Panel = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://124751224634629",
			ImageColor3 = if building then Color3.fromRGB(214, 220, 226) else color,
			Position = shakeStyles.Offset:map(function(offset: number)
				return UDim2.fromScale(0.5 + offset, 0.53 + offset * 0.6)
			end),
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
			SliceCenter = Rect.new(31, 41, 978, 620),
			SliceScale = 0.5,
			ZIndex = 112,
		}, {
			Aspect = if not portrait
				then c("UIAspectRatioConstraint", {
					AspectRatio = if isBulk then 1.45 else 1.15,
					AspectType = Enum.AspectType.FitWithinMaxSize,
				})
				else nil,
			Burst = if phase == "Burst" or phase == "Item"
				then c("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 116,
				}, burstRays(tier, color, 1, 116))
				else nil,
			Flash = c("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = burstStyles.Alpha:map(function(alpha: number)
					return math.clamp(1 - (1 - alpha) * 0.15, 0, 1)
				end),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Visible = phase == "Burst",
				ZIndex = 117,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0.06, 0) }),
			}),
			Title = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 46,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.06),
					Size = UDim2.fromScale(0.88, 0.12),
					Text = title,
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 114,
				},
			}),
			Pity = if reveal.pityTriggered and not building
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.SourceSansBold,
					MaxTextSize = 20,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/SourceSansPro.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0.5, 0.175),
						Size = UDim2.fromScale(0.88, 0.06),
						Text = `PITY  •  GUARANTEED {string.upper(reveal.pityTriggered)}`,
						TextColor3 = Color3.fromRGB(255, 235, 130),
						ZIndex = 115,
					},
				})
				else nil,
			Single = if not isBulk
				then c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.16, 0.18),
					Size = UDim2.fromScale(0.68, 0.46),
					Visible = revealedCount >= 1,
					ZIndex = 113,
				}, {
					Scale = c("UIScale", { Scale = itemStyles.Scale }),
					Content = c(ShopPreview, {
						Items = if headline.preview then { headline.preview } else {},
						Thumbnail = "",
						ZIndex = 113,
					}),
				})
				else nil,
			Grid = if isBulk
				then c(
					"ScrollingFrame",
					{
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						CanvasSize = UDim2.fromOffset(0, 0),
						Position = UDim2.fromScale(0.08, 0.24),
						ScrollBarImageTransparency = 0.2,
						ScrollBarThickness = 5,
						Size = UDim2.fromScale(0.84, 0.5),
						VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
						ZIndex = 113,
					},
					(function()
						local cells: { [string]: any } = {
							Layout = c("UIGridLayout", {
								CellPadding = if portrait then UDim2.fromOffset(8, 8) else UDim2.fromScale(0.02, 0.04),
								CellSize = if portrait
									then UDim2.new(1 / 3, -6, 0, 112)
									else UDim2.fromScale(0.18, 0.44),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
						}
						for index, entry in results :: { any } do
							cells[`Cell{index}`] = gridCell(entry, index, revealedCount, 114)
						end
						return cells
					end)()
				)
				else nil,
			Name = if not isBulk
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.LuckiestGuy,
					MaxTextSize = 42,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						Position = UDim2.fromScale(0.5, 0.62),
						Size = UDim2.fromScale(0.9, 0.12),
						Text = if revealedCount >= 1 then string.upper(headline.displayName) else "",
						TextColor3 = Color3.new(1, 1, 1),
						ZIndex = 114,
					},
				})
				else nil,
			Subtitle = c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				MaxTextSize = 25,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.5, if isBulk then 0.76 else 0.74),
					Size = UDim2.fromScale(0.88, 0.08),
					Text = if not settled then "" else if isBulk then (refundLine or "") else subtitleFor(headline),
					TextColor3 = if isBulk then Color3.fromRGB(255, 235, 130) else Color3.new(1, 1, 1),
					ZIndex = 114,
				},
			}),
			Confirm = c(ShopPriceButton, {
				ButtonRef = buttonRef,
				Enabled = true,
				Position = if props.OnOpenAgain and settled
					then UDim2.fromScale(0.28, 0.94)
					else UDim2.fromScale(0.5, 0.94),
				Size = if props.OnOpenAgain and settled
					then UDim2.fromScale(0.4, 0.13)
					else UDim2.fromScale(0.46, 0.13),
				Text = if settled then "AWESOME!" else "SKIP",
				OnActivated = if settled then props.OnClose else finish,
				ZIndex = 114,
			}),
			Again = if props.OnOpenAgain and settled
				then c(ShopPriceButton, {
					Enabled = props.OpenAgainEnabled == true,
					Position = UDim2.fromScale(0.72, 0.94),
					Size = UDim2.fromScale(0.4, 0.13),
					Text = props.OpenAgainText or "OPEN AGAIN",
					OnActivated = props.OnOpenAgain,
					ZIndex = 114,
				})
				else nil,
		}),
	})
end
