-- Picks the AI's shot: random aim, power from the config range.

local Rng = require("./Rng")
local Shot = require("./Shot")
local config = require("../config")

local AiShooter = {}

function AiShooter.pickShot(rng: Rng.Rng): Shot.Shot
	return {
		column = Shot.COLUMNS[rng:int(1, #Shot.COLUMNS)],
		height = if rng:next() < 0.5 then "high" else "low",
		power = rng:int(config.aiPowerMin, config.aiPowerMax),
	}
end

return AiShooter
