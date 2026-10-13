local Summary = require("../src/shared/logic/Summary")

-- Alternating kicks, p1 first: "G" goal, "S" saved, "M" missed, "P" post.
local CODES = { G = "GOAL", S = "SAVED", M = "MISSED", P = "POST" }
local function history(kicks: string)
	local list = {}
	for i = 1, #kicks do
		local side = if i % 2 == 1 then "p1" else "p2"
		table.insert(list, { side = side, outcome = CODES[string.sub(kicks, i, i)] })
	end
	return list
end

return function(t)
	t.test("counts each outcome per side", function()
		local s = Summary.build(history("GSPMGGSGMS"), "p1")
		t.expect(s.p1.goals, 2)
		t.expect(s.p1.post, 1)
		t.expect(s.p1.saved, 1)
		t.expect(s.p1.missed, 1)
		t.expect(s.p2.goals, 2)
		t.expect(s.p2.saved, 2)
		t.expect(s.p2.missed, 1)
		t.expect(s.p2.post, 0)
		t.expect(s.scores.p1, 2)
		t.expect(s.scores.p2, 2)
		t.expect(s.winner, "p1")
	end)

	t.test("keeps kicks in order", function()
		local s = Summary.build(history("GSMG"), "p2")
		t.expect(#s.p1.kicks, 2)
		t.expect(s.p1.kicks[1], "GOAL")
		t.expect(s.p1.kicks[2], "MISSED")
		t.expect(s.p2.kicks[1], "SAVED")
		t.expect(s.p2.kicks[2], "GOAL")
	end)

	t.test("flags sudden death only past the regulation rounds", function()
		t.expect(Summary.build(history("GGGGGGGGGS"), "p1").suddenDeath, false)
		t.expect(Summary.build(history("GGGGGGGGGGGS"), "p1").suddenDeath, true)
	end)
end
