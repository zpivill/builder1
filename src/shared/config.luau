-- Every tuning number for the penalty shootout. See docs/design.md for meanings.

export type Shooter = { name: string, accuracy: number, strength: number }
export type Keeper = { name: string, reach: number, reaction: number }

local config = {
	rounds = 5,

	-- effectivePower = shotPower * strengthFactor(strength)
	strengthFactorMin = 0.7,
	strengthFactorMax = 1.3,

	missBase = 0.03,
	missPowerThreshold = 50,
	missPerPower = 0.006,
	missAccuracyReduction = 0.6,
	missHighAimBonus = 0.05,
	postShareOfMisses = 0.25,

	guessBase = 0.33,
	guessPerReaction = 0.004,

	saveBase = 0.35,
	savePerReach = 0.005,
	savePerPower = 0.005,
	saveMin = 0.05,
	saveMax = 0.95,

	aiPowerMin = 55,
	aiPowerMax = 85,

	shooters = {
		{ name = "Striker", accuracy = 60, strength = 85 },
		{ name = "Playmaker", accuracy = 85, strength = 55 },
	} :: { Shooter },

	keepers = {
		{ name = "Wall", reach = 85, reaction = 55 },
		{ name = "Cat", reach = 60, reaction = 85 },
	} :: { Keeper },
}

return config
