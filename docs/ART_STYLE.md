# Splat Brawl art direction

Build an original, colorful toy-like party-platformer world. Favor bold rounded geometry, chunky filled icons, strong simple silhouettes, saturated colors, friendly exaggerated proportions, large rounded UI containers, and strong foreground/background contrast. Materials should feel like simplified toys; effects should read graphically at normal gameplay distance. Avoid fine noise, photorealism, thin technical symbols, and detail that disappears on mobile.

Figma owns UI, HUD, screens, menus, buttons, badges, icon treatments, simple 2D artwork, particle sprites, gradients, masks, UI textures, typography, colors, spacing, responsive layouts, and tokens. The canonical file is recorded in `tools/workflow.json`. Inspect it and reuse components, variables, styles, and auto-layout before adding structures. Record canonical concepts in `canonical_icons` with file URL and node ID to avoid repeated symbol searches.

Fall Guys is the sole high-level reference for abstract readability and playful proportions.

Evaluate silhouettes in motion, on light and dark backgrounds, at normal gameplay distance and actual mobile size. Retain readable labels, clear interactive states, and sufficient contrast. Use existing React UI components and roots when implementing designs. Studio is final visual and integration truth; Figma/Blender approval alone never establishes production acceptance.

For consequential visuals, send Gemini a bounded packet containing this direction, the requirement, source imagery, and representative Studio output. Review icon candidates together in a labeled contact sheet with current UI context. Codex chooses the final direction and records the disposition of reviewer findings.
