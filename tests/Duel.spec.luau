local Duel = require("../src/shared/logic/Duel")
local config = require("../src/shared/config")

local SHOT = { column = "left", height = "low", power = 60 }
local DIVE = { column = "right", height = "high" }

-- Plays kicks with both choices made until the match ends.
local function playToEnd(duel)
	local log = {}
	for _ = 1, 200 do
		local shooter, keeper = duel:roles()
		duel:choose(shooter, SHOT)
		duel:choose(keeper, DIVE)
		local result = duel:resolve()
		table.insert(log, result.outcome)
		if result.state.finished then
			break
		end
	end
	return log
end

return function(t)
	t.test("p1 shoots first and roles swap every kick", function()
		local d = Duel.new(1)
		local shooter, keeper = d:roles()
		t.expect(shooter, "p1")
		t.expect(keeper, "p2")
		d:resolve()
		shooter, keeper = d:roles()
		t.expect(shooter, "p2")
		t.expect(keeper, "p1")
	end)

	t.test("each role must send the right kind of choice", function()
		local d = Duel.new(1)
		t.expect(select(2, d:choose("p1", DIVE)), "invalid shot")
		t.expect(select(2, d:choose("p2", { column = "left" })), "invalid dive")
		t.expect(d:choose("p1", SHOT), true)
		t.expect(d:choose("p2", DIVE), true)
	end)

	t.test("rejects bad input from clients", function()
		local d = Duel.new(1)
		for _, bad in
			{ "kick", { column = "left", height = "low", power = 0 / 0 }, { column = "x", height = "low", power = 5 } }
		do
			local ok = d:choose("p1", bad)
			t.expect(ok, false)
		end
		t.expect(d:hasChosen("p1"), false)
	end)

	t.test("ready only once both have chosen", function()
		local d = Duel.new(1)
		t.expect(d:isReady(), false)
		d:choose("p1", SHOT)
		t.expect(d:hasChosen("p1"), true)
		t.expect(d:isReady(), false)
		d:choose("p2", DIVE)
		t.expect(d:isReady(), true)
	end)

	t.test("choices are copied and can be changed before resolving", function()
		local d = Duel.new(1)
		local mine = { column = "left", height = "low", power = 60 }
		d:choose("p1", mine)
		mine.column = "right" -- client-side table changes must not leak in
		d:choose("p1", { column = "centre", height = "high", power = 30 })
		d:choose("p2", DIVE)
		local r = d:resolve()
		t.expect(r.shot.column, "centre")
		t.expect(r.shot.power, 30)
	end)

	t.test("missing choices use the defaults and are flagged", function()
		local d = Duel.new(1)
		d:choose("p2", DIVE)
		local r = d:resolve()
		t.expect(r.defaulted.shot, true)
		t.expect(r.defaulted.dive, false)
		t.expect(r.shot.column, config.defaultShot.column)
		t.expect(r.shot.power, config.defaultShot.power)
		t.expect(r.dive.column, "right")
	end)

	t.test("choices reset after each kick", function()
		local d = Duel.new(1)
		d:choose("p1", SHOT)
		d:choose("p2", DIVE)
		d:resolve()
		t.expect(d:isReady(), false)
		t.expect(d:hasChosen("p1"), false)
		t.expect(d:hasChosen("p2"), false)
	end)

	t.test("full match reaches a winner, with a summary, then refuses choices", function()
		for seed = 1, 20 do
			local d = Duel.new(seed)
			playToEnd(d)
			local history = d:getHistory()
			local last = history[#history]
			t.expect(last.state.finished, true)
			t.expect(last.summary ~= nil, true)
			t.expect(last.summary.winner, last.state.winner)
			t.expect(select(2, d:choose("p1", SHOT)), "match is finished")
		end
	end)

	t.test("same seed plays the same match", function()
		local a, b = playToEnd(Duel.new(77)), playToEnd(Duel.new(77))
		t.expect(#a, #b)
		for i = 1, #a do
			t.expect(a[i], b[i])
		end
	end)

	t.test("forfeit ends the match for the other side", function()
		local d = Duel.new(1)
		d:choose("p1", SHOT)
		local summary = d:forfeit("p1")
		t.expect(summary.winner, "p2")
		t.expect(d:getState().finished, true)
		t.expect(d:isReady(), false)
	end)
end
