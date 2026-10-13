-- Builds the result-screen data from a finished match's kick history.

local config = require("../config")

export type SideStats = { goals: number, saved: number, missed: number, post: number, kicks: { string } }
export type Summary = {
	winner: string?,
	scores: { p1: number, p2: number },
	suddenDeath: boolean,
	p1: SideStats,
	p2: SideStats,
}

local FIELD = { GOAL = "goals", SAVED = "saved", MISSED = "missed", POST = "post" }

local Summary = {}

function Summary.build(history: { { side: string, outcome: string } }, winner: string?): Summary
	local sides = {
		p1 = { goals = 0, saved = 0, missed = 0, post = 0, kicks = {} },
		p2 = { goals = 0, saved = 0, missed = 0, post = 0, kicks = {} },
	}
	for _, kick in history do
		local stats = sides[kick.side]
		stats[FIELD[kick.outcome]] += 1
		table.insert(stats.kicks, kick.outcome)
	end
	return {
		winner = winner,
		scores = { p1 = sides.p1.goals, p2 = sides.p2.goals },
		suddenDeath = #sides.p1.kicks > config.rounds or #sides.p2.kicks > config.rounds,
		p1 = sides.p1,
		p2 = sides.p2,
	}
end

return Summary
