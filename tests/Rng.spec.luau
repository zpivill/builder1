local Rng = require("../src/shared/logic/Rng")

return function(t)
	t.test("same seed gives same sequence", function()
		local a, b = Rng.new(42), Rng.new(42)
		for _ = 1, 100 do
			t.expect(a:next(), b:next())
		end
	end)
	t.test("different seeds differ", function()
		t.expect(Rng.new(1):next() ~= Rng.new(2):next(), true)
	end)
	t.test("next stays in [0, 1)", function()
		local rng = Rng.new(7)
		for _ = 1, 10000 do
			local x = rng:next()
			t.expect(x >= 0 and x < 1, true)
		end
	end)
	t.test("int stays in range and hits both ends", function()
		local rng = Rng.new(9)
		local seen = {}
		for _ = 1, 1000 do
			local x = rng:int(1, 3)
			t.expect(x >= 1 and x <= 3 and x == math.floor(x), true)
			seen[x] = true
		end
		t.expect(seen[1] and seen[3], true)
	end)
end
