-- Resolves a single penalty kick. Pure logic; all numbers come from config.

local Rng = require("./Rng")
local config = require("../config")

export type Column = "left" | "centre" | "right"
export type Height = "high" | "low"
export type Shot = { column: Column, height: Height, power: number }
export type Outcome = "GOAL" | "SAVED" | "MISSED" | "POST"

local COLUMNS: { Column } = { "left", "centre", "right" }

local Shot = {}
Shot.COLUMNS = COLUMNS

local function clamp(x: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, x))
end

function Shot.strengthFactor(strength: number): number
	local t = (clamp(strength, 1, 100) - 1) / 99
	return config.strengthFactorMin + t * (config.strengthFactorMax - config.strengthFactorMin)
end

function Shot.effectivePower(shotPower: number, strength: number): number
	return clamp(shotPower, 0, 100) * Shot.strengthFactor(strength)
end

function Shot.missChance(effectivePower: number, accuracy: number, height: Height): number
	local overPower = math.max(0, effectivePower - config.missPowerThreshold)
	local accuracyScale = 1 - clamp(accuracy, 0, 100) / 100 * config.missAccuracyReduction
	local chance = config.missBase + overPower * config.missPerPower * accuracyScale
	if height == "high" then
		chance += config.missHighAimBonus
	end
	return clamp(chance, 0, 1)
end

function Shot.guessChance(reaction: number): number
	return clamp(config.guessBase + clamp(reaction, 0, 100) * config.guessPerReaction, 0, 1)
end

function Shot.saveChance(reach: number, effectivePower: number): number
	local chance = config.saveBase + clamp(reach, 0, 100) * config.savePerReach - effectivePower * config.savePerPower
	return clamp(chance, config.saveMin, config.saveMax)
end

function Shot.isValid(shot: any): boolean
	return type(shot) == "table"
		and table.find(COLUMNS, shot.column) ~= nil
		and (shot.height == "high" or shot.height == "low")
		and type(shot.power) == "number"
		and shot.power >= 0
		and shot.power <= 100
end

-- Returns the outcome and the column the keeper dived to.
function Shot.resolveShot(shot: Shot, shooter: config.Shooter, keeper: config.Keeper, rng: Rng.Rng): (Outcome, Column)
	assert(Shot.isValid(shot), "invalid shot")
	local power = Shot.effectivePower(shot.power, shooter.strength)

	-- Draw order is fixed so the same seed always gives the same result.
	local missRoll, postRoll, guessRoll, sideRoll, saveRoll = rng:next(), rng:next(), rng:next(), rng:next(), rng:next()

	local dive: Column = shot.column
	if guessRoll >= Shot.guessChance(keeper.reaction) then
		local others = {}
		for _, c in COLUMNS do
			if c ~= shot.column then
				table.insert(others, c)
			end
		end
		dive = others[1 + math.floor(sideRoll * #others)]
	end

	if missRoll < Shot.missChance(power, shooter.accuracy, shot.height) then
		return if postRoll < config.postShareOfMisses then "POST" else "MISSED", dive
	end
	if dive == shot.column and saveRoll < Shot.saveChance(keeper.reach, power) then
		return "SAVED", dive
	end
	return "GOAL", dive
end

return Shot
