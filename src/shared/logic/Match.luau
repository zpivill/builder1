-- Match state machine: alternating kicks (p1 first), regulation rounds,
-- early finish when one side can't catch up, then sudden death. A side that
-- leaves forfeits.

local Shot = require("./Shot")
local config = require("../config")

export type Side = "p1" | "p2"
export type State = {
	nextSide: Side,
	round: number,
	scores: { p1: number, p2: number },
	taken: { p1: number, p2: number },
	suddenDeath: boolean,
	finished: boolean,
	winner: Side?,
}

export type Match = {
	recordKick: (self: Match, outcome: Shot.Outcome) -> State,
	getState: (self: Match) -> State,
	forfeit: (self: Match, side: Side) -> State,
	_rounds: number,
	_scores: { p1: number, p2: number },
	_taken: { p1: number, p2: number },
	_next: Side,
	_winner: Side?,
}

local OUTCOMES = { GOAL = true, SAVED = true, MISSED = true, POST = true }

local Match = {}
Match.__index = Match

function Match.new(rounds: number?): Match
	local self = {
		_rounds = rounds or config.rounds,
		_scores = { p1 = 0, p2 = 0 },
		_taken = { p1 = 0, p2 = 0 },
		_next = "p1" :: Side,
		_winner = nil :: Side?,
	}
	return (setmetatable(self, Match) :: any) :: Match
end

local function checkWinner(self: Match): Side?
	local s, t, n = self._scores, self._taken, self._rounds
	if t.p1 <= n and t.p2 <= n then
		-- Regulation: finished as soon as one side can't catch up.
		if s.p1 + (n - t.p1) < s.p2 then
			return "p2"
		elseif s.p2 + (n - t.p2) < s.p1 then
			return "p1"
		end
	elseif t.p1 == t.p2 and s.p1 ~= s.p2 then
		-- Sudden death: decided after each complete pair.
		return if s.p1 > s.p2 then "p1" else "p2"
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
	self._next = Match.other(side)
	self._winner = checkWinner(self)
	return self:getState()
end

function Match.other(side: Side): Side
	return if side == "p1" then "p2" else "p1"
end

-- The side that leaves loses; the other side wins straight away.
function Match.forfeit(self: Match, side: Side): State
	if self._winner == nil then
		self._winner = Match.other(side)
	end
	return self:getState()
end

return Match
