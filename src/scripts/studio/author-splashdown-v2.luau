-- Name: author-splashdown-v2.luau
-- Author: Jack C.
-- Description: Documented Studio Command Bar entry to the declarative Splashdown course pipeline (HANDOFF.md section 5 and 10). Paste one of the commands below into the normal Edit Command Bar; this file is the reference, not a script the engine runs. It never calls the old author-splashdown-courses.luau Author.build(), which destroys same-ID templates and regenerates the superseded layouts.
-- Created: 2026-09-15

--[[

Prerequisites, all in normal Edit mode on the Match Place:

  1. ServerStorage.SplashdownAuthoringSources exists (Kit + ArenaSources.BoundaryWall).
     It is produced by the section 4 source export and verified against
     docs/splashdown/evidence/source-hashes.json.
  2. Rojo is connected so ReplicatedStorage.Shared.Game.Splashdown is current.

Stage the pilot (HANDOFF section 10 step 3). Prints the section 5.1.12 JSON:

  require(game.ReplicatedStorage.Shared.Game.Splashdown.CourseAuthoring).stage({"BallBarrage"})

Expected: ok=true, ids=["BallBarrage"], attributeErrors=[], routeErrors=[],
boundsViolations=[], finite partCounts/buildSeconds, and a specHashes entry.

Run it a second time and compare specHashes (step 4). The two runs must print the
same hash; elapsed build time is deliberately excluded from it.

Preview at the live MapOrigin for the section 8.6 fixed cameras (step 5):

  require(game.ReplicatedStorage.Shared.Game.Splashdown.CourseAuthoring).preview("BallBarrage")

Then capture the two documented cameras and put the preview back:

  require(game.ReplicatedStorage.Shared.Game.Splashdown.CourseAuthoring).clearPreview()

Audit a staged model without Play (structure, surfaces, graph, cut sets, gaps,
geometry, coverage and variety; the live-playtest checks report NOT RUN):

  local QA = require(game.ReplicatedStorage.Shared.Game.Splashdown.CourseQA)
  local spec = require(game.ReplicatedStorage.Shared.Game.Splashdown.CourseSpecs.BallBarrage)
  local staged = game.ServerStorage.SplashdownStaging.BallBarrage:Clone()
  staged.Parent = workspace
  print(game:GetService("HttpService"):JSONEncode(QA.check(staged, spec)))
  staged:Destroy()

promote() is reserved for the final validated replacement and refuses to mutate
anything unless every id is staged AND its SpecHash matches a hash you pass in
from the verified Gate evidence:

  require(game.ReplicatedStorage.Shared.Game.Splashdown.CourseAuthoring)
      .promote({"BallBarrage"}, { BallBarrage = "<hash from qa.json>" })

Do not run promote() before the gate that authorises the swap.

]]

return nil
