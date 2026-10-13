-- One player's match against the AI: turn checks, kick resolution and the
-- AI's own kicks. Pure logic so the server script stays a thin wrapper.

local AiShooter = require("./AiShooter")
local Match = require("./Match")
local Rng = require("./Rng")
local Shot = require("./Shot")
local Summary = require("./Summary")
local config = require("../config")

export type KickResult = {
	side: Match.Side,
	shot: Shot.Shot,
	outcome: Shot.Outcome,
	dive: Shot.Column,
	state: Match.State,
	summary: Summary.Summary?, -- set on the kick that ends the match
}

export type Options = {
	seed: number,
	playerShooter: config.Shooter?,
	playerKeeper: config.Keeper?,
	aiShooter: config.Shooter?,
	aiKeeper: config.Keeper?,
}

export type Session = {
	playerKick: (self: Session, shot: any) -> (KickResult?, string?),
	aiKick: (self: Session) -> (KickResult?, string?),
	getState: (self: Session) -> Match.State,
	getHistory: (self: Session) -> { KickResult },
	_match: Match.Match,
	_rng: Rng.Rng,
	_playerShooter: config.Shooter,
	_playerKeeper: config.Keeper,
	_aiShooter: config.Shooter,
	_aiKeeper: config.Keeper,
	_history: { KickResult },
}

local Session = {}
Session.__index = Session

function Session.new(options: Options): Session
	local self = {
		_match = Match.new(),
		_rng = Rng.new(options.seed),
		_playerShooter = options.playerShooter or config.shooters[1],
		_playerKeeper = options.playerKeeper or config.keepers[1],
		_aiShooter = options.aiShooter or config.shooters[2],
		_aiKeeper = options.aiKeeper or config.keepers[2],
		_history = {},
	}
	return (setmetatable(self, Session) :: any) :: Session
end

function Session.getState(self: Session): Match.State
	return self._match:getState()
end

function Session.getHistory(self: Session): { KickResult }
	return table.clone(self._history)
end

local function kick(self: Session, side: Match.Side, shot: Shot.Shot): KickResult
	local shooter = if side == "player" then self._playerShooter else self._aiShooter
	local keeper = if side == "player" then self._aiKeeper else self._playerKeeper
	local outcome, dive = Shot.resolveShot(shot, shooter, keeper, self._rng)
	local state = self._match:recordKick(outcome)
	local result: KickResult = { side = side, shot = shot, outcome = outcome, dive = dive, state = state }
	table.insert(self._history, result)
	if state.finished then
		result.summary = Summary.build(self._history, state.winner)
	end
	return result
end

local function checkTurn(self: Session, side: Match.Side): string?
	local state = self._match:getState()
	if state.finished then
		return "match is finished"
	elseif state.nextSide ~= side then
		return "not your turn"
	end
	return nil
end

-- `shot` comes from the client, so it is validated and copied before use.
function Session.playerKick(self: Session, shot: any): (KickResult?, string?)
	local err = checkTurn(self, "player")
	if err then
		return nil, err
	end
	if not Shot.isValid(shot) then
		return nil, "invalid shot"
	end
	return kick(self, "player", { column = shot.column, height = shot.height, power = shot.power })
end

function Session.aiKick(self: Session): (KickResult?, string?)
	local err = checkTurn(self, "ai")
	if err then
		return nil, err
	end
	return kick(self, "ai", AiShooter.pickShot(self._rng))
end

return Session
