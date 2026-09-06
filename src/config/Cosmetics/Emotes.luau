-- Victory emotes drive preview rigs only; ownership and selection remain in CosmeticsService.
--!strict

return {
	DefaultStyle = "Wave",
	Styles = {
		Wave = { Duration = 3.2, Accent = "Cyan", ConfettiCount = 8, Pose = "Wave" },
		ConfettiTwirl = { Duration = 4, Accent = "Pink", ConfettiCount = 18, Pose = "Twirl" },
		ChampionFlex = { Duration = 3.6, Accent = "Yellow", ConfettiCount = 14, Pose = "Flex" },
		PartyBounce = { Duration = 3.2, Accent = "Cyan", ConfettiCount = 18, Pose = "Bounce" },
	},
	Preview = {
		WidthStuds = 6.8,
		HeightStuds = 7.3,
		FieldOfView = 42,
		TargetOffset = Vector3.new(0, 0.1, 0),
		UpdateHz = 30,
	},
}
