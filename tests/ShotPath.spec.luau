local ShotPath = require("../src/shared/logic/ShotPath")
local config = require("../src/shared/config")

local W, H = config.goalWidth, config.goalHeight

local function eachAim(fn)
	for _, column in { "left", "centre", "right" } do
		for _, height in { "high", "low" } do
			fn({ column = column, height = height, power = 70 })
		end
	end
end

local function inside(x, y)
	return math.abs(x) < W / 2 and y > 0 and y < H
end

return function(t)
	t.test("goals and saves land inside the goal frame", function()
		eachAim(function(shot)
			t.expect(inside(ShotPath.target(shot, "GOAL")), true)
			t.expect(inside(ShotPath.target(shot, "SAVED")), true)
		end)
	end)

	t.test("misses land outside the goal frame", function()
		eachAim(function(shot)
			local x, y = ShotPath.target(shot, "MISSED")
			t.expect(math.abs(x) > W / 2 or y > H, true)
		end)
	end)

	t.test("posts land on the frame", function()
		eachAim(function(shot)
			local x, y = ShotPath.target(shot, "POST")
			t.expect(math.abs(x) == W / 2 or y == H, true)
		end)
	end)

	t.test("left is negative x, right is positive x", function()
		t.expect(ShotPath.diveX("left") < 0, true)
		t.expect(ShotPath.diveX("centre"), 0)
		t.expect(ShotPath.diveX("right") > 0, true)
	end)
end
