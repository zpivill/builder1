-- Where the ball ends up for a resolved kick, as (x, y) on the goal plane.
-- x = 0 is the goal centre (negative = shooter's left), y = 0 is the ground.

local Shot = require("./Shot")
local config = require("../config")

local ShotPath = {}

local COLUMN_X = { left = -1 / 3, centre = 0, right = 1 / 3 }
local HEIGHT_Y = { low = 0.25, high = 0.75 }
local MISS_MARGIN = 3

function ShotPath.aimPoint(column: Shot.Column, height: Shot.Height): (number, number)
	return COLUMN_X[column] * config.goalWidth, HEIGHT_Y[height] * config.goalHeight
end

function ShotPath.diveX(column: Shot.Column): number
	return COLUMN_X[column] * config.goalWidth
end

function ShotPath.target(shot: Shot.Shot, outcome: Shot.Outcome): (number, number)
	local x, y = ShotPath.aimPoint(shot.column, shot.height)
	local halfWidth = config.goalWidth / 2
	local sideSign = if shot.column == "left" then -1 else 1

	if outcome == "MISSED" then
		if shot.height == "high" or shot.column == "centre" then
			return x, config.goalHeight + MISS_MARGIN
		end
		return sideSign * (halfWidth + MISS_MARGIN), y
	elseif outcome == "POST" then
		if shot.column == "centre" then
			return x, config.goalHeight
		end
		return sideSign * halfWidth, y
	end
	return x, y
end

return ShotPath
