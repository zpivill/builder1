-- Resolves a single penalty kick from the shooter's shot and the keeper's
-- dive. Pure logic; all numbers come from config.

local Rng = require("./Rng")
local config = require("../config")

export type Column = "left" | "centre" | "right"
export type Height = "high" | "low"
export type Shot = { column: Column, height: Height, power: number }
export type Dive = { column: Column, height: Height }
export type Outcome = "GOAL" | "SAVED" | "MISSED" | "POST"

local COLUMNS: { Column } = { "left", "centre", "right" }

local Shot = {}
Shot.COLUMNS = COLUMNS

local function clamp(x: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, x))
end

local function isZone(value: any): boolean
	return type(value) == "table"
		and table.find(COLUMNS, value.column) ~= nil
		and (value.height == "high" or value.height == "low")
end

function Shot.isValid(shot: any): boolean
	return isZone(shot) and type(shot.power) == "number" and shot.power >= 0 and shot.power <= 100
end

function Shot.isValidDive(dive: any): boolean
	return isZone(dive)
end

function Shot.missChance(power: number, height: Height): number
	local chance = config.missBase + math.max(0, power - config.missPowerThreshold) * config.missPerPower
	if height == "high" then
		chance += config.missHighAimBonus
	end
	return clamp(chance, 0, 1)
end

-- Chance an on-target shot is saved, given where the keeper dived.
function Shot.saveChance(shot: Shot, dive: Dive): number
	if dive.column ~= shot.column then
		return 0
	end
	local base, perPower
	if dive.height == shot.height then
		base, perPower = config.saveExactBase, config.saveExactPerPower
	else
		base, perPower = config.saveColumnBase, config.saveColumnPerPower
	end
	return clamp(base - shot.power * perPower, config.saveMin, config.saveMax)
end

function Shot.resolve(shot: Shot, dive: Dive, rng: Rng.Rng): Outcome
	assert(Shot.isValid(shot), "invalid shot")
	assert(Shot.isValidDive(dive), "invalid dive")
	-- Draw order is fixed so the same seed always gives the same result.
	local missRoll, postRoll, saveRoll = rng:next(), rng:next(), rng:next()
	if missRoll < Shot.missChance(shot.power, shot.height) then
		return if postRoll < config.postShareOfMisses then "POST" else "MISSED"
	end
	if saveRoll < Shot.saveChance(shot, dive) then
		return "SAVED"
	end
	return "GOAL"
end

return Shot
