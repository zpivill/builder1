-- Every tuning number for the penalty shootout. See docs/design.md for meanings.

local config = {
	rounds = 5,

	-- Each kick: shooter and keeper choose at the same time, hidden, within
	-- this many seconds. Missing choices fall back to these defaults.
	choiceTime = 10,
	defaultShot = { column = "centre", height = "low", power = 50 },
	defaultDive = { column = "centre", height = "low" },

	-- Miss chance rises with power above the threshold; high aims miss more.
	missBase = 0.03,
	missPowerThreshold = 50,
	missPerPower = 0.003,
	missHighAimBonus = 0.05,
	postShareOfMisses = 0.25,

	-- Save chance when the keeper dives to the shot's column: exact zone, or
	-- right column but wrong height. Both drop with shot power. Wrong column = 0.
	saveExactBase = 0.9,
	saveExactPerPower = 0.003,
	saveColumnBase = 0.35,
	saveColumnPerPower = 0.002,
	saveMin = 0.05,
	saveMax = 0.95,

	-- World and timing (studs / seconds). Goal line is at z = 0, shooter at +z.
	goalWidth = 24,
	goalHeight = 8,
	penaltyDistance = 36,
	runUpTime = 0.7,
	ballFlightTime = 0.6,
	keeperDiveTime = 0.45,
	resultHoldTime = 1.6,
	powerBarCyclesPerSecond = 0.8,

	-- In Studio only, a bot fills the second slot so one person can test.
	studioBot = true,

	-- Mesh models built by assets/source/build_models.py and uploaded with
	-- scripts/upload.luau. Owned by the game's creator so the server can load them.
	assetIds = {
		Ball = 93558228140246,
		Goal = 93200732902848,
	},
}

return config
