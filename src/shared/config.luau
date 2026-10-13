-- Every tuning number for the penalty shootout. See docs/design.md for meanings.

export type Shooter = { name: string, description: string, accuracy: number, strength: number }
export type Keeper = { name: string, description: string, reach: number, reaction: number }

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

	-- World and timing (studs / seconds). Goal line is at z = 0, shooter at +z.
	goalWidth = 24,
	goalHeight = 8,
	penaltyDistance = 36,
	ballFlightTime = 0.6,
	keeperDiveTime = 0.45,
	resultHoldTime = 1.4,
	aiKickDelay = 2.5,
	powerBarCyclesPerSecond = 0.8,

	-- Mesh models built by assets/source/build_models.py and uploaded with
	-- scripts/upload.luau. Owned by the game's creator so the server can load them.
	assetIds = {
		Ball = 93558228140246,
		Goal = 93200732902848,
		Keeper = 103543688356323,
	},

	shooters = {
		{ name = "Striker", description = "Hits it hard, sometimes too hard.", accuracy = 60, strength = 85 },
		{ name = "Playmaker", description = "Places it neatly, rarely misses.", accuracy = 85, strength = 55 },
	} :: { Shooter },

	keepers = {
		{ name = "Wall", description = "Huge reach, slow to read the shot.", reach = 85, reaction = 55 },
		{ name = "Cat", description = "Reads the shooter, shorter reach.", reach = 60, reaction = 85 },
	} :: { Keeper },
}

return config
