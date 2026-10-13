local Session = require("../src/shared/logic/Session")

local SHOT = { column = "left", height = "low", power = 70 }

local function playToEnd(session)
	local log = {}
	for _ = 1, 200 do
		local result = session:playerKick(SHOT)
		if not result then
			break
		end
		table.insert(log, result.outcome)
		if result.state.finished then
			break
		end
		result = session:aiKick()
		table.insert(log, result.outcome)
		if result.state.finished then
			break
		end
	end
	return log
end

return function(t)
	t.test("player kicks first; AI cannot kick out of turn", function()
		local s = Session.new({ seed = 1 })
		local result, err = s:aiKick()
		t.expect(result, nil)
		t.expect(err, "not your turn")
		t.expect(s:playerKick(SHOT) ~= nil, true)
	end)

	t.test("player cannot kick twice in a row", function()
		local s = Session.new({ seed = 1 })
		s:playerKick(SHOT)
		local result, err = s:playerKick(SHOT)
		t.expect(result, nil)
		t.expect(err, "not your turn")
	end)

	t.test("rejects invalid shots from the client", function()
		local s = Session.new({ seed = 1 })
		for _, bad in
			{
				nil,
				"kick",
				{ column = "left", height = "low" },
				{ column = "x", height = "low", power = 50 },
				{
					column = "left",
					height = "low",
					power = 0 / 0,
				},
			}
		do
			local result, err = s:playerKick(bad)
			t.expect(result, nil)
			t.expect(err, "invalid shot")
		end
		t.expect(s:getState().taken.player, 0)
	end)

	t.test("result reports side, outcome, dive and state", function()
		local s = Session.new({ seed = 3 })
		local r = s:playerKick(SHOT)
		t.expect(r.side, "player")
		t.expect(r.shot.column, "left")
		t.expect(r.dive ~= nil, true)
		t.expect(r.state.nextSide, "ai")
		r = s:aiKick()
		t.expect(r.side, "ai")
		t.expect(r.state.nextSide, "player")
	end)

	t.test("full match reaches a winner and then refuses kicks", function()
		for seed = 1, 30 do
			local s = Session.new({ seed = seed })
			playToEnd(s)
			local state = s:getState()
			t.expect(state.finished, true)
			t.expect(state.winner == "player" or state.winner == "ai", true)
			local _, err = s:playerKick(SHOT)
			t.expect(err, "match is finished")
		end
	end)

	t.test("same seed plays the same match", function()
		local a = playToEnd(Session.new({ seed = 77 }))
		local b = playToEnd(Session.new({ seed = 77 }))
		t.expect(#a, #b)
		for i = 1, #a do
			t.expect(a[i], b[i])
		end
	end)
end
