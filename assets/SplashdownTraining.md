# Splashdown training assets

Exact Studio serialization of four source MeshParts from the open Match Place's
`Workspace.battle_stadium`, exported for reuse in the existing TutorialArena:

- `obstacle_18_001`: round bumper (mesh 111046007117803)
- `obstacle_19_001`: triangular bumper (mesh 136833854670623)
- `obstacle_6_001`: spinner (mesh 126266875043409)
- `obstacle_3_001`: swinging hammer mount (mesh 132531980247334), including
  `obstacle_3_002` blade (mesh 96215223817723)

The binary model retains the original mesh, texture (83918297212907), hierarchy,
and collision data. No mesh or texture was regenerated.

Onboarding uses one of them: `OnboardingObstacle` clones the spinner
(`obstacle_6_001`) for the single obstacle lesson, applying the same 0.55
scaling and placement recipe as `author-splashdown-courses.luau` and then the
existing map-feature mover and shove kits. The other three are kept because this
file is a verbatim export, not because the tutorial places them.
