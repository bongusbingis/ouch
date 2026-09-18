# Splashdown map remediation — literal instruction list

**This document replaces all earlier versions.** Earlier versions contained procedures that
required you to judge a situation. Two of them produced broken results. This version contains
**no judgement calls.** Every instruction is an exact value.

---

## 0. THE SINGLE MOST IMPORTANT RULE

**Never move, delete, resize or re-orient any instance unless this document names that exact
instance and gives you the exact value to use.**

If you think something looks wrong but this document does not name it: **write it down and report
it. Do not touch it.** Being right about a problem does not authorise you to invent a fix.

Two failures already happened because this rule did not exist:

- A spinner was moved "backwards along the course direction until it was 16 studs from the
  finish". The finish sits on a small island, so there was nowhere to move it to. The spinner
  ended up hovering over open lava. The correct action was to delete it.
- A bumper was moved the same way and ended up over open lava too.

Both were the result of following a *procedure* instead of applying a *value*. There are no
procedures in this document.

---

## 1. Where things are

### Connecting to Studio

**Do not hardcode a studio id — it changes every time Studio restarts.**

1. Call `mcp__Roblox_Studio__list_roblox_studios`.
2. Pick the entry whose `name` contains **`Match Place`** (placeId **121997450145716**).
3. Use that `id` for every call, with `datamodel_type: "Edit"`.

If no entry contains "Match Place", **stop and tell the owner.** Do not guess.

### Where the courses currently live

**`Workspace.SplashdownPreview`** — all 7 courses, spread out so the owner can see live changes.
**This is where you make every edit.**

The seven: `BallBarrage`, `WhirlpoolWaltz`, `DoorDash`, `TumbleTunnels`, `TiptoeTrials`,
`PistonPeak`, `SummitSplash`.

**`ReplicatedStorage.Assets.Maps.Splashdown` is currently EMPTY.** The courses were moved out,
not copied. **The game cannot boot in this state.** Task T9 puts them back. Until T9 runs, the
game is broken — that is expected and fine while you work.

### Off limits — do not open, edit or run any of these

```
src/shared/Game/Splashdown/CourseBuilder.luau
src/shared/Game/Splashdown/CoursePresets.luau
src/shared/Game/Splashdown/CourseSpecs/*.luau
src/shared/Game/Splashdown/AssetManifest.luau
src/shared/Game/Splashdown/CourseQA.luau
places/arena/tests/Assets/SplashdownQA.spec.luau
src/shared/Game/MapFeatures/RotatingPlatforms.luau
```

Never run any course authoring or rebuild script. Never regenerate a course.

**You do not need to edit any file in git.** This entire plan is Studio-only.

---

## 2. Absolute rules

1. **Only act on instructions in section 3.** Everything else is report-only.
2. **Never invent a coordinate, size, angle or offset.** If a value is not written here, stop.
3. **Print the before and after value for every change.** A change you did not print did not
   happen.
4. **Do all reads first, then all writes.** If a script errors halfway it keeps what it already
   did, which leaves the map in an unknown state.
5. **One task at a time.** Run it, verify it, report it, then move on.
6. **If a verification number does not match what this document says to expect, stop
   immediately** and report. Do not try to correct it yourself.
7. Do not touch git. Do not commit, revert, stage or stash.

### Helper you will need

Course pieces are usually a holder `Model` wrapping a MeshPart. Use this to measure either:

```lua
local function box(i)
    if i:IsA("BasePart") then return i.CFrame, i.Size end
    local c, s = i:GetBoundingBox(); return c, s
end
```

To find a named instance inside a course:

```lua
local function find(course, name)
    for _, d in course:GetDescendants() do
        if d.Name == name and d:IsA("Model") then return d end
    end
    for _, d in course:GetDescendants() do
        if d.Name == name then return d end
    end
    return nil
end
```

---

## 3. Tasks — do these in order

Each task gives you the exact instance, the exact action, and the exact number to expect
afterwards. Nothing here requires you to decide anything.

---

### T1 — Delete the Whirlpool Waltz finish spinner

**Instance:** `sd_WhirlpoolWaltz_06_spinner_51`, in `Workspace.SplashdownPreview.WhirlpoolWaltz`

**Action: delete it, including its holder Model.**

**Why (for your report, not for you to re-evaluate):** it is 29.0 × 6.2 × 29.0 studs. The Whirlpool
finish sits on its own small island — the finish plaza is 34 × 34 and the only other surface within
120 studs is `sd_WhirlpoolWaltz_06_platform_50` at 14 × 18, which is smaller than the spinner.
There is nowhere to put a 29-stud spinner near this finish. It is currently hovering over open
lava after an earlier bad move. Deletion is the correct outcome.

```lua
local prev = workspace.SplashdownPreview
local course = prev.WhirlpoolWaltz
local target
for _, d in course:GetDescendants() do
    if d.Name == "sd_WhirlpoolWaltz_06_spinner_51" then
        -- delete the outermost holder, not the inner MeshPart
        target = (d.Parent and d.Parent.Name == d.Name) and d.Parent or d
    end
end
if not target then return "ALREADY GONE - report this" end
local cf = target:IsA("BasePart") and target.CFrame or target:GetPivot()
local msg = ("DELETING %s at %.2f,%.2f,%.2f"):format(target:GetFullName(), cf.Position.X, cf.Position.Y, cf.Position.Z)
target:Destroy()
local still = 0
for _, d in course:GetDescendants() do if d.Name == "sd_WhirlpoolWaltz_06_spinner_51" then still += 1 end end
return msg .. ("\nremaining instances with that name: %d (EXPECT 0)"):format(still)
```

**Expect:** `remaining instances with that name: 0`

---

### T2 — Move the Ball Barrage bumper onto the last approach platform

**Instance:** `sd_BallBarrage_06_bumper_48`, in `Workspace.SplashdownPreview.BallBarrage`

**Action: set its position to exactly `(-22.171, 14.564, -2823.948)`.** Do not change its
rotation. Do not change its size.

**Why:** it is currently hovering over open lava after an earlier bad move. This coordinate
places it centred on `sd_BallBarrage_06_platform_47` (the last platform before the finish),
resting on that platform's top surface at Y = 12.0, and 19.39 studs back from `Finish.Deck`.
Verified: zero penetration against every other part in the course.

```lua
local prev = workspace.SplashdownPreview
local course = prev.BallBarrage
local target
for _, d in course:GetDescendants() do
    if d.Name == "sd_BallBarrage_06_bumper_48" then
        target = (d.Parent and d.Parent.Name == d.Name) and d.Parent or d
    end
end
if not target then return "NOT FOUND - report this" end
local before = target:IsA("BasePart") and target.CFrame or target:GetPivot()
local TARGET = Vector3.new(-22.171, 14.564, -2823.948)
if target:IsA("Model") then
    target:PivotTo(before.Rotation + TARGET)
else
    target.CFrame = before.Rotation + TARGET
end
local after = target:IsA("BasePart") and target.CFrame or target:GetPivot()
local deck = course.Finish.Deck
return ("BEFORE %.3f,%.3f,%.3f\nAFTER  %.3f,%.3f,%.3f\ndistance to Finish.Deck = %.2f (EXPECT 19.39)"):format(
    before.Position.X, before.Position.Y, before.Position.Z,
    after.Position.X, after.Position.Y, after.Position.Z,
    (after.Position - deck.Position).Magnitude)
```

**Expect:** `AFTER -22.171, 14.564, -2823.948` and `distance to Finish.Deck = 19.39`

---

### T3 — Raise the buried Tumble Tunnels fan so its grate is flush

**Instance:** `sd_TumbleTunnels_05_fan_43`, in `Workspace.SplashdownPreview.TumbleTunnels`

**Action: raise it by exactly `0.68` studs on Y.** Change nothing else.
Its Y goes from `5.66` to `6.34`.

**Why:** this is the fan the owner photographed in `docs/image-19.png` ("towards the maps end
there is a fan literally inside of a platform"). Its top is currently at Y = 11.32 while the deck
it sits in, `sd_TumbleTunnels_05_platform_42`, has its top at Y = 12.00 — so the fan is buried
0.68 studs below the surface, grate and all. The course spec's stated intent was that "the grate
finishes flush with the launch deck". Raising it 0.68 makes it exactly flush.

```lua
local prev = workspace.SplashdownPreview
local course = prev.TumbleTunnels
local target
for _, d in course:GetDescendants() do
    if d.Name == "sd_TumbleTunnels_05_fan_43" then
        target = (d.Parent and d.Parent.Name == d.Name) and d.Parent or d
    end
end
if not target then return "NOT FOUND - report this" end
local function box(i) if i:IsA("BasePart") then return i.CFrame, i.Size end local c,s = i:GetBoundingBox() return c,s end
local beforeCF, sz = box(target)
if target:IsA("Model") then target:PivotTo(target:GetPivot() + Vector3.new(0, 0.68, 0))
else target.CFrame = target.CFrame + Vector3.new(0, 0.68, 0) end
local afterCF = box(target)
local deck
for _, d in course:GetDescendants() do if d.Name == "sd_TumbleTunnels_05_platform_42" then deck = d end end
local deckTop = deck.Position.Y + deck.Size.Y/2
return ("BEFORE Y=%.2f fanTop=%.2f\nAFTER  Y=%.2f fanTop=%.2f\ndeckTop=%.2f  fanTop-deckTop=%+.2f (EXPECT +0.00)"):format(
    beforeCF.Position.Y, beforeCF.Position.Y + sz.Y/2,
    afterCF.Position.Y, afterCF.Position.Y + sz.Y/2,
    deckTop, (afterCF.Position.Y + sz.Y/2) - deckTop)
```

**Expect:** `AFTER Y=6.34` and `fanTop-deckTop=+0.00`

---

### T4 - Stop the finish-line z-fighting (6 courses)

**Action: lower each course's finish plaza part by exactly `0.05` studs on Y.**

**Why:** on all six courses that have one, the finish plaza's top surface is at *exactly* the
same height as the last approach deck's top, and their footprints overlap. Two coplanar
overlapping surfaces produce flickering (z-fighting). This is what the owner photographed in
`docs/image-15.png` ("z-clipping between the final and second-to-last platforms") and
`docs/image-23.png` ("z-clipping at the finish line; recurring in many courses"). Measured
top-difference before the fix is 0.000 on every one. Dropping the plaza 0.05 studs breaks the
coplanarity; a 0.05-stud step is far too small to affect movement.

Summit Splash has no `finishplaza` part and is correctly skipped by this script.

```lua
local prev = workspace.SplashdownPreview
local out = {}
for _, c in prev:GetChildren() do
    local plaza
    for _, d in c:GetDescendants() do
        if d:IsA("BasePart") and d.Name:find("finishplaza") then plaza = d end
    end
    if not plaza then
        table.insert(out, ("%-15s no finishplaza - skipped (expected for SummitSplash)"):format(c.Name))
    else
        local before = plaza.Position.Y + plaza.Size.Y / 2
        plaza.CFrame = plaza.CFrame - Vector3.new(0, 0.05, 0)
        local after = plaza.Position.Y + plaza.Size.Y / 2
        table.insert(out, ("%-15s plazaTop %.3f -> %.3f (moved %.3f)"):format(c.Name, before, after, before - after))
    end
end
return table.concat(out, "
")
```

**Expect:** six lines each showing `moved 0.050`, and one line for SummitSplash saying skipped.

---

### T5 - Separate the finish arch from its flags (4 courses)

**Action: move `Flag01` and `Flag02` each 2.0 studs directly away from the `Arch`,** along the
straight line from the Arch's centre to that flag. The direction is fully determined by the two
positions - there is nothing for you to choose.

**Why:** the finish arch is 28.0 studs wide (half-width 14.0) and each flag sits 15.1 studs from
its centre with a half-width of 2.2, so arch and flag interpenetrate by about 1.2 studs. This is
visible clipping at the finish line. Only BallBarrage, DoorDash, TiptoeTrials and TumbleTunnels
have both an `Arch` and flags; the script skips the rest.

```lua
local prev = workspace.SplashdownPreview
local out = {}
for _, c in prev:GetChildren() do
    local f = c.Finish
    local arch = f:FindFirstChild("Arch")
    if not arch then
        table.insert(out, ("%-15s no Finish.Arch - skipped"):format(c.Name))
    else
        for _, fname in { "Flag01", "Flag02" } do
            local flag = f:FindFirstChild(fname)
            if flag then
                local dir = flag.Position - arch.Position
                dir = Vector3.new(dir.X, 0, dir.Z)
                if dir.Magnitude < 0.01 then
                    table.insert(out, ("%-15s %s is centred on the Arch - SKIPPED, report this"):format(c.Name, fname))
                else
                    local beforeD = (flag.Position - arch.Position).Magnitude
                    flag.CFrame = flag.CFrame + dir.Unit * 2.0
                    local afterD = (flag.Position - arch.Position).Magnitude
                    table.insert(out, ("%-15s %s distance %.2f -> %.2f"):format(c.Name, fname, beforeD, afterD))
                end
            end
        end
    end
end
return table.concat(out, "
")
```

**Expect:** eight lines (two flags on each of four courses) each showing `distance 15.10 -> 17.10`,
plus skipped lines for PistonPeak, SummitSplash and WhirlpoolWaltz.

---

### T9 — LAST TASK: put the courses back so the game can boot

**Do this only after T1 through T5 are done and verified, and only when the owner says the
Studio work is finished for now.**

`ReplicatedStorage.Assets.Maps.Splashdown` is empty. The game loads courses from there and will
fail to start until all seven are back.

Moving them is safe: each model's pivot sits exactly on its `Origin` part (verified, 0.0000 studs
on all seven), and the game repositions each course on load, so their current spread-out
positions do not matter.

```lua
local prev = workspace:FindFirstChild("SplashdownPreview")
local maps = game.ReplicatedStorage.Assets.Maps:FindFirstChild("Splashdown")
if not prev then return "NO PREVIEW FOLDER - report this" end
if not maps then return "NO TARGET FOLDER - report this" end
local order = {"BallBarrage","WhirlpoolWaltz","DoorDash","TumbleTunnels","TiptoeTrials","PistonPeak","SummitSplash"}
local out = {}
for _, id in order do
    local c = prev:FindFirstChild(id)
    if not c then table.insert(out, "MISSING " .. id) else
        c.Parent = maps
        table.insert(out, ("moved %s"):format(id))
    end
end
table.insert(out, ("templates folder now holds %d courses (EXPECT 7)"):format(#maps:GetChildren()))
table.insert(out, ("preview folder now holds %d (EXPECT 0)"):format(#prev:GetChildren()))
return table.concat(out, "\n")
```

**Expect:** `templates folder now holds 7 courses` and `preview folder now holds 0`

Then delete the empty preview folder:

```lua
local p = workspace:FindFirstChild("SplashdownPreview")
if p and #p:GetChildren() == 0 then p:Destroy() end
return tostring(workspace:FindFirstChild("SplashdownPreview") == nil) .. " (EXPECT true)"
```

---

### T10 — Final boot-contract check

Run this after T9. It proves the game can start.

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
    table.insert(out, ("%-15s cp=%d/%s arches=%d/%d liquid=%s pads=%d boundary=%d %s"):format(
        id, n, tostring(c:GetAttribute("CheckpointCount")), n - noArch, n,
        liquid and liquid.ClassName or "NONE", #c.Start.Pads:GetChildren(),
        #c.Boundary:GetChildren(), ok and "OK" or "** FAIL **"))
end
table.insert(out, allOk and "ALL 7 PASS" or "** FAIL - report immediately **")
return table.concat(out, "\n")
```

**Expect exactly this:**

| Course | checkpoints | arches | liquid | pads | boundary |
|---|---|---|---|---|---|
| BallBarrage | 5/5 | 5/5 | MeshPart | 30 | 24 |
| WhirlpoolWaltz | 5/5 | 5/5 | MeshPart | 30 | 24 |
| DoorDash | 5/5 | 5/5 | MeshPart | 30 | 24 |
| TumbleTunnels | 6/6 | 6/6 | MeshPart | 30 | 24 |
| TiptoeTrials | 5/5 | 5/5 | MeshPart | 30 | 24 |
| PistonPeak | 6/6 | 6/6 | MeshPart | 30 | 24 |
| SummitSplash | 4/4 | 4/4 | MeshPart | 30 | 24 |

and `ALL 7 PASS`. Anything else: **stop and report.**

---

## 4. DO NOT TOUCH — known issues that need the owner

These are real problems. They are **not yours to fix.** They need design judgement, and a wrong
guess makes the map worse. The measurements are already done — your only job is to include this
list in your final report so the owner knows it is still outstanding.

### 4.1 The three swing panels sitting above solid decks

The owner asked (`docs/image-39.png`): *"what is the point of the flap going up and down if
there's a platform under it?"*

**The obvious fix — deleting the deck — would break three courses.** All three decks are
load-bearing route pieces:

| Course | Panel | Deck | Why the deck cannot be deleted |
|---|---|---|---|
| TiptoeTrials | `sd_TiptoeTrials_05_swingpanel_53` | `sd_TiptoeTrials_05_ride_52` | `Ride` piece, 20.2 studs of route across it, reached by an `Island` jump |
| TumbleTunnels | `sd_TumbleTunnels_06_swingpanel_58` | `sd_TumbleTunnels_06_platform_57` | `Chain` piece, 29.0 studs of route across it |
| WhirlpoolWaltz | `sd_WhirlpoolWaltz_04_swingpanel_36` | `sd_WhirlpoolWaltz_04_platform_35` | `Chain` piece with a 14-stud jump gap on **each** side — deleting it makes a 44-stud gap |

**Do not delete these decks. Do not move these panels.** Report only.

### 4.2 Three badly-seated hazards

All three need someone to decide where the piece *should* go, which is why they are not in
section 3. Measurements are current as of this document.

**`sd_TiptoeTrials_01_fan_4`** (TiptoeTrials) — centre Y = -2.34, base Y = -8.00. **No deck
contains its footprint**: it sits in open air beside the route, about 14 studs below
`sd_TiptoeTrials_01_platform_3` (top Y = 6.00). See `docs/image-28.png`.

**`sd_BallBarrage_04_fan_28`** (BallBarrage) — its base is **12.01 studs below** the top of
`sd_BallBarrage_04_ramp_26` (top Y = 24.0). Its centre is **outside** that ramp's X extent but
inside its Z extent, so it is tucked beside and under the ramp rather than mounted on it.

**`sd_PistonPeak_02_logroll_19`** (PistonPeak) — its base is **7.39 studs below** the top of
`sd_PistonPeak_02_platform_18` (top Y = 18.0) and its centre **is inside** that platform's
footprint in both X and Z, i.e. it is buried in the deck. It also measures 7.3 x **16.8** x 7.3,
meaning it is standing on end -- a log roll is meant to be laid on its side so it can roll, so its
mounting rotation looks wrong as well as its height.

**Do not move any of these three. Report only.**

### 4.3 Swing panel rest orientation (unresolved)

The owner's note on `docs/image-8.png` says "some of the swinging panels aren't swinging on their
proper axis". Measured: all three panels use `RotorAxis = "X"` with amplitude 28, and in every
case the rotation axis runs across the lane, so the panel tips forward and backward along the
runner's direction of travel. That is a defensible configuration, so the rotor axis may not be
the actual problem - the screenshot appears to show the panel's *resting* angle being wrong
rather than its axis. **This was never resolved.** It needs someone to look at the panel in
Studio from the runner's approach direction and decide. **Report only.**

### 4.4 The four slides

The earlier claim that these were "buried in platforms" was **wrong**. They are working
descenders: each has its top flush with the deck above and its base just above the deck below.
The real defects are much smaller (a lower lip ~1 stud low, and the body starting inside the
upper deck rather than at its edge). Fixing them means moving `Chain` route pieces, which changes
the route length.

`sd_BallBarrage_06_slide_45`, `sd_DoorDash_02_slide_68`, `sd_WhirlpoolWaltz_05_slide_40`,
`sd_TumbleTunnels_07_slide_64`. **Do not move them.** Report only.

### 4.5 Design work — none of this is yours

Do not attempt any of it. Listed so the owner has the full picture.

- Tumble Tunnels' ending tunnel: a paddlewheel 20.7 studs and a swing panel 12.4 studs inside the
  arch (`docs/image-40.png`).
- Ball Barrage: a 78-stud stretch with no hazards; a Big Ball that cannot be reached from the ramp
  below it (`docs/image-1.png`, `-25`, `-26`).
- TipToe Trials: only 11 hazards across 880 studs, with dead stretches of 127.8 and 121.5 studs.
- Whirlpool Waltz: 14 hazards across 885 studs, with a 250-stud dead stretch.
- Summit Splash: the unreadable ending (`docs/image-30.png`); 29 repeated wall assets.
- Piston Peak: `sd_PistonPeak_07_prop_67` is the intended finish gate but overlaps the finish line
  and two platforms by 2.1 studs each (`docs/image-13.png`). **Do not delete it.**
- Door Dash: the "roof" over the opening door rows (`docs/image-16.png`). **The second half of
  this course is good — do not touch it.**
- Conveyors across all maps read as static mats (`docs/image-9.png`).
- 108 of the 176 kit assets are unused while `platform_001/002/003` account for 179 placed
  instances — the root of the "everything looks copy-pasted" complaint.

### 4.6 Renaming Door Dash to Knock Knock

The owner decided this earlier. It touches config files and ~470 instance names, and the
course-builder files are frozen, so it needs a scoping decision first. **Not in this plan. Do not
start it.**

---

## 5. Already done — do not redo, do not re-report as bugs

Both the framework and the maps already received a large pass. Notably: fan blades no longer spin
on world Y; all checkpoint and finish triggers were widened from 12 studs to 56; four missing
checkpoint arches were added; the fall zone is purple lava instead of blue water on all six
non-Summit courses; all six foam pits were removed; three jammed bumper pairs were re-spaced; four
overhanging jump pads were pulled onto their decks; Summit's oversized finish arch was scaled to
match the others; seven seesaws were set to 34°; five punchers were moved inward and retuned; two
beach balls were enlarged and given knockback; four hammer blades were rotated 90° so the edge
leads instead of the flat face.

The two checkpoint-arch intersections listed in earlier versions of this plan now measure **0.00**
— they are already fixed. Do not act on them.

Full history is in `docs/map-remediation.md`.

---

## 6. Your final report

When T1, T2, T3, T4, T5, T9 and T10 are complete, report:

1. The before/after output of each of T1, T2, T3, T4 and T5.
2. The T10 table, confirming `ALL 7 PASS`.
3. The full contents of section 4 restated as "still outstanding, needs owner".
4. Anything you noticed that looked wrong but was not in section 3 — **described, not fixed.**
