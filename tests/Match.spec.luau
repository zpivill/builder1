local Match = require("../src/shared/logic/Match")

-- Plays alternating kicks (p1 first); "G" = goal, "S" = saved.
local function play(match, kicks: string)
	local state = match:getState()
	for i = 1, #kicks do
		state = match:recordKick(if string.sub(kicks, i, i) == "G" then "GOAL" else "SAVED")
	end
	return state
end

return function(t)
	t.test("starts with p1, round 1, not sudden death", function()
		local s = Match.new():getState()
		t.expect(s.nextSide, "p1")
		t.expect(s.round, 1)
		t.expect(s.suddenDeath, false)
		t.expect(s.finished, false)
	end)

	t.test("full 5 rounds with a winner", function()
		-- p1 G S G S G = 3, p2 S G S G S = 2; decided only on the last kick.
		local m = Match.new()
		local s = play(m, "GSSGGSSGG")
		t.expect(s.finished, false)
		s = play(m, "S")
		t.expect(s.finished, true)
		t.expect(s.winner, "p1")
		t.expect(s.taken.p1, 5)
		t.expect(s.taken.p2, 5)
	end)

	t.test("finishes early when one side can't catch up", function()
		-- After 3 each: p1 3, p2 0, p2 has 2 kicks left.
		local s = play(Match.new(), "GSGSGS")
		t.expect(s.finished, true)
		t.expect(s.winner, "p1")
	end)

	t.test("p2 can win early too", function()
		-- After 3 each: p1 0, p2 3; p1 has 2 kicks left.
		local s = play(Match.new(), "SGSGSG")
		t.expect(s.finished, true)
		t.expect(s.winner, "p2")
	end)

	t.test("tie goes to sudden death", function()
		local s = play(Match.new(), "GGGGGGGGGG")
		t.expect(s.finished, false)
		t.expect(s.suddenDeath, true)
		t.expect(s.round, 6)
	end)

	t.test("sudden death waits for the pair, then decides", function()
		local m = Match.new()
		play(m, "GGGGGGGGGG")
		local s = play(m, "S")
		t.expect(s.finished, false)
		s = play(m, "G")
		t.expect(s.finished, true)
		t.expect(s.winner, "p2")
	end)

	t.test("sudden death continues while level", function()
		local m = Match.new()
		local s = play(m, "SSSSSSSSSS" .. "GG" .. "SS")
		t.expect(s.finished, false)
		t.expect(s.round, 8)
		s = play(m, "GS")
		t.expect(s.winner, "p1")
	end)

	t.test("rejects kicks after the match ends", function()
		local m = Match.new()
		play(m, "GSGSGS")
		t.expect(pcall(m.recordKick, m, "GOAL"), false)
	end)

	t.test("rejects invalid outcomes", function()
		local m = Match.new()
		t.expect(pcall(m.recordKick, m, "WHATEVER" :: any), false)
	end)
	t.test("a side that forfeits loses at once", function()
		local m = Match.new()
		play(m, "GG")
		local s = m:forfeit("p2")
		t.expect(s.finished, true)
		t.expect(s.winner, "p1")
		t.expect(m:forfeit("p1").winner, "p1") -- later forfeits change nothing
	end)
end
