-- Builds the result-screen data from a finished match's kick history.

local config = require("../config")

export type SideStats = { goals: number, saved: number, missed: number, post: number, kicks: { string } }
export type Summary = {
	winner: string?,
	scores: { player: number, ai: number },
	suddenDeath: boolean,
	player: SideStats,
	ai: SideStats,
}

local FIELD = { GOAL = "goals", SAVED = "saved", MISSED = "missed", POST = "post" }

local Summary = {}

function Summary.build(history: { { side: string, outcome: string } }, winner: string?): Summary
	local sides = {
		player = { goals = 0, saved = 0, missed = 0, post = 0, kicks = {} },
		ai = { goals = 0, saved = 0, missed = 0, post = 0, kicks = {} },
	}
	for _, kick in history do
		local stats = sides[kick.side]
		stats[FIELD[kick.outcome]] += 1
		table.insert(stats.kicks, kick.outcome)
	end
	return {
		winner = winner,
		scores = { player = sides.player.goals, ai = sides.ai.goals },
		suddenDeath = #sides.player.kicks > config.rounds or #sides.ai.kicks > config.rounds,
		player = sides.player,
		ai = sides.ai,
	}
end

return Summary
