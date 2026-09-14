# Ouch UI styles

`OuchButton` is the reusable native button skin. Pair it with `AnimatedButton`
for mouse, touch, and gamepad feedback, stable hitboxes, focus indication, and
reduced-motion support. `ButtonSurface` remains an alias for existing callers.

```lua
c(AnimatedButton, {
    Visual = c(OuchButton, { Color = UI.ProgressionStyle.Pink }),
    Native = { BackgroundTransparency = 1, Image = "", Size = UDim2.fromOffset(240, 52) },
    OnActivated = onActivated,
}, {
    Label = c(OuchText, {
        MaxTextSize = UI.Text.LabelPx,
        Native = {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = label,
            TextColor3 = UI.ProgressionStyle.White,
            ZIndex = 2,
        },
    }),
})
```

`OuchPanel` accepts `Native`, `Color`, `Radius`, and `Padding` (20px by default).
The existing reward/quest/season cards pass `Padding = 0` because their content
already has responsive insets. Reserve 12px outside panels for the shadow and
8px below button faces for the bevel/shadow.

`OuchProgressBar` accepts `Progress` (clamped to 0–1), `Color`, `TrackColor`,
and `Native` bounds. `OuchText` applies the shared Luckiest Guy face and outline.
The style tokens live in `Config.Interface.UI`.

Crate details and rewards use `OuchPanel.Gloss = true`; `Well.Ouch` and
`WellScroll.Ouch` apply the same face to existing inset layouts. Image-backed
panels retain their source skin and image bounds beneath the native face.

`useCrateRevealMotion` animates only presentation, using already-awarded results.
Its build, landing, burst and batch stagger take about 1.8–2.3 seconds for 1–10
items. `finish()` immediately reveals the full batch and cancels all work.
Closing, replaying, and reduced motion also dispose tweens and pending tasks.
The glow and sparks are native UI shapes; reward image sizes stay unchanged.

Reward framing uses `BonksLabel.Framed` and preserves the existing icon assets
and fitted image dimensions. The background controller reduces texture opacity
without changing texture IDs, tile size, or source artwork.
