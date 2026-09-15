--!strict
local T = require(script.Parent.TestKit)
local Model = require(script.Parent.Parent.UI.Models.SplashdownIntroModel)
local RS = script.Parent.Parent.Parent
local Splashdown = require(RS.Config.Gameplay.Splashdown)
local Intro = require(RS.Config.Interface.SplashdownIntro)

T.describe("SplashdownIntroModel", function()
	T.it("joins the current shot using the server deadline, including exact cuts", function()
		local duration = Splashdown.IntroSeconds
		local endsAt = 100 + duration
		T.expect(Model.sample("DiscJockey", endsAt, 100).index):toEqual(1)
		T.expect(Model.sample("DiscJockey", endsAt, 100 + duration / 3).index):toEqual(2)
		local late = Model.sample("DiscJockey", endsAt, 100 + duration * 0.8)
		T.expect(late.index):toEqual(3)
		T.expect(late.progress):toBeNear(0.8, 1e-9)
		T.expect(Model.sample("DiscJockey", endsAt, 100 + duration * 0.8).shot):toEqual(late.shot)
	end)

	T.it("clamps clock skew and an expired intro without wrapping to the first shot", function()
		local early = Model.sample("WhirlPool", 109, 90)
		local expired = Model.sample("WhirlPool", 109, 120)
		T.expect(early.index):toEqual(1)
		T.expect(early.progress):toEqual(0)
		T.expect(expired.index):toEqual(3)
		T.expect(expired.progress):toEqual(1)
	end)

	T.it("covers each camera cut while leaving the held shots unobscured", function()
		local third = Splashdown.IntroSeconds / 3
		local endsAt = 100 + Splashdown.IntroSeconds
		for index = 0, 3 do
			T.expect(Model.sample("KnockKnock", endsAt, 100 + third * index).cover):toBeNear(1, 1e-9)
		end
		T.expect(Model.sample("KnockKnock", endsAt, 100 + third / 2).cover):toEqual(0)
	end)

	T.it("provides instructions and three nondegenerate fixed shots for every playable course", function()
		for _, courseId in Splashdown.CourseOrder do
			local course = Intro.Courses[courseId]
			T.expect(course ~= nil):toEqual(true)
			T.expect(#course.Shots):toEqual(3)
			T.expect(#course.Description > 20):toEqual(true)
			for _, shot in course.Shots do
				local distance = 0
				for axis = 1, 3 do
					distance += (shot.Eye[axis] - shot.Look[axis]) ^ 2
				end
				T.expect(distance > 100):toEqual(true)
				T.expect(shot.FieldOfView >= 40 and shot.FieldOfView <= 80):toEqual(true)
			end
		end
	end)

	T.it("keeps unknown courses safe and widens the lens on narrow viewports", function()
		T.expect(#Model.course("FutureCourse").Shots):toEqual(3)
		T.expect(Model.fieldOfView(60, 16 / 9)):toBeNear(60, 1e-9)
		T.expect(Model.fieldOfView(60, 21 / 9)):toBeNear(60, 1e-9)
		T.expect(Model.fieldOfView(60, 4 / 3) > 60):toEqual(true)
		T.expect(Model.fieldOfView(60, 0)):toEqual(Intro.MaxFieldOfView)
	end)
end)

return true
