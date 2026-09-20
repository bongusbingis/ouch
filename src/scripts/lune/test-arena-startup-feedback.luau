-- Description: Exercises UIFeedback source with malformed optional cue configuration and verifies healthy cues remain usable.
--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function loadFeedback(hover: any, click: any)
	local created: { any } = {}
	local played: { any } = {}
	local function makeInstance(className: string): any
		local instance = {
			ClassName = className,
			Destroyed = false,
			Play = function() end,
			Stop = function() end,
			Destroy = function(self)
				self.Destroyed = true
			end,
		}
		table.insert(created, instance)
		return instance
	end

	local uiConfig = {
		Feedback = {
			HoverSoundId = hover,
			ClickSoundId = click,
			Volume = 1,
		},
	}
	local targetKeys = {
		UI = uiConfig,
		SettingsStore = {
			get = function()
				return 1
			end,
		},
	}
	local environment: any = {
		game = {
			GetService = function(_, name)
				if name == "ReplicatedStorage" then
					return {
						WaitForChild = function(_, child)
							if child == "Config" then
								return {
									WaitForChild = function(_, interface)
										assert(interface == "Interface", "expected Config.Interface")
										return {
											WaitForChild = function(_, module)
												return { _key = module }
											end,
										}
									end,
								}
							end
							assert(child == "Shared", "expected ReplicatedStorage.Shared")
							return {
								WaitForChild = function(_, gameName)
									assert(gameName == "Game", "expected Shared.Game")
									return {
										WaitForChild = function(_, settingsName)
											assert(settingsName == "Settings", "expected Game.Settings")
											return {
												WaitForChild = function(_, module)
													return { _key = module }
												end,
											}
										end,
									}
								end,
							}
						end,
					}
				elseif name == "SoundService" then
					return {
						PlayLocalSound = function(_, sound)
							table.insert(played, sound)
						end,
					}
				elseif name == "Workspace" then
					return {}
				end
				error(`unexpected service {name}`)
			end,
		},
		Instance = { new = makeInstance },
		Enum = {
			HapticEffectType = { UIHover = "UIHover", UIClick = "UIClick", UINotification = "UINotification" },
		},
		Random = {
			new = function()
				return {
					NextInteger = function(_, lower)
						return lower
					end,
				}
			end,
		},
		require = function(target)
			return assert(targetKeys[target._key], `unexpected require {tostring(target._key)}`)
		end,
	}
	local module = luau.load(
		luau.compile(fs.readFile("src/shared/UI/Services/UIFeedback.luau")),
		{ debugName = "UIFeedback", environment = environment, injectGlobals = true }
	)()
	return module, created, played
end

local function assertCueScenario(name: string, hover: any, click: any, expectedSoundId: string?)
	local feedback, created, played = loadFeedback(hover, click)
	local started, reason = pcall(feedback.start)
	assert(started, `{name}: malformed optional cue aborted UIFeedback.start: {tostring(reason)}`)
	feedback.hover()
	feedback.click()
	if expectedSoundId then
		assert(#played == 1, `{name}: the healthy cue did not play exactly once`)
		assert(played[1].SoundId == expectedSoundId, `{name}: the wrong healthy cue played`)
	else
		assert(#played == 0, `{name}: unavailable cues unexpectedly played audio`)
	end
	feedback.destroy()
	for _, instance in created do
		assert(instance.Destroyed, `{name}: {instance.ClassName} was not cleaned up`)
	end
end

assertCueScenario("empty-hover", "", "rbxassetid://click", "rbxassetid://click")
assertCueScenario("empty-click-array", "rbxassetid://hover", {}, "rbxassetid://hover")
assertCueScenario("both-invalid", {}, "", nil)

print("Arena startup UIFeedback actual-source malformed-cue regression: 3 scenarios passed")
