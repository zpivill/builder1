-- One match between two players (slots p1 and p2). Each kick the shooter and
-- the keeper submit hidden choices; once both are in, or time runs out, the
-- kick is resolved. Pure logic so the server script stays a thin wrapper.

local Match = require("./Match")
local Rng = require("./Rng")
local Shot = require("./Shot")
local Summary = require("./Summary")
local config = require("../config")

export type KickResult = {
	side: Match.Side, -- the shooter
	keeper: Match.Side,
	shot: Shot.Shot,
	dive: Shot.Dive,
	defaulted: { shot: boolean, dive: boolean }, -- true where time ran out
	outcome: Shot.Outcome,
	state: Match.State,
	summary: Summary.Summary?, -- set on the kick that ends the match
}

export type Duel = {
	getState: (self: Duel) -> Match.State,
	roles: (self: Duel) -> (Match.Side, Match.Side),
	choose: (self: Duel, side: Match.Side, choice: any) -> (boolean, string?),
	hasChosen: (self: Duel, side: Match.Side) -> boolean,
	isReady: (self: Duel) -> boolean,
	resolve: (self: Duel) -> KickResult,
	forfeit: (self: Duel, side: Match.Side) -> Summary.Summary,
	summary: (self: Duel) -> Summary.Summary,
	getHistory: (self: Duel) -> { KickResult },
	_match: Match.Match,
	_rng: Rng.Rng,
	_shot: Shot.Shot?,
	_dive: Shot.Dive?,
	_history: { KickResult },
}

local Duel = {}
Duel.__index = Duel

function Duel.new(seed: number): Duel
	local self = {
		_match = Match.new(),
		_rng = Rng.new(seed),
		_shot = nil,
		_dive = nil,
		_history = {},
	}
	return (setmetatable(self, Duel) :: any) :: Duel
end

function Duel.getState(self: Duel): Match.State
	return self._match:getState()
end

-- Who shoots and who keeps for the next kick.
function Duel.roles(self: Duel): (Match.Side, Match.Side)
	local shooter = self._match:getState().nextSide
	return shooter, Match.other(shooter)
end

-- `choice` comes from a client, so it is validated and copied. A player may
-- change their choice until the kick is resolved.
function Duel.choose(self: Duel, side: Match.Side, choice: any): (boolean, string?)
	if self._match:getState().finished then
		return false, "match is finished"
	end
	local shooter = self:roles()
	if side == shooter then
		if not Shot.isValid(choice) then
			return false, "invalid shot"
		end
		self._shot = { column = choice.column, height = choice.height, power = choice.power }
	else
		if not Shot.isValidDive(choice) then
			return false, "invalid dive"
		end
		self._dive = { column = choice.column, height = choice.height }
	end
	return true
end

function Duel.hasChosen(self: Duel, side: Match.Side): boolean
	local shooter = self:roles()
	return if side == shooter then self._shot ~= nil else self._dive ~= nil
end

function Duel.isReady(self: Duel): boolean
	return self._shot ~= nil and self._dive ~= nil
end

-- Resolves the kick, using the config defaults for any missing choice.
function Duel.resolve(self: Duel): KickResult
	assert(not self._match:getState().finished, "match is finished")
	local shooter, keeper = self:roles()
	local shot = self._shot or table.clone(config.defaultShot) :: Shot.Shot
	local dive = self._dive or table.clone(config.defaultDive) :: Shot.Dive
	local defaulted = { shot = self._shot == nil, dive = self._dive == nil }
	self._shot, self._dive = nil, nil

	local outcome = Shot.resolve(shot, dive, self._rng)
	local state = self._match:recordKick(outcome)
	local result: KickResult = {
		side = shooter,
		keeper = keeper,
		shot = shot,
		dive = dive,
		defaulted = defaulted,
		outcome = outcome,
		state = state,
	}
	table.insert(self._history, result)
	if state.finished then
		result.summary = self:summary()
	end
	return result
end

function Duel.forfeit(self: Duel, side: Match.Side): Summary.Summary
	self._match:forfeit(side)
	self._shot, self._dive = nil, nil
	return self:summary()
end

function Duel.summary(self: Duel): Summary.Summary
	return Summary.build(self._history, self._match:getState().winner)
end

function Duel.getHistory(self: Duel): { KickResult }
	return table.clone(self._history)
end

return Duel
