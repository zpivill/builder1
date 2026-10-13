local Match = require("../src/shared/logic/Match")

-- Plays alternating kicks (player first); "G" = goal, "S" = saved.
local function play(match, kicks: string)
	local state = match:getState()
	for i = 1, #kicks do
		state = match:recordKick(if string.sub(kicks, i, i) == "G" then "GOAL" else "SAVED")
	end
	return state
end

return function(t)
	t.test("starts with player, round 1, not sudden death", function()
		local s = Match.new():getState()
		t.expect(s.nextSide, "player")
		t.expect(s.round, 1)
		t.expect(s.suddenDeath, false)
		t.expect(s.finished, false)
	end)

	t.test("full 5 rounds with a winner", function()
		-- Player G S G S G = 3, AI S G S G S = 2; decided only on the last kick.
		local m = Match.new()
		local s = play(m, "GSSGGSSGG")
		t.expect(s.finished, false)
		s = play(m, "S")
		t.expect(s.finished, true)
		t.expect(s.winner, "player")
		t.expect(s.taken.player, 5)
		t.expect(s.taken.ai, 5)
	end)

	t.test("finishes early when one side can't catch up", function()
		-- After 3 each: player 3, AI 0, AI has 2 kicks left.
		local s = play(Match.new(), "GSGSGS")
		t.expect(s.finished, true)
		t.expect(s.winner, "player")
	end)

	t.test("AI can win early too", function()
		-- After 3 each: player 0, AI 3; player has 2 kicks left.
		local s = play(Match.new(), "SGSGSG")
		t.expect(s.finished, true)
		t.expect(s.winner, "ai")
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
		t.expect(s.winner, "ai")
	end)

	t.test("sudden death continues while level", function()
		local m = Match.new()
		local s = play(m, "SSSSSSSSSS" .. "GG" .. "SS")
		t.expect(s.finished, false)
		t.expect(s.round, 8)
		s = play(m, "GS")
		t.expect(s.winner, "player")
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
end
