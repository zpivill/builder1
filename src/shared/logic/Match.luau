-- Match state machine: alternating kicks (player first), regulation rounds,
-- early finish when one side can't catch up, then sudden death.

local Shot = require("./Shot")
local config = require("../config")

export type Side = "player" | "ai"
export type State = {
	nextSide: Side,
	round: number,
	scores: { player: number, ai: number },
	taken: { player: number, ai: number },
	suddenDeath: boolean,
	finished: boolean,
	winner: Side?,
}

export type Match = {
	recordKick: (self: Match, outcome: Shot.Outcome) -> State,
	getState: (self: Match) -> State,
	_rounds: number,
	_scores: { player: number, ai: number },
	_taken: { player: number, ai: number },
	_next: Side,
	_winner: Side?,
}

local OUTCOMES = { GOAL = true, SAVED = true, MISSED = true, POST = true }

local Match = {}
Match.__index = Match

function Match.new(rounds: number?): Match
	local self = {
		_rounds = rounds or config.rounds,
		_scores = { player = 0, ai = 0 },
		_taken = { player = 0, ai = 0 },
		_next = "player" :: Side,
		_winner = nil :: Side?,
	}
	return (setmetatable(self, Match) :: any) :: Match
end

local function checkWinner(self: Match): Side?
	local s, t, n = self._scores, self._taken, self._rounds
	if t.player <= n and t.ai <= n then
		-- Regulation: finished as soon as one side can't catch up.
		if s.player + (n - t.player) < s.ai then
			return "ai"
		elseif s.ai + (n - t.ai) < s.player then
			return "player"
		end
	elseif t.player == t.ai and s.player ~= s.ai then
		-- Sudden death: decided after each complete pair.
		return if s.player > s.ai then "player" else "ai"
	end
	return nil
end

function Match.getState(self: Match): State
	local taken = self._taken[self._next]
	return {
		nextSide = self._next,
		round = taken + 1,
		scores = table.clone(self._scores),
		taken = table.clone(self._taken),
		suddenDeath = taken >= self._rounds,
		finished = self._winner ~= nil,
		winner = self._winner,
	}
end

function Match.recordKick(self: Match, outcome: Shot.Outcome): State
	assert(self._winner == nil, "match is already finished")
	assert(OUTCOMES[outcome], "invalid outcome")
	local side = self._next
	self._taken[side] += 1
	if outcome == "GOAL" then
		self._scores[side] += 1
	end
	self._next = if side == "player" then "ai" else "player"
	self._winner = checkWinner(self)
	return self:getState()
end

return Match
