-- Name: CourseVariety.spec.luau
-- Author: Jack C.
-- Description: Spec for the cross-course variety rules of HANDOFF section 7 override 2 - declared headline exclusivity, the three-course cap on non-glue mechanics, and the ban on two courses sharing a beat recipe - checked against seeded violating fixtures so a rule that silently stopped firing would fail here rather than pass a whole course set.
-- Created: 2026-09-16

--!strict

local T = require(script.Parent.TestKit)
local CourseQA = require(script.Parent.Parent.Game.Splashdown.CourseQA)

local function piece(id: string, preset: string, group: string?)
	return { Id = id, Kind = "Mount", Preset = preset, Scale = 1, EncounterGroup = group }
end

local function beat(id: string, family: string, mechanic: string, pieces: { any })
	return { Id = id, Family = family, Mechanic = mechanic, LengthTarget = 100, Pieces = pieces }
end

-- Two small courses that satisfy every cross-course rule: distinct declared
-- headlines, distinct family/mechanic pairs, and one user each for the non-glue
-- presets they use.
local function compliantPair()
	return {
		Alpha = {
			Id = "Alpha",
			Headline = "BigBall",
			Beats = {
				beat("01_Open", "Ride", "Counterbelt", { piece("Belt", "Conveyor") }),
				beat(
					"02_Climax",
					"Precision",
					"BigBallChain",
					{ piece("Ball1", "BigBall"), piece("Ball2", "BigBall") }
				),
				beat("03_Finish", "Timing", "Strikes", { piece("Hammer", "Hammer") }),
			},
		},
		Beta = {
			Id = "Beta",
			Headline = "RotatingPlatforms",
			Beats = {
				beat("01_Drop", "ClimbDescend", "ArchedDescent", { piece("Spin", "Spinner") }),
				beat("02_Climax", "Ride", "WedgePlatforms", {
					piece("Disc1", "RidePlatform"),
					piece("Disc2", "RidePlatform"),
				}),
				beat("03_Hub", "Crowd", "DoorChoke", { piece("Door", "Door") }),
			},
		},
	}
end

local function statusOf(findings: { any }, prefix: string): string?
	for _, finding in findings do
		if string.sub(finding.Check, 1, #prefix) == prefix then
			return finding.Status
		end
	end
	return nil
end

T.describe("CourseVariety cross-course rules", function()
	T.it("passes a compliant pair and reports every rule it checked", function()
		local findings, errors = CourseQA.auditCrossCourse(compliantPair())

		T.expect(#errors):toEqual(0)
		T.expect(statusOf(findings, "HeadlineNotAnotherClimax:Alpha")):toEqual("PASS")
		T.expect(statusOf(findings, "HeadlineDominantOutside<=1:Beta")):toEqual("PASS")
		T.expect(statusOf(findings, "NoSharedBeatRecipe")):toEqual("PASS")
	end)

	T.it("does not run the rules against a single course", function()
		local specs = compliantPair()
		specs.Beta = nil
		local findings, errors = CourseQA.auditCrossCourse(specs)

		T.expect(#errors):toEqual(0)
		T.expect(statusOf(findings, "CrossCourse")):toEqual("NOT RUN")
	end)

	T.it("rejects a headline that dominates another course's climax beat", function()
		local specs = compliantPair()
		-- Beta's climax now reads as a Big Ball beat, which is Alpha's headline.
		specs.Beta.Beats[2] = beat("02_Climax", "Ride", "WedgePlatforms", {
			piece("Ball1", "BigBall"),
			piece("Ball2", "BigBall"),
		})
		local _, errors = CourseQA.auditCrossCourse(specs)

		local matched = false
		for _, message in errors do
			if string.find(message, "HeadlineNotAnotherClimax:Alpha", 1, true) then
				matched = true
			end
		end
		T.expect(matched):toBeTruthy()
	end)

	T.it("rejects a headline that dominates more than one beat outside its own course", function()
		local specs = compliantPair()
		specs.Beta.Beats[1] = beat("01_Drop", "ClimbDescend", "ArchedDescent", { piece("Ball0", "BigBall") })
		specs.Beta.Beats[3] = beat("03_Hub", "Crowd", "DoorChoke", { piece("Ball3", "BigBall") })
		local _, errors = CourseQA.auditCrossCourse(specs)

		local matched = false
		for _, message in errors do
			if string.find(message, "HeadlineDominantOutside<=1:Alpha", 1, true) then
				matched = true
			end
		end
		T.expect(matched):toBeTruthy()
	end)

	T.it("caps a non-glue mechanic at three courses and leaves glue uncapped", function()
		local specs = compliantPair()
		for index, id in { "Gamma", "Delta" } do
			specs[id] = {
				Id = id,
				Headline = "Conveyor",
				Beats = {
					beat("01_" .. id, "Ride", "Belt" .. index, { piece("Belt", "Conveyor") }),
					beat("02_" .. id, "Timing", "Glue" .. index, { piece("Spin", "Spinner") }),
					beat("03_" .. id, "Timing", "More" .. index, { piece("Bump", "Bumper") }),
				},
			}
		end
		local _, errors = CourseQA.auditCrossCourse(specs)

		-- Conveyor is non-glue and now used by Alpha, Gamma and Delta: three is
		-- still legal.
		for _, message in errors do
			T.expect(string.find(message, "NonGlueCap<=3:Conveyor", 1, true) == nil):toBeTruthy()
		end

		specs.Epsilon = {
			Id = "Epsilon",
			Headline = "Conveyor",
			Beats = {
				beat("01_Epsilon", "Ride", "BeltFour", { piece("Belt", "Conveyor") }),
			},
		}
		local _, overCap = CourseQA.auditCrossCourse(specs)
		local matched = false
		for _, message in overCap do
			if string.find(message, "NonGlueCap<=3:Conveyor", 1, true) then
				matched = true
			end
		end
		T.expect(matched):toBeTruthy()
	end)

	T.it("rejects two courses sharing a family, mechanic and encounter recipe", function()
		local specs = compliantPair()
		specs.Beta.Beats[1] = beat("01_Drop", "Ride", "Counterbelt", { piece("Belt", "Conveyor") })
		local _, errors = CourseQA.auditCrossCourse(specs)

		local matched = false
		for _, message in errors do
			if string.find(message, "NoSharedBeatRecipe", 1, true) then
				matched = true
			end
		end
		T.expect(matched):toBeTruthy()
	end)

	T.it("rejects a course that declares no headline", function()
		local specs = compliantPair()
		specs.Beta.Headline = nil
		local _, errors = CourseQA.auditCrossCourse(specs)

		local matched = false
		for _, message in errors do
			if string.find(message, "declares no Headline", 1, true) then
				matched = true
			end
		end
		T.expect(matched):toBeTruthy()
	end)

	T.it("rejects a declared headline the course never uses", function()
		local specs = compliantPair()
		specs.Beta.Headline = "FallingTile"
		local _, errors = CourseQA.auditCrossCourse(specs)

		local matched = false
		for _, message in errors do
			if string.find(message, "does not occur in the course", 1, true) then
				matched = true
			end
		end
		T.expect(matched):toBeTruthy()
	end)
end)

return true
