local MathUtil = require("../src/shared/MathUtil")

return function(t)
	t.test("clamps below min", function()
		t.expect(MathUtil.clamp(-5, 0, 10), 0)
	end)
	t.test("clamps above max", function()
		t.expect(MathUtil.clamp(15, 0, 10), 10)
	end)
	t.test("keeps value in range", function()
		t.expect(MathUtil.clamp(5, 0, 10), 5)
	end)
end
