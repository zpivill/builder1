local Summary = require("../src/shared/logic/Summary")

-- Alternating kicks, player first: "G" goal, "S" saved, "M" missed, "P" post.
local CODES = { G = "GOAL", S = "SAVED", M = "MISSED", P = "POST" }
local function history(kicks: string)
	local list = {}
	for i = 1, #kicks do
		local side = if i % 2 == 1 then "player" else "ai"
		table.insert(list, { side = side, outcome = CODES[string.sub(kicks, i, i)] })
	end
	return list
end

return function(t)
	t.test("counts each outcome per side", function()
		local s = Summary.build(history("GSPMGGSGMS"), "player")
		t.expect(s.player.goals, 2)
		t.expect(s.player.post, 1)
		t.expect(s.player.saved, 1)
		t.expect(s.player.missed, 1)
		t.expect(s.ai.goals, 2)
		t.expect(s.ai.saved, 2)
		t.expect(s.ai.missed, 1)
		t.expect(s.ai.post, 0)
		t.expect(s.scores.player, 2)
		t.expect(s.scores.ai, 2)
		t.expect(s.winner, "player")
	end)

	t.test("keeps kicks in order", function()
		local s = Summary.build(history("GSMG"), "ai")
		t.expect(#s.player.kicks, 2)
		t.expect(s.player.kicks[1], "GOAL")
		t.expect(s.player.kicks[2], "MISSED")
		t.expect(s.ai.kicks[1], "SAVED")
		t.expect(s.ai.kicks[2], "GOAL")
	end)

	t.test("flags sudden death only past the regulation rounds", function()
		t.expect(Summary.build(history("GGGGGGGGGS"), "player").suddenDeath, false)
		t.expect(Summary.build(history("GGGGGGGGGGGS"), "player").suddenDeath, true)
	end)
end
