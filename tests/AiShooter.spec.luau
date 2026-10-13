local AiShooter = require("../src/shared/logic/AiShooter")
local Rng = require("../src/shared/logic/Rng")
local Shot = require("../src/shared/logic/Shot")
local config = require("../src/shared/config")

return function(t)
	t.test("shots are valid and power stays in config range", function()
		local rng = Rng.new(5)
		for _ = 1, 5000 do
			local shot = AiShooter.pickShot(rng)
			t.expect(Shot.isValid(shot), true)
			t.expect(shot.power >= config.aiPowerMin and shot.power <= config.aiPowerMax, true)
		end
	end)
	t.test("uses every column and height", function()
		local rng = Rng.new(6)
		local seen = {}
		for _ = 1, 1000 do
			local shot = AiShooter.pickShot(rng)
			seen[shot.column] = true
			seen[shot.height] = true
		end
		for _, key in { "left", "centre", "right", "high", "low" } do
			t.expect(seen[key], true)
		end
	end)
end
