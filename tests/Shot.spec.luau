local Rng = require("../src/shared/logic/Rng")
local Shot = require("../src/shared/logic/Shot")

local N = 10000

-- Fraction of N kicks of `shot` against `dive` that end in `outcome`.
local function rate(outcome, shot, dive, seed)
	local rng = Rng.new(seed)
	local count = 0
	for _ = 1, N do
		if Shot.resolve(shot, dive, rng) == outcome then
			count += 1
		end
	end
	return count / N
end

local function shot(column, height, power)
	return { column = column, height = height, power = power }
end

local function dive(column, height)
	return { column = column, height = height }
end

return function(t)
	t.test("same seed gives same result", function()
		for seed = 1, 50 do
			local a = Shot.resolve(shot("left", "high", 80), dive("left", "high"), Rng.new(seed))
			local b = Shot.resolve(shot("left", "high", 80), dive("left", "high"), Rng.new(seed))
			t.expect(a, b)
		end
	end)

	t.test("wrong column never saves", function()
		t.expect(Shot.saveChance(shot("left", "low", 50), dive("right", "low")), 0)
		t.expect(rate("SAVED", shot("left", "low", 50), dive("centre", "low"), 1), 0)
	end)

	t.test("exact zone saves more than right column, wrong height", function()
		local exact = Shot.saveChance(shot("right", "high", 50), dive("right", "high"))
		local column = Shot.saveChance(shot("right", "high", 50), dive("right", "low"))
		t.expect(exact > column, true)
		t.expect(column > 0, true)
	end)

	t.test("save chances match the agreed starting values at power 50", function()
		t.expect(math.abs(Shot.saveChance(shot("left", "low", 50), dive("left", "low")) - 0.75) < 1e-9, true)
		t.expect(math.abs(Shot.saveChance(shot("left", "low", 50), dive("left", "high")) - 0.25) < 1e-9, true)
	end)

	t.test("more power lowers save chance and raises miss chance", function()
		t.expect(
			Shot.saveChance(shot("left", "low", 100), dive("left", "low"))
				< Shot.saveChance(shot("left", "low", 40), dive("left", "low")),
			true
		)
		t.expect(Shot.missChance(100, "low") > Shot.missChance(40, "low"), true)
	end)

	t.test("high aims miss more than low", function()
		t.expect(Shot.missChance(70, "high") > Shot.missChance(70, "low"), true)
	end)

	t.test("simulated rates follow the same directions", function()
		local exact = rate("SAVED", shot("centre", "low", 50), dive("centre", "low"), 2)
		local column = rate("SAVED", shot("centre", "low", 50), dive("centre", "high"), 2)
		t.expect(exact > column, true)
		local function offTarget(power)
			return rate("MISSED", shot("left", "high", power), dive("right", "low"), 3)
				+ rate("POST", shot("left", "high", power), dive("right", "low"), 3)
		end
		t.expect(offTarget(100) > offTarget(40), true)
	end)

	t.test("chances stay within [0, 1] at extremes", function()
		for _, p in { 0, 100 } do
			for _, h in { "high", "low" } do
				local m = Shot.missChance(p, h)
				local s = Shot.saveChance(shot("left", h, p), dive("left", h))
				t.expect(m >= 0 and m <= 1 and s >= 0 and s <= 1, true)
			end
		end
	end)

	t.test("rejects invalid shots and dives", function()
		t.expect(Shot.isValid(shot("up", "low", 50)), false)
		t.expect(Shot.isValid(shot("left", "low", 101)), false)
		t.expect(Shot.isValid(shot("left", "low", 0 / 0)), false)
		t.expect(Shot.isValidDive(dive("left", "middle")), false)
		t.expect(Shot.isValidDive("left"), false)
		t.expect(pcall(Shot.resolve, shot("left", "low", 50), dive("x", "low"), Rng.new(1)), false)
	end)
end
