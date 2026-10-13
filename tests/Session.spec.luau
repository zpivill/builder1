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
	t.test("records history in order and summarises the final kick", function()
		local s = Session.new({ seed = 11 })
		local log = playToEnd(s)
		local history = s:getHistory()
		t.expect(#history, #log)
		for i, kick in history do
			t.expect(kick.outcome, log[i])
			t.expect(kick.side, if i % 2 == 1 then "player" else "ai")
			t.expect(kick.summary ~= nil, i == #history)
		end
		local summary = history[#history].summary
		t.expect(summary.winner, s:getState().winner)
		t.expect(summary.scores.player, s:getState().scores.player)
		t.expect(#summary.player.kicks + #summary.ai.kicks, #history)
	end)

	t.test("uses the chosen presets", function()
		local function aiSaves(keeper)
			local saves = 0
			for seed = 1, 40 do
				local s = Session.new({ seed = seed, playerKeeper = keeper })
				playToEnd(s)
				for _, kick in s:getHistory() do
					if kick.side == "ai" and kick.outcome == "SAVED" then
						saves += 1
					end
				end
			end
			return saves
		end
		local great = aiSaves({ name = "Great", description = "", reach = 100, reaction = 100 })
		local poor = aiSaves({ name = "Poor", description = "", reach = 1, reaction = 1 })
		t.expect(great > poor, true)
	end)
end
