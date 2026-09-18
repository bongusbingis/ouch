-- Name: author-splashdown-courses.luau
-- Author: Jack C.
-- Description: RETIRED at the HANDOFF.md section 12.1 replacement transaction (2026-09-16). This module used to hold the seven imperative Studio Edit recipes for the original Splashdown courses; all seven are superseded and six of their parked models were permanently destroyed at the same swap, so every recipe and every helper that could recreate them has been removed rather than left behind a flag. The three public entry points remain only so an old Command Bar line fails loudly instead of silently doing nothing, and they direct the author at src/scripts/studio/author-splashdown-v2.luau, which drives the declarative CourseBuilder/CourseAuthoring pipeline.
-- Created: 2026-09-14

--!strict

local Author = {}

local RETIRED = table.concat({
	"[SplashdownAuthor] the imperative course recipes were retired at the HANDOFF section 12.1",
	"replacement transaction. WhirlPool, DiscJockey, KnockKnock, BumperBay, TiltTrip, CrossCurrent",
	"and Downpour no longer exist as courses, their parked models were destroyed with no archive,",
	"and SummitSplash is now built by the declarative pipeline's SourcePatch layout from",
	"ServerStorage.SplashdownAuthoringSources.SummitSource. Author courses through",
	"src/scripts/studio/author-splashdown-v2.luau instead: it documents the exact Command Bar lines",
	"for CourseAuthoring.stage / .preview / .clearPreview / .promote over the seven CourseSpecs.",
}, " ")

-- No recipe table, no course DSL and no templates folder helper survive here.
-- HANDOFF 12.1.4 requires that no executable path in this file can recreate a
-- retired course, so the entry points do nothing except raise.
function Author.build(_courseIds: { string }?): { string }
	error(RETIRED, 2)
end

function Author.preview(_courseId: string): string
	error(RETIRED, 2)
end

function Author.restore(): string
	error(RETIRED, 2)
end

return Author
