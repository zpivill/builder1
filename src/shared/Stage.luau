-- Where things stand on the pitch. Used by the server to place avatars and by
-- clients to pose them, so both agree. Goal line at z = 0, shooter at +z.

local config = require("./config")

local Stage = {}

Stage.BALL_RADIUS = 0.7
Stage.BALL_SPOT = Vector3.new(0, Stage.BALL_RADIUS, config.penaltyDistance)
Stage.KEEPER_Z = 1.5

-- Height of the HumanoidRootPart centre above the ground for a character.
function Stage.rootHeight(character: Model): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return 3
end

-- Keeper on the goal line, facing the shooter (+Z).
function Stage.keeperHome(character: Model): CFrame
	local y = Stage.rootHeight(character)
	return CFrame.lookAt(Vector3.new(0, y, Stage.KEEPER_Z), Vector3.new(0, y, Stage.KEEPER_Z + 1))
end

-- Shooter a few steps behind the ball and to its left (right-footed), facing the goal.
function Stage.shooterHome(character: Model): CFrame
	local y = Stage.rootHeight(character)
	local p = Vector3.new(-1.6, y, config.penaltyDistance + 4.5)
	return CFrame.lookAt(p, p - Vector3.zAxis)
end

-- Where the shooter plants their standing foot to strike the ball.
function Stage.shooterStrike(character: Model): CFrame
	local y = Stage.rootHeight(character)
	local p = Vector3.new(-0.9, y, config.penaltyDistance + 1.1)
	return CFrame.lookAt(p, p - Vector3.zAxis)
end

-- Off to the side of the pitch while waiting for a match.
function Stage.waitingSpot(character: Model, index: number): CFrame
	local y = Stage.rootHeight(character)
	local p = Vector3.new(18 + index * 4, y, config.penaltyDistance - 6)
	return CFrame.lookAt(p, Vector3.new(0, y, 12))
end

return Stage
