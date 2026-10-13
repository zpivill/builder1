local Rng = require("../src/shared/logic/Rng")
local Shot = require("../src/shared/logic/Shot")

local SHOOTER = { name = "Test", accuracy = 70, strength = 50 }
local KEEPER = { name = "Test", reach = 70, reaction = 70 }
local N = 10000

-- Fraction of N shots (cycling through every aim) that end in `outcome`.
local function rate(outcome, power, shooter, keeper, seed)
	local rng = Rng.new(seed)
	local count = 0
	for i = 1, N do
		local shot = {
			column = Shot.COLUMNS[1 + i % 3],
			height = if i % 2 == 0 then "high" else "low",
			power = power,
		}
		if Shot.resolveShot(shot, shooter, keeper, rng) == outcome then
			count += 1
		end
	end
	return count / N
end

return function(t)
	t.test("same seed gives same result", function()
		local shot = { column = "left", height = "high", power = 80 }
		for seed = 1, 50 do
			local a, da = Shot.resolveShot(shot, SHOOTER, KEEPER, Rng.new(seed))
			local b, db = Shot.resolveShot(shot, SHOOTER, KEEPER, Rng.new(seed))
			t.expect(a, b)
			t.expect(da, db)
		end
	end)

	t.test("higher strength raises effectivePower", function()
		t.expect(Shot.effectivePower(80, 90) > Shot.effectivePower(80, 20), true)
		t.expect(Shot.strengthFactor(1) < Shot.strengthFactor(100), true)
	end)

	t.test("higher effectivePower lowers save chance and raises miss chance", function()
		t.expect(Shot.saveChance(70, 100) < Shot.saveChance(70, 50), true)
		t.expect(Shot.missChance(100, 70, "low") > Shot.missChance(60, 70, "low"), true)
	end)

	t.test("higher accuracy lowers miss chance", function()
		t.expect(Shot.missChance(90, 90, "low") < Shot.missChance(90, 30, "low"), true)
	end)

	t.test("high aims miss more than low", function()
		t.expect(Shot.missChance(70, 70, "high") > Shot.missChance(70, 70, "low"), true)
	end)

	t.test("chances stay within [0, 1] at extremes", function()
		for _, a in { 0, 1, 100 } do
			for _, p in { 0, 130 } do
				local values = {
					Shot.missChance(p, a, "high"),
					Shot.missChance(p, a, "low"),
					Shot.saveChance(a, p),
					Shot.guessChance(a),
				}
				for _, v in values do
					t.expect(v >= 0 and v <= 1, true)
				end
			end
		end
	end)

	t.test("higher keeper reaction saves more (simulated)", function()
		local slow = rate("SAVED", 75, SHOOTER, { name = "", reach = 70, reaction = 10 }, 1)
		local fast = rate("SAVED", 75, SHOOTER, { name = "", reach = 70, reaction = 95 }, 1)
		t.expect(fast > slow, true)
	end)

	t.test("more power saves less and misses more (simulated)", function()
		t.expect(rate("SAVED", 100, SHOOTER, KEEPER, 2) < rate("SAVED", 40, SHOOTER, KEEPER, 2), true)
		local function offTarget(power)
			return rate("MISSED", power, SHOOTER, KEEPER, 3) + rate("POST", power, SHOOTER, KEEPER, 3)
		end
		t.expect(offTarget(100) > offTarget(40), true)
	end)

	t.test("wrong guess never saves", function()
		for seed = 1, 500 do
			local shot = { column = "right", height = "low", power = 60 }
			local outcome, dive = Shot.resolveShot(shot, SHOOTER, KEEPER, Rng.new(seed))
			if dive ~= "right" then
				t.expect(outcome ~= "SAVED", true)
			end
		end
	end)

	t.test("rejects invalid shots", function()
		local ok = pcall(Shot.resolveShot, { column = "up", height = "low", power = 50 }, SHOOTER, KEEPER, Rng.new(1))
		t.expect(ok, false)
		ok = pcall(Shot.resolveShot, { column = "left", height = "low", power = 101 }, SHOOTER, KEEPER, Rng.new(1))
		t.expect(ok, false)
	end)
end
