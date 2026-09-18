# Splashdown map remediation — execution plan (Studio-only)

**Audience:** an agent picking this work up cold, with access to the Roblox Studio MCP and
(optionally) subagents. You have not seen the conversation that produced this file. Everything
you need is here, in `docs/map-issues.md` (the owner's playtest notes), and in
`docs/map-remediation.md` (the running tracker).

**Read sections 1–6 in full before touching anything.** Section 5 exists because four confident
findings in the original audit turned out to be measurement errors. If you skip it you will
re-discover them and "fix" things that were never broken.

---

## 1. Scope — what you may and may not touch

### You work almost entirely inside Roblox Studio

The shipped course templates live at `ReplicatedStorage.Assets.Maps.Splashdown` **inside the
`.rbxl` place file**. They are not in git. Every map fix in this plan is a direct edit to those
instances via `mcp__Roblox_Studio__execute_luau`.

### OFF LIMITS — do not open, read-to-edit, or modify these

| Frozen | Why |
|---|---|
| `src/shared/Game/Splashdown/CourseBuilder.luau` | course-builder toolkit |
| `src/shared/Game/Splashdown/CoursePresets.luau` | course-builder toolkit |
| `src/shared/Game/Splashdown/CourseSpecs/*.luau` | course-builder toolkit |
| `src/shared/Game/Splashdown/AssetManifest.luau` | course-builder toolkit |
| `src/shared/Game/Splashdown/CourseQA.luau` | QA — out of scope entirely |
| `places/arena/tests/Assets/SplashdownQA.spec.luau` | QA — out of scope entirely |
| `src/shared/Game/MapFeatures/RotatingPlatforms.luau` | already fixed and frozen |

These already received their fixes in an earlier pass (see §6). That work is **done and
committed**. Do not revisit it, do not "improve" it, and do not run any of it.

**Never regenerate, rebuild or re-author a course.** Do not run `CourseAuthoring.stage`, anything
under `src/scripts/studio/author-splashdown-*`, or any promotion tool. The existing layouts stay.
If a task looks like it needs a rebuild, stop and report.

### The one task that touches git

**Task R1** (the Door Dash rename) edits two config files and one test spec. That is the only
git work in this plan, and §9 scopes it precisely. Everything else is Studio-only.

---

## 2. What this system is

**Splashdown** is a 7-course obstacle-race mode. The seven course IDs:

`BallBarrage`, `WhirlpoolWaltz`, `DoorDash`, `TumbleTunnels`, `TiptoeTrials`, `PistonPeak`,
`SummitSplash`

| Thing | Where |
|---|---|
| **Shipped course templates — what you edit** | `ReplicatedStorage.Assets.Maps.Splashdown` |
| Kit source meshes (176 roots) | `ServerStorage.SplashdownAuthoringSources.Kit` |
| Arena sources | `ServerStorage.SplashdownAuthoringSources.ArenaSources` (`LiquidMesh`, `BoundaryWall`) |
| Per-course route reports (JSON) | `ServerStorage.SplashdownStageReport_<CourseId>_Route` |
| Screenshot staging | `Workspace.SplashdownPreview` (scratch — task A4 deletes it) |
| Asset inventory (read-only reference) | `docs/splashdown/01-asset-inventory.md` |
| Owner's playtest notes + screenshots | `docs/map-issues.md`, `docs/image*.png` |

### The course contract every template must keep

If you break this, the game fails to boot. Verify it after every session (§8, "final check").

Each course Model needs: `Origin` (Part), `Start.Pads` (≥30), `Checkpoints` (each child Model
having `Pad` + `Trigger`, and by convention `Arch`), `Finish.Trigger` + `Finish.Deck`, `Hazards`
(≥1 part), `Boundary` (24 walls), `Scriptables`, `Geometry`, `Beats`, `QA`. The model attribute
`CheckpointCount` must equal the number of checkpoint Models.

---

## 3. Hard rules

1. **Never invent a number.** Every position, size, angle and value in this plan is measured or
   decided. If a task needs a value this plan does not give, **stop and ask**.
2. **Never use "as appropriate", "where it makes sense", or "clean up" as your own instruction.**
   If you cannot state exactly what you are about to change and why, you are not ready to change
   it.
3. **Measure before and after, every time.** Print the value you are changing *from* and *to*. A
   change you did not verify did not happen.
4. **Do not delete anything you have not first inspected and reported.**
5. **One Studio writer at a time.** See §4.3 — this is the main coordination hazard.
6. **This git checkout is shared with other sessions.** `git status` will show files you did not
   touch. Never revert, stage, or commit another session's work. No `git checkout`, `git reset`,
   or `git stash`.
7. **Do not "fix" line endings.** `stylua --check` reports spurious whole-file diffs here (CRLF
   working tree, LF expected). Local artifact. Ignore it.

---

## 4. Working with the Studio MCP

### 4.1 Connection

```
studio_id      = f2e79758-7afe-47ea-8efc-85035edf8307   (Match Place, placeId 121997450145716)
datamodel_type = "Edit"
```

Confirm with `mcp__Roblox_Studio__list_roblox_studios` first — if the id has changed, use the one
whose name contains **"Match Place"**. There is a second Studio open (`OUCH!`, placeId
130584867985467) — **that is the wrong one.**

### 4.2 Known limits of the Luau execution VM

- **You cannot `require()` a synced ModuleScript.** It fails with a `Capabilities` error.
  Hardcode the constants you need and say so in a comment.
- **A script that errors part-way still keeps whatever it already did.** Never write a script
  that mutates and then might throw. **Do all reads first, then all writes.**
- Course pieces are often a holder `Model` wrapping a MeshPart. Always use:
  ```lua
  local function box(i)
      if i:IsA("BasePart") then return i.CFrame, i.Size end
      local c, s = i:GetBoundingBox(); return c, s
  end
  ```
- To move a piece, move its **holder** so sub-parts keep their offsets:
  ```lua
  local holder = inst:IsA("Model") and inst or inst.Parent
  if holder:IsA("Model") then holder:PivotTo(holder:GetPivot() + shift)
  else inst.CFrame = inst.CFrame + shift end
  ```

### 4.3 The Studio lease — mandatory if you use subagents

**The Studio MCP is one connection to one running Studio.** Two agents writing at once will
corrupt each other's work silently: there is no locking, no transaction, and no conflict error.

**Protocol:**

- Exactly **one** agent holds the *Studio lease* at any moment. That agent is the only one that
  may call `execute_luau` with a write, or `screen_capture`.
- The lead agent holds the lease by default.
- To hand the lease to a subagent: the lead states in the brief *"You hold the Studio lease"*,
  then makes **no Studio calls at all** until that subagent reports back.
- A subagent that does not hold the lease **must not call any Studio tool**, including reads. Say
  this explicitly in every brief that doesn't grant it.
- Never run two lease-holding subagents concurrently, even on different maps.

**Because of this, subagents do not speed up Studio work.** Their value is in §7: thinking,
measuring-and-proposing, and design. Structure the work so subagents produce *specs and
proposals* and the lead applies them.

### 4.4 Visual verification

Courses live in `ReplicatedStorage` and do not render. `Workspace.SplashdownPreview` holds clones
of all 7, offset **1000 studs apart in X**, in this index order:

`1 BallBarrage, 2 WhirlpoolWaltz, 3 DoorDash, 4 TumbleTunnels, 5 TiptoeTrials, 6 PistonPeak, 7 SummitSplash`

So Piston Peak's preview copy sits at template coordinates **+5000 X**. Refresh after any change:

```lua
local maps = game.ReplicatedStorage.Assets.Maps.Splashdown
local preview = workspace:FindFirstChild("SplashdownPreview")
if not preview then preview = Instance.new("Folder"); preview.Name = "SplashdownPreview"; preview.Parent = workspace end
for _, c in preview:GetChildren() do c:Destroy() end
local order = {"BallBarrage","WhirlpoolWaltz","DoorDash","TumbleTunnels","TiptoeTrials","PistonPeak","SummitSplash"}
for i, id in order do
    local clone = maps[id]:Clone()
    clone:PivotTo(clone:GetPivot() + Vector3.new((i - 1) * 1000, 0, 0))
    clone.Parent = preview
end
```

Then `mcp__Roblox_Studio__screen_capture` with `camera_position` and `look_at_position`.

**Always screenshot from the runner's approach direction** when judging a hazard — that is the
only view that shows what the player actually faces. Get the route heading from the route report
(§5.5); the runner travels along `forward`, so put the camera *behind* them at
`headPos - forward*45 + Vector3.new(0, 6, 0)` looking at `headPos`.

### 4.5 Reading a route report

```lua
local HttpService = game:GetService("HttpService")
local rv = game.ServerStorage["SplashdownStageReport_BallBarrage_Route"]
local arr = HttpService:JSONDecode(rv.Value)
-- entries: { PieceId, BeatId, Kind, Yaw, ArcLength, SegmentTravel, HalfWidth }
-- Kind: Chain | Corner | Mount | Advance | Ride | Flank | Island | Retain
```

Route forward at a piece:
`Vector3.new(math.sin(math.rad(Yaw)), 0, math.cos(math.rad(Yaw)))`

Match a built instance to its route entry via its `PieceId` attribute (on the instance or its
holder). **`Kind = "Advance"` means an authored jump gap — open air by design, not a defect.**

---

## 5. Measurement traps — read this or you will repeat these mistakes

The original audit produced four confident findings that were **wrong**. Each came from a
plausible-looking measurement.

### 5.1 Never sample `Position.Y` as "the surface"

The green ramp (`box_011` / `box_013`) has its walkable plateau **26.9 studs above its part
centre** at the high end and 1.6 below it at the low end. No other kit piece is like this.

Sampling `Position.Y` produced a "recurring −5.7 stud step at nearly every ramp end on all six
courses". That number is just `26.9 × 0.210526` (the near-universal ramp scale of 6/28.5) =
**5.663**. An artifact — identical across unrelated courses *because* it was scale-locked.
Re-measured against real plateaus, every ramp junction is flush, and **every ramp is aligned to
its route heading** (all 41 checked, none off by more than 8°).

**Rule:** a ramp's walkable height is `Position.Y + 26.9 × scale` (high end) or
`Position.Y − 1.6 × scale` (low end), where `scale = Size.X / 153.06268`.

**There is no ramp work left in this plan.** If you find yourself about to move a ramp, re-read
this section first.

### 5.2 An overlap is not automatically a defect

Some pieces are *supposed* to interpenetrate:

- **Slides are descenders.** All four have their top flush with the deck above and their base
  just above the deck below. A descender must overlap the deck it descends from. The original
  audit called this "slide buried 8.6 studs into platform" — it was working correctly.
- **Assembly sub-parts overlap their own root** (piston body/spring, paddlewheel hub/cradles,
  mace links). Filter by `PieceId` — parts sharing one are a single piece.
- **Some fans are sunk deliberately**, so the grate finishes flush with the deck and a runner
  crossing it is inside the airflow column.

**Rule:** before calling an overlap a defect, ask what the piece is *for*, and check whether the
overlap is with the piece it is meant to meet.

### 5.3 "Nearest deck" is not "the deck it belongs to"

- A jump pad was reported as floating **72.7 studs past a plaza edge**. It is correctly seated on
  `sd_arc.007`, 4.1 studs inside the footprint. The deck-name filter did not match Summit's
  `sd_arc.*` naming, so it measured against a plaza 72 studs away.
- Ramp ends were reported with ±6 and ±12 stud "steps". Those are the ramp's *intended rise*; on
  a switchback the nearest deck in plan is often the deck at the other end's height.

**Rule:** identify a supporting deck by **footprint containment plus height**, never by nearest
centre distance. Check your name filter covers that course's naming — **Summit Splash is a legacy
course** and uses `sd_arc.*`, `sd_plaza.*`, `sd_island_support.*`, `sd_flag.*`, `sd_lava`.

### 5.4 Large gaps are usually authored

Horizontal gaps of 11–28 studs near ramps are `Advance` pieces — jump gaps of 14, 16 and 18
studs. Check the route report before calling a gap a defect.

### 5.5 When a measurement disagrees with a screenshot, trust the screenshot

Twice in this project the arithmetic said "fine" and the picture said "wrong", and the picture was
right — because the arithmetic was measuring the wrong thing. Take the screenshot.

---

## 6. What is already done — do not redo or revisit any of this

31 tasks are complete and verified. The framework half is **committed and frozen** (§1).

### Framework (frozen — listed only so you don't re-report these as bugs)

Fan blades no longer spin on world Y regardless of fan orientation; checkpoint/finish triggers are
built at 56×24×2; the builder now creates its own checkpoint arch; the fall zone is built as the
purple lava mesh; the FoamPit feature was removed entirely; piston tuning is spec-driven at
18/1.9s/0.35s/shove 54; seesaw default tilt is 34°; the sweeper's sliding frame is opt-in; the
green ramp's sockets were corrected from ±69 to ±72.705.

### Maps (in the `.rbxl` — the state you are inheriting)

| What | Detail |
|---|---|
| Whirlpool Waltz restored | It had been dragged into the Workspace, which would have hard-failed boot. |
| Blue water → purple lava | All 6 non-Summit courses. Surface height delta **0.000**; kill threshold unchanged. |
| 42 triggers widened | To 56×24×2 (Summit 56×24×6), every bottom edge preserved. |
| 4 missing checkpoint arches added | 3 had to be relocated — see §10 note 3. |
| 6 foam pits + 7 folders deleted | Also removed the translucent slabs that made Summit's ending unreadable. |
| 3 Piston Peak bumper pairs re-spaced | 0.07 / −0.08 / 1.20 → **4.00 studs**. |
| 2 spinners centred | 3.61→0.00, 8.50→0.00. |
| 2 Door Dash decks deleted | The decks under the second pad of each launch pair. Pads still anchored in place. |
| 4 jump pads inset | +3.4/+2.9/+3.0/+3.0 → −1.0 stud margin. |
| Summit finish arch resized | 124.2×40.9×18.4 → **28.0×9.2×4.1**; line 103.9×10.3 → 26.0×2.6. |
| 7 seesaws | `MaxTiltDegrees` → 34. |
| 5 punchers | Moved to a 6-stud gap; throw **18 Ball Barrage / 11 Piston Peak**; period 1.9s, hold 0.35s, shove 54. |
| Ball Barrage sweeper | Frame's `slide` stripped so the spiked roller spins in place. Summit's deliberately kept. |
| 2 beach balls | **4.6 → 10.1 studs** + full knockback, lifted 2.75 studs. |
| **4 hammer blades rolled 90°** | Was presenting its broad face to the runner and rotating about that same axis — a propeller facing the player, so the edge could never lead. Now `\|faceNormal · routeForward\|` = 0.00 on all four; pivots moved <0.0001 studs. |
| 4 hammers re-profiled | Old windup/strike → symmetric rock at `RotorPeriod = 3.6`. |

### Withdrawn — audit errors, not defects. Do not "re-fix" these.

- Summit's jump pad is correctly seated (§5.3).
- Re-seating ~14 ramp ends: the premise was the −5.7 artifact (§5.1). Nothing to re-seat.

**Current state is verified good:** all 7 courses pass the boot contract — correct checkpoint
counts, an arch on every checkpoint, lava present as a MeshPart, no foam pits, 30 start pads, 24
boundary walls.

---

## 7. How to use subagents

If your harness supports subagents, use this decomposition. **If it does not, do the same tasks
yourself in the same order** — the plan works either way.

Model capability varies; assign by what the task *demands*, not by model name.

| Role | Demands | Holds Studio lease? | Use for |
|---|---|---|---|
| **Surveyor** | Careful, literal, good at arithmetic | **Yes**, one at a time | Run a measurement script, report numbers. Changes nothing. |
| **Applier** | Precise, follows a spec exactly, does not improvise | **Yes**, one at a time | Apply a fully-specified change, verify before/after, report. |
| **Analyst** | Reasoning, reads code and evidence, weighs options | **No** | Take a Surveyor's numbers + screenshots and produce an exact spec or a recommendation. |
| **Designer** | Taste, judgement, spatial reasoning | **No** (works from captured data) | Group D. Produces a written proposal the lead reviews before anything is applied. |

### The loop that keeps a weaker model safe

```
Surveyor (lease) → numbers
        ↓
Analyst (no lease) → an exact spec: instance names, from-values, to-values
        ↓
Lead reviews the spec. Is every value concrete? If not, send it back.
        ↓
Applier (lease) → applies it, prints before/after, reports
        ↓
Lead verifies against the spec and updates docs/map-remediation.md
```

**Never let one agent both decide what to change and change it.** That is how unfounded edits
happen. The split is the safety mechanism.

### Every subagent brief must contain

1. Whether it holds the Studio lease. If not: *"Do not call any Roblox Studio tool."*
2. The `studio_id` and `datamodel_type` if it does.
3. The exact instances by full name — never "the bumper near the finish".
4. The exact from-values and to-values.
5. The specific `docs/image*.png` files it must view, if any.
6. The verification it must print.
7. **"If anything is ambiguous, stop and report rather than guessing."**
8. The frozen-file list from §1.

Subagents cannot see this conversation or each other's work. Every brief is self-contained.

---

## 8. Reusable code

### Oriented-bounding-box overlap (pieces are yawed — an axis-aligned test gives false results)

```lua
local function obb(cf, sz)
    local h = sz / 2
    return { c = cf.Position, ax = { cf.RightVector, cf.UpVector, cf.LookVector }, h = { h.X, h.Y, h.Z } }
end

local function penetration(a, b)  -- studs of overlap, or 0 if disjoint
    local d = b.c - a.c
    local best = math.huge
    local axes = {}
    for i = 1, 3 do table.insert(axes, a.ax[i]); table.insert(axes, b.ax[i]) end
    for i = 1, 3 do for j = 1, 3 do
        local cr = a.ax[i]:Cross(b.ax[j])
        if cr.Magnitude > 1e-4 then table.insert(axes, cr.Unit) end
    end end
    for _, ax in axes do
        local ra, rb = 0, 0
        for i = 1, 3 do
            ra += a.h[i] * math.abs(a.ax[i]:Dot(ax))
            rb += b.h[i] * math.abs(b.ax[i]:Dot(ax))
        end
        local overlap = ra + rb - math.abs(d:Dot(ax))
        if overlap <= 0 then return 0 end
        if overlap < best then best = overlap end
    end
    return best
end
```

When hunting defects, always exclude: `Liquid`, `sd_lava`, anything named `Wall<NN>`, anything
with `Transparency >= 1`, `Pad`, `Trigger`, `Origin`, and any pair sharing a `PieceId`.

### Find the deck a piece actually stands on (not the nearest one — §5.3)

```lua
local function supportingDeck(course, inst, maxDrop)
    local cf, sz = box(inst)
    local r = math.max(sz.X, sz.Z) / 2
    local best, bestArea
    for _, d in course:GetDescendants() do
        if d:IsA("BasePart") and d ~= inst and not d:IsDescendantOf(inst)
            and d.Size.X > 4 and d.Size.Z > 4
            and d.Name ~= "Liquid" and d.Name ~= "sd_lava" and not d.Name:find("^Wall%d") then
            local lp = d.CFrame:PointToObjectSpace(cf.Position)
            local horizOut = math.max(math.abs(lp.X) - d.Size.X/2, math.abs(lp.Z) - d.Size.Z/2)
            local dy = (cf.Position.Y - sz.Y/2) - (d.Position.Y + d.Size.Y/2)
            if horizOut < r + 2 and dy > -2.5 and dy < (maxDrop or 14) then
                local area = d.Size.X * d.Size.Z
                if not bestArea or area < bestArea then best, bestArea = d, area end
            end
        end
    end
    return best
end
```

### Final check — run after every session

```lua
local maps = game.ReplicatedStorage.Assets.Maps.Splashdown
local order = {"BallBarrage","WhirlpoolWaltz","DoorDash","TumbleTunnels","TiptoeTrials","PistonPeak","SummitSplash"}
local out, allOk = {}, true
for _, id in order do
    local c = maps:FindFirstChild(id)
    if not c then table.insert(out, "** MISSING " .. id); allOk = false continue end
    local n, noArch = 0, 0
    for _, cp in c.Checkpoints:GetChildren() do
        if cp:IsA("Model") then
            n += 1
            if not cp:FindFirstChild("Arch") then noArch += 1 end
            if not cp:FindFirstChild("Pad") or not cp:FindFirstChild("Trigger") then allOk = false end
        end
    end
    local liquid
    for _, p in c.Hazards:GetChildren() do if p.Name == "Liquid" or p.Name == "sd_lava" then liquid = p end end
    local ok = (c:GetAttribute("CheckpointCount") == n) and liquid ~= nil
        and #c.Start.Pads:GetChildren() >= 30 and c:FindFirstChild("Origin")
        and c.Finish:FindFirstChild("Trigger") and c.Finish:FindFirstChild("Deck")
        and #c.Boundary:GetChildren() > 0
    if not ok then allOk = false end
    table.insert(out, ("%-15s cp=%d/%s arches=%d/%d liquid=%s pads=%d %s"):format(
        id, n, tostring(c:GetAttribute("CheckpointCount")), n - noArch, n,
        liquid and liquid.ClassName or "NONE", #c.Start.Pads:GetChildren(), ok and "OK" or "** FAIL **"))
end
table.insert(out, allOk and "ALL 7 PASS THE BOOT CONTRACT" or "** FAIL - fix before stopping **")
return table.concat(out, "\n")
```

**Expected baseline:** BallBarrage 5, WhirlpoolWaltz 5, DoorDash 5, TumbleTunnels 6,
TiptoeTrials 5, PistonPeak 6, SummitSplash 4 — every one `OK`.

---

## 9. Tasks

Do groups in order. Within a group, tasks are independent unless noted.
Update `docs/map-remediation.md` as each completes — not at the end.

---

### GROUP A — fully specified. Apply exactly as written.

#### A1 — Remove the deck under each swing panel (3 instances)

**Evidence:** `docs/image-39.png` — *"what is the point of the flap going up and down if there's
a platform under it?"* A panel that knocks you onto a solid deck 6 studs below is not a hazard.

| Course | Panel | Deck beneath | Deck size | dY | Deck `PieceId` |
|---|---|---|---|---|---|
| TiptoeTrials | `sd_TiptoeTrials_05_swingpanel_53` | `sd_TiptoeTrials_05_ride_52` | 20.5×20.5 | 6.4 | `Land07` |
| TumbleTunnels | `sd_TumbleTunnels_06_swingpanel_58` | `sd_TumbleTunnels_06_platform_57` | 23.1×29.7 | 6.4 | `Lane16` |
| WhirlpoolWaltz | `sd_WhirlpoolWaltz_04_swingpanel_36` | `sd_WhirlpoolWaltz_04_platform_35` | 12.6×16.2 | 1.4 | `Floor11` |

**STOP POINT — this is load-bearing.** All three decks are `Chain` route pieces, meaning the
route *walks across them*. Deleting one may strand the course over open lava.

**Phase 1 (Surveyor, read-only).** For each of the three, read the course route report and report:
- the preceding entry's `PieceId` and `Kind`
- the following entry's `PieceId` and `Kind`
- whether an `Advance` (jump gap) exists on either side
- what else, if anything, the runner could land on within 20 studs

**Then stop and report all three to the owner.** Do not delete anything yet.

Note the Whirlpool case is different: `dY = 1.4` means the panel is nearly flush with the floor,
not suspended above it. That likely needs the *panel raised*, not the deck deleted. Say so.

#### A2 — Clear the two hazards sitting on finish lines

**Evidence:** `docs/image-15.png` (*"bumper in the middle of the finish line"*),
`docs/image-45.png` (*"spinner right at the finish line"*).

| Course | Instance | Current pos | Size | Dist to `Finish.Deck` | `PieceId` |
|---|---|---|---|---|---|
| BallBarrage | `sd_BallBarrage_06_bumper_48` | −7.9, 14.6, −1900.4 | 7.9×5.1×8.5 | **5.6** | `Bumper04` |
| WhirlpoolWaltz | `sd_WhirlpoolWaltz_06_spinner_51` | 9.6, 3.1, −1861.1 | 29.0×6.2×29.0 | **8.6** | `Cross01` |

**Change:** move each **backwards along its own route heading** (`-forward`, §4.5) until its
distance to `Finish.Deck` is **≥ 16 studs**. Keep its Y and its rotation. Move the holder.

**Verify all three, and revert the move if any fails:**
(a) new distance ≥ 16;
(b) penetration against every other piece ≤ 0.75 studs (§8);
(c) it is still over a deck — use `supportingDeck` (§8). *A hazard pushed into open air is worse
than one at the finish line.*

**Explicitly not in this task:** `sd_DoorDash_06_spinner_110` (34 studs away — fine, leave it) and
`sd_PistonPeak_07_prop_67`, which carries `PieceId = FinishArch` — it is Piston Peak's *intended*
finish gate, not pasted-on junk. That one is task C3.

#### A3 — Fix two pre-existing checkpoint-arch intersections

Found during the earlier pass, not caused by it. Both minor.

| Course | Arch | Intersects | Depth |
|---|---|---|---|
| BallBarrage | `Checkpoint03.Arch` | `sd_BallBarrage_04_ramp_26` | 0.4 studs |
| PistonPeak | `Checkpoint06.Arch` | `sd_PistonPeak_06_piston_62_2` | 1.4 studs |

**Change:** walk the arch along its own route heading in 1-stud steps, nearest-first
(0, +1, −1, +2, −2, … to ±30). Place it at the first offset clearing everything by >0.1 studs
(§8 exclusions apply). This is the same procedure already used successfully on three other arches.

If no clear offset exists within ±30, **leave it and report** — do not delete an arch.

**Verify:** print before/after penetration depth for each.

#### A4 — Delete the preview folder (do this LAST, after all map work)

`Workspace.SplashdownPreview` holds ~1200 scratch parts and must not ship.

```lua
local p = workspace:FindFirstChild("SplashdownPreview")
if p then p:Destroy() end
return tostring(workspace:FindFirstChild("SplashdownPreview") == nil)
```

---

### GROUP B — measure, propose, then stop. Do not apply unapproved.

Each of these is a real defect whose *fix* needs judgement. Use the Surveyor → Analyst loop (§7)
and bring the owner a concrete proposal with numbers.

#### B1 — The slides

**The original "slides are buried" finding was wrong (§5.2).** All four are working descenders:
top flush with the deck above (24.02/24.00, 18.02/18.00, 14.02/14.00, 24.02/24.00).

The **real**, smaller defects:
1. The lower lip sits ~1 stud *below* the next deck's top — the visible clipping in
   `docs/image-43.png`.
2. The slide body is pushed into the previous deck's footprint (local Z offsets +4.1 to +10.2 on
   decks 13–27 deep) rather than starting at its edge, so it appears to emerge from inside the
   deck — `docs/image-14.png`, `docs/image-20.png`.

**Instances:** `sd_BallBarrage_06_slide_45`, `sd_DoorDash_02_slide_68`,
`sd_WhirlpoolWaltz_05_slide_40`, `sd_TumbleTunnels_07_slide_64`.

**Produce:** for each, the offset back along its route that puts its upper mouth at the upper
deck's *edge*, while keeping (a) its top flush with that deck and (b) its base at or above the
lower deck's top. Report all three numbers before and after, for all four slides. **Then stop** —
these are `Chain` pieces and moving one changes the route's arclength.

#### B2 — The fans and the log roll

Partly deliberate (§5.2). Read each piece's context before judging.

| Instance | Finding | Likely verdict |
|---|---|---|
| `sd_TumbleTunnels_01_fan_9` | sunk 3.26 into its deck | **Deliberate — leave it.** The grate is meant to finish flush so a runner crossing it is inside the airflow column. |
| `sd_TiptoeTrials_01_fan_4` | 14 studs below deck top **and outside the footprint in Z** (offset 15.8 on an 18-deep deck) | Genuinely wrong — `docs/image-28.png` |
| `sd_BallBarrage_04_fan_28` | overlaps `sd_BallBarrage_04_ramp_26` by 4.0 | investigate |
| `sd_PistonPeak_02_logroll_19` | overlaps `sd_PistonPeak_02_platform_18` by 2.7 | investigate |

**Produce:** for each of the latter three, a reading of whether the placement is deliberate and a
proposed fix with exact numbers. **Then stop.**

#### B3 — Tumble Tunnels' fan that sits inside a platform

`docs/image-19.png` — *"towards the maps end there is a fan literally inside of a platform."*
The beat-01 fan is the deliberate one (B2); this is a **different** instance near the course end.

**Produce:** identify it by name, measure it, determine whether its burial is deliberate, propose
a fix. **Then stop.**

---

### GROUP C — design work. Proposal first, always.

Every task here must stay within the existing asset inventory
(`docs/splashdown/01-asset-inventory.md`), match the map's existing visual style, and end with a
written record of what changed and why. **No new meshes. No resizing an asset into a shape it
isn't.**

**The single most useful piece of context:** **108 of the 176 kit assets are unused**, while
`platform_001/002/003` account for **179 placed instances**. That imbalance is the root of the
owner's "everything looks copy-pasted" complaint.

Unused and usable: `bridge_001/002/003`, `podium_001–007`, `octagon_001`, `arch_001/002/003`,
`road_002`, `ring_002`, `fence_001`, `obstacle_7_001`, `obstacle_20/21_001`, `wall_003/009–015`,
`water_platform_partition_*`, `water_platform_tube_*`, `box_004–010`, the whole `tower_*` family.

**Workflow for every Group C task:** Designer produces a written proposal (which assets, where,
why, and what it replaces) → owner approves → Applier places it → screenshot from the runner's
view → record in the tracker.

| ID | Map | Brief | Evidence |
|---|---|---|---|
| C1 | TumbleTunnels | Rebuild the ending tunnel. The paddlewheel sits **20.7 studs** and the swing panel **12.4 studs** inside `arch_004/005/006`. Make it traversable and legible. | `docs/image-40.png` |
| C2 | BallBarrage | Fill the **78-stud** hazard-free stretch at 44–78% and the bland run to the finish. Fix the third Big Ball, which cannot be reached from the ramp below it — **measure the jump arc from the ramp exit before changing anything**. Break up 3 chained identical slabs. Replace the `platform_00X` stack used as a bridge. | `docs/image-1.png`, `-25`, `-26`, `-32`, `-33` |
| C3 | PistonPeak | `sd_PistonPeak_07_prop_67` (`PieceId = FinishArch`, 20.0×14.3×31.5) overlaps the finish `Line`, the plaza, and platforms 64 and 66 by 2.1 studs each. **It is the intended finish gate — do not delete it.** Reposition it clear, or propose a replacement that reads as a finish gate at this course's scale. Also address the 5 scattered `wall_001` instances. | `docs/image-13.png`, `-12`, `-37` |
| C4 | **TiptoeTrials** | **Not in the owner's notes but worse than Ball Barrage.** Only **11 encounters across 880 studs**, with back-to-back dead stretches of **127.8** and **121.5** studs — 38%→66% of the route is empty. | route report |
| C5 | **WhirlpoolWaltz** | Also not in the notes. **14 encounters / 885 studs**, a **250-stud** gap at 17–45% and 135.7 at 85–100%. | route report |
| C6 | SummitSplash | The unreadable ending. **The foam pit, oversized arch and "floating pad" findings are all already resolved — re-screenshot and re-evaluate what is actually left before changing anything.** Also reduce the 29 `wall_001`/`wall_002` instances. Note Summit's dressing flags (`sd_flag.001/.002`, 29.6×83.8×8.1) are ~6.8× the built courses' `Flag01/02` (4.4×12.4×1.2) — decide whether that is Summit's legitimate larger scale or more of the same problem. | `docs/image-30.png`, `-29`, `-38`, `-31` |
| C7 | DoorDash | The "roof" over the opening door rows (8 `prop` pieces in beat 01). **The second half of this course is explicitly good — do not touch it.** | `docs/image-16.png`, `-17` |
| C8 | all | Conveyors. 8 instances of `obstacle_9_001`, a static chevron mat given a `Conveyor` attribute. Nothing reads as a belt. Needs a real design, not a tuning pass. | `docs/image-9.png` |
| C9 | all | Bring unused inventory in; break the `platform_00X` monotony. Broadest task here — do it **last**, once C1–C8 have already changed the picture. | `docs/image-36.png` |

---

### GROUP R — the one task that touches git

#### R1 — Rename Door Dash to Knock Knock

**Owner's decision, already made.** The name collides with the food-delivery company.

Because the course-builder toolkit is frozen (§1), this rename is scoped to the **running game**
only:

**Do change:**
- `src/config/Gameplay/Splashdown.luau` — the `CourseOrder` entry and the `Courses` table key
- `src/config/Interface/SplashdownIntro.luau` — the `Intro.Courses` key
- `src/shared/Tests/SplashdownIntroModel.spec.luau` — if it names the id
- Studio: `ReplicatedStorage.Assets.Maps.Splashdown.DoorDash` → `KnockKnock`
- Studio: `ServerStorage.SplashdownStaging.DoorDash` → `KnockKnock`
- Studio: ~470 instances named `sd_DoorDash_*` → `sd_KnockKnock_*`, **and their `CourseId`
  attribute**
- Studio: `ServerStorage.SplashdownStageReport_DoorDash_Route` → `..._KnockKnock_Route`
- `docs/splashdown/courses/door-dash.md` → `knock-knock.md`

**Do NOT change** (frozen): `src/shared/Game/Splashdown/CourseSpecs/DoorDash.luau`. It keeps its
old name. Record this in the tracker as a deliberate, known inconsistency — the specs have
already diverged from the shipped maps and are not being rebuilt.

**Sequence:** code side first → run the three checks below → then the Studio side. Between the two
the game is inconsistent; do not stop there.

```bash
bash src/scripts/shell/lint.sh src           # baseline: 0 errors, 2 warnings
bash src/scripts/shell/lint.sh places/arena  # baseline: 0 errors, 0 warnings
lune run src/scripts/lune/run-tests.luau     # baseline: 987 tests, 0 failures
```

The 2 Selene warnings are pre-existing in `src/scripts/lune/test-crate-services.luau` and are not
yours. `SplashdownIntroModel.spec` asserts `CourseOrder` and `Intro.Courses` agree, so it will
catch a half-done rename — use it.

Finish by running the §8 final check. `KnockKnock` must appear and `DoorDash` must not.

---

## 10. Things already decided — do not re-litigate

1. **Puncher throw is 18 on Ball Barrage, 11 on Piston Peak** — not 18 everywhere. Ball Barrage's
   lane is 21.0 studs wide; Piston Peak's is **8.8**, where 18 would punch 8.3 studs past the far
   edge into open air.
2. **Beach balls are 10.1 studs, not 20.** They are blown through an arch (33.1×23.7×52.1) whose
   bore is far narrower than 20 studs — a 20-stud ball would jam it.
3. **Tumble Tunnels' checkpoint 05 arch sits 23 studs from its trigger.** Three of four new arches
   initially landed inside existing geometry (a Big Ball, a ramp, a prop) — which is almost
   certainly why they were skipped originally. Each was walked to the nearest clear spot. This one
   is cosmetically loose but acceptable, because the trigger is now 56 studs wide and the arch is
   a marker rather than the detector. On the playtest list.
4. **Summit's sweeper keeps its sliding frame** (`RotorAmplitude = 8`) — it is deliberately tuned
   so the roller sweeps its narrow bridge end to end. Only Ball Barrage's was stripped.

---

## 11. Open questions for the owner

1. **The checkpoint arch is a small pink handlebar** (~11×8.4 studs), easy to miss at speed even
   when present — which is what made the sequential-checkpoint bug so punishing. Should a more
   legible marker be used? Not raised in the original notes.
2. **A1, B1, B2, B3 and every Group C task have explicit stop points.** Those proposals need
   approval before anything is applied.
3. **The axe now swings *along* the runner's path**, with its axle across the lane and the edge
   leading. The owner's note was ambiguous between that and a lateral sweep. Needs a playtest
   verdict.
4. **Peer sessions share this checkout.** A commit `c2460b9 "base wipeout"` swept the earlier work
   into one commit with an uninformative message; the owner may want that history cleaned up.

---

## 12. Playtest list — cannot be confirmed without playing

- Checkpoints advance end-to-end on all 7 courses. The gate is **strictly sequential** — the
  server only ever tests `currentCheckpoint + 1` — so one missed trigger kills every later one.
  Only a full run proves it.
- Whether the widened 56-stud trigger plane can be crossed accidentally from off-route.
- Whether a jump-pad launch (48–54 studs/s) or a fan lift can still tunnel a 2-stud-deep trigger.
- Tumble Tunnels checkpoint 05, whose arch sits 23 studs from its trigger.
- Door Dash pads 87→89 and the Pad03 succession now their decks are gone — the landing target
  shrank from a 10.5×13.5 deck to the 8.9-stud pad.
- Puncher feel at throw 18/11, period 1.9s.
- Seesaws at 34° — whether they now dump riders too eagerly.
- Beach balls at 10.1 studs with knockback.
- The four re-rolled hammers (see §11.3).
- Lava readability on 6 courses at once; whether the splash VFX still reads against purple.
- Piston Peak's rising liquid against the widened triggers.
- Everything in Group C.
