local TweenService = game:GetService("TweenService")

local NavigationController = {}

local SELECTED_RED = "rbxassetid://94748581468730"
local UNSELECTED_BLUE = "rbxassetid://136021539696619"

local MENU_ONSCREEN = UDim2.fromScale(0.021, 0.143)
local MENU_OFFSCREEN = UDim2.fromScale(-1.5, 0.143)
local SPLASH_ONSCREEN = UDim2.fromScale(0, 0)
local SPLASH_OFFSCREEN = UDim2.fromScale(0, 1)
local PARTY_CODE_ONSCREEN = UDim2.fromScale(0.5, 0.115)
local PARTY_CODE_OFFSCREEN = UDim2.fromScale(0.5, -0.25)

local PAGE_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local CAMERA_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function NavigationController.start(screenGui)
	local camera = workspace.CurrentCamera
	local partyWorld = workspace:WaitForChild("Views"):WaitForChild("Party")
	local baseClip = screenGui:WaitForChild("BaseClip")
	local views = baseClip:WaitForChild("Views")
	local hud = baseClip:WaitForChild("HUD")
	local tabs = hud:WaitForChild("TopBar"):WaitForChild("PageTabs")
	local partyCode = hud:WaitForChild("PartyCode")

	local pages = {
		Inventory = {
			frame = views:WaitForChild("Inventory"),
			camera = partyWorld:WaitForChild("InventoryCamera"),
			onscreen = MENU_ONSCREEN,
			offscreen = MENU_OFFSCREEN,
		},
		Shop = {
			frame = views:WaitForChild("Shop"),
			camera = partyWorld:WaitForChild("ShopCamera"),
			onscreen = MENU_ONSCREEN,
			offscreen = MENU_OFFSCREEN,
		},
		SplashScreen = {
			frame = views:WaitForChild("SplashScreen"),
			camera = partyWorld:WaitForChild("SplashScreenCamera"),
			onscreen = SPLASH_ONSCREEN,
			offscreen = SPLASH_OFFSCREEN,
		},
	}
	local linkedHud = {
		{
			frame = partyCode,
			page = "SplashScreen",
			onscreen = PARTY_CODE_ONSCREEN,
			offscreen = PARTY_CODE_OFFSCREEN,
		},
	}

	local activeTweens = {}
	local currentPage
	local transitionRevision = 0
	local tabButtons = {}

	local function playTween(object, tweenInfo, properties)
		local activeTween = activeTweens[object]
		if activeTween then
			activeTween:Cancel()
		end

		local nextTween = TweenService:Create(object, tweenInfo, properties)
		activeTweens[object] = nextTween
		nextTween.Completed:Connect(function()
			if activeTweens[object] == nextTween then
				activeTweens[object] = nil
			end
		end)
		nextTween:Play()
		return nextTween
	end

	local function setLinkedHudTarget(element, pageName)
		local shouldShow = element.page == pageName
		if shouldShow then
			if not element.frame.Visible then
				element.frame.Position = element.offscreen
				element.frame.Visible = true
			end
			playTween(element.frame, PAGE_TWEEN_INFO, { Position = element.onscreen })
		elseif element.frame.Visible then
			playTween(element.frame, PAGE_TWEEN_INFO, { Position = element.offscreen })
		end
	end

	local function finishTransition(revision, pageName, incomingTween)
		task.spawn(function()
			local playbackState = incomingTween.Completed:Wait()
			if
				playbackState ~= Enum.PlaybackState.Completed
				or revision ~= transitionRevision
				or currentPage ~= pageName
			then
				return
			end

			for otherName, page in pages do
				if otherName ~= pageName then
					page.frame.Visible = false
					page.frame.Position = page.offscreen
				end
			end
			for _, element in linkedHud do
				if element.page ~= pageName then
					element.frame.Visible = false
					element.frame.Position = element.offscreen
				end
			end
		end)
	end

	local function setPage(pageName)
		local destination = pages[pageName]
		if not destination or pageName == currentPage then
			return
		end

		local previousPage = currentPage and pages[currentPage]
		currentPage = pageName
		transitionRevision += 1
		local revision = transitionRevision

		for _, entry in tabButtons do
			entry.button.Image = entry.page == pageName and SELECTED_RED or UNSELECTED_BLUE
		end

		if not previousPage then
			camera.CFrame = destination.camera.CFrame
		elseif previousPage.camera ~= destination.camera then
			playTween(camera, CAMERA_TWEEN_INFO, { CFrame = destination.camera.CFrame })
		end

		local incomingTween
		for name, page in pages do
			if name == pageName then
				if not page.frame.Visible then
					page.frame.Position = page.offscreen
					page.frame.Visible = true
				end
				incomingTween = playTween(page.frame, PAGE_TWEEN_INFO, { Position = page.onscreen })
			elseif page.frame.Visible then
				playTween(page.frame, PAGE_TWEEN_INFO, { Position = page.offscreen })
			end
		end

		for _, element in linkedHud do
			setLinkedHudTarget(element, pageName)
		end

		finishTransition(revision, pageName, incomingTween)
	end

	local function pageForButton(button)
		if pages[button.Name] then
			return button.Name
		end

		for pageName in pages do
			if string.find(button.Name, pageName, 1, true) then
				return pageName
			end
		end

		return nil
	end

	for _, page in pages do
		page.frame.Position = page.offscreen
		page.frame.Visible = false
	end
	for _, element in linkedHud do
		element.frame.Position = element.offscreen
		element.frame.Visible = false
	end
	camera.CameraType = Enum.CameraType.Scriptable

	for _, child in tabs:GetChildren() do
		if child:IsA("ImageButton") then
			local pageName = pageForButton(child)
			if pageName then
				table.insert(tabButtons, {
					button = child,
					page = pageName,
				})
				child.MouseButton1Click:Connect(function()
					setPage(pageName)
				end)
			end
		end
	end

	setPage("SplashScreen")
end

return NavigationController
