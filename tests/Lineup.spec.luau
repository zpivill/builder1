local Lineup = require("../src/shared/logic/Lineup")
local config = require("../src/shared/config")

return function(t)
	t.test("accepts valid picks and copies them", function()
		local input = { shooter = 2, keeper = 1, extra = "ignored" }
		local choice = Lineup.validChoice(input)
		t.expect(choice.shooter, 2)
		t.expect(choice.keeper, 1)
		t.expect(choice.extra, nil)
	end)

	t.test("rejects bad picks", function()
		local bad = {
			"nope",
			{ shooter = 1 },
			{ keeper = 1 },
			{ shooter = 0, keeper = 1 },
			{ shooter = 1, keeper = #config.keepers + 1 },
			{ shooter = 1.5, keeper = 1 },
			{ shooter = "1", keeper = 1 },
			{ shooter = 0 / 0, keeper = 1 },
		}
		for _, choice in bad do
			local result, err = Lineup.validChoice(choice)
			t.expect(result, nil)
			t.expect(err ~= nil, true)
		end
		t.expect(Lineup.validChoice(nil), nil)
	end)

	t.test("fromChoice returns the chosen presets", function()
		local lineup = Lineup.fromChoice({ shooter = 2, keeper = 1 })
		t.expect(lineup.shooter, config.shooters[2])
		t.expect(lineup.keeper, config.keepers[1])
	end)

	t.test("AI gets the presets the player didn't pick", function()
		for s = 1, #config.shooters do
			for k = 1, #config.keepers do
				local ai = Lineup.aiChoice({ shooter = s, keeper = k })
				t.expect(ai.shooter ~= s, true)
				t.expect(ai.keeper ~= k, true)
			end
		end
	end)
end
