-- Poses a player's R15 avatar from code (no animation assets). Each action is
-- a track: a chain of poses that blend into each other, and the last pose
-- keeps animating (idle bounce, celebration) instead of freezing.
--   stand / keep : relaxed stand, keeper ready stance
--   kick         : run-up, strike, plant the leg, react to the outcome
--   dive         : dive, land on the ground, get up to the knees, react
-- Arms aim at world points so the keeper's gloves go for the dive spot.
--
-- Runs on every client for every avatar; the server only places the avatars.
-- R15 joint frames line up with the body: forward is -Z, up +Y, right +X.
-- Joints may be classic Motor6Ds or the newer AnimationConstraints; both
-- have a Transform, and frames() gives their two joint frames.

local RunService = game:GetService("RunService")

local config = require(game:GetService("ReplicatedStorage").Shared.config)

local rad = math.rad
local function angles(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end

local SIDES = { Left = -1, Right = 1 }
local DIVE_REACH = 2.9 -- root to hands at full stretch
local HAND_SPREAD = 0.35
local LYING_HEIGHT = 1.0 -- root height when lying on the side
local KNEEL_DROP = 1.15 -- how much lower the root is when kneeling
local SNAP_DISTANCE = 12 -- farther than this, a new spot is jumped to, not blended

export type Pose = {
	root: CFrame, -- HumanoidRootPart world CFrame
	joints: { [string]: CFrame }, -- joint name -> Transform
	hands: { [string]: Vector3 }, -- Left/Right -> world point the arm aims at
}

-- One step of a track. `pose` is a fixed pose or a function of the time
-- spent in this step. The step blends in from the previous one over `blend`.
type Step = { pose: Pose | (t: number) -> Pose, blend: number, duration: number }

local AvatarRig = {}
AvatarRig.__index = AvatarRig

local function isJoint(d: Instance): boolean
	return d:IsA("Motor6D") or d:IsA("AnimationConstraint")
end

-- The joint's frame on each part (C0/C1 for a Motor6D, the attachments' frames
-- for an AnimationConstraint).
local function frames(joint: any): (CFrame, CFrame)
	if joint:IsA("Motor6D") then
		return joint.C0, joint.C1
	end
	local a0, a1 = joint.Attachment0, joint.Attachment1
	return if a0 then a0.CFrame else CFrame.identity, if a1 then a1.CFrame else CFrame.identity
end

-- Rotation taking unit vector u onto unit vector w.
local function between(u: Vector3, w: Vector3): CFrame
	local axis = u:Cross(w)
	local dot = math.clamp(u:Dot(w), -1, 1)
	if axis.Magnitude < 1e-6 then
		if dot > 0 then
			return CFrame.identity
		end
		return CFrame.fromAxisAngle(Vector3.xAxis, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerpPose(a: Pose, b: Pose, alpha: number, handAlpha: number?): Pose
	local out: Pose = { root = a.root:Lerp(b.root, alpha), joints = {}, hands = {} }
	for name, cf in a.joints do
		out.joints[name] = cf:Lerp(b.joints[name] or CFrame.new(), alpha)
	end
	for name, cf in b.joints do
		if not out.joints[name] then
			out.joints[name] = CFrame.new():Lerp(cf, alpha)
		end
	end
	for side in SIDES do
		out.hands[side] = a.hands[side]:Lerp(b.hands[side], handAlpha or alpha)
	end
	return out
end

local function evaluate(step: Step, t: number): Pose
	local pose = step.pose
	if type(pose) == "function" then
		return pose(t)
	end
	return pose :: Pose
end

function AvatarRig.new(character: Model)
	local self = setmetatable({}, AvatarRig)
	self.character = character
	self.root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	self.motors = {}
	for _, d in character:GetDescendants() do
		if isJoint(d) then
			self.motors[d.Name] = d
		end
	end
	-- Parts can stream in after the root part; pick up their joints as they arrive.
	self.added = character.DescendantAdded:Connect(function(d)
		if isJoint(d) then
			self.motors[d.Name] = d
		end
	end)
	self.home = if self.root then self.root.CFrame else CFrame.identity
	self.clock = 0
	self.speed = 1 -- below 1 plays everything in slow motion
	self.standY = self.home.Position.Y -- root height when standing
	self.current = nil :: Pose?
	self:_play({
		{
			pose = function()
				return self:_standPose(self.home)
			end,
			blend = 0,
			duration = math.huge,
		},
	})
	-- PreSimulation runs after the Animator, so these joint transforms are the
	-- ones that get rendered instead of being reset each frame.
	self.connection = RunService.PreSimulation:Connect(function(dt)
		self:_step(dt)
	end)
	return self
end

function AvatarRig:destroy()
	self.connection:Disconnect()
	self.added:Disconnect()
	for _, motor in self.motors do
		motor.Transform = CFrame.identity
	end
end

-- Tracks ---------------------------------------------------------------------

function AvatarRig:_play(track: { Step })
	self.speed = 1 -- a new action always plays at normal speed
	self.track = track
	self.trackTime = 0
	self.trackFrom = self.current
end

-- Blend time to reach `home`: a short glide nearby, a jump when far away.
function AvatarRig:_blendTo(home: CFrame, slow: number): number
	if not self.current or (self.current.root.Position - home.Position).Magnitude > SNAP_DISTANCE then
		return 0
	end
	return slow
end

function AvatarRig:stand(home: CFrame)
	self.home = home
	self.standY = home.Position.Y
	self:_play({
		{
			pose = function()
				return self:_standPose(home)
			end,
			blend = self:_blendTo(home, 0.5),
			duration = math.huge,
		},
	})
end

function AvatarRig:keep(home: CFrame)
	self.home = home
	self.standY = home.Position.Y
	self:_play({
		{
			pose = function()
				return self:_keepPose(home)
			end,
			blend = self:_blendTo(home, 0.6),
			duration = math.huge,
		},
	})
end

-- Stand in a line with arms over the neighbours' shoulders, swaying with the
-- rest of the team. towardX/awayX are the neighbours' x positions (nil at an end).
function AvatarRig:huddle(home: CFrame, towardX: number?, awayX: number?)
	self.home = home
	self.standY = home.Position.Y
	self:_play({
		{
			pose = function()
				return self:_huddlePose(home, towardX, awayX)
			end,
			blend = 0,
			duration = math.huge,
		},
	})
end

-- Upright frame where the avatar is now (even if lying down), facing the
-- same way horizontally.
function AvatarRig:_uprightHere(): CFrame
	local now = if self.current then self.current.root else self.home
	local look = now.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		flat = self.home.LookVector
	end
	local p = Vector3.new(now.Position.X, self.standY, now.Position.Z)
	return CFrame.lookAt(p, p + flat)
end

-- Sprint from wherever the avatar is to `target`, then celebrate there.
function AvatarRig:runTo(target: CFrame, duration: number)
	local start = self:_uprightHere()
	-- Face the direction of travel while running.
	local flat = Vector3.new(target.Position.X, start.Position.Y, target.Position.Z)
	local heading = if (flat - start.Position).Magnitude > 0.1 then CFrame.lookAt(start.Position, flat) else start
	local from = CFrame.new(start.Position) * heading.Rotation
	local to = CFrame.new(target.Position) * heading.Rotation
	self.home = target
	self:_play({
		{
			pose = function(t)
				return self:_runPose(from, to, math.clamp(t / duration, 0, 1))
			end,
			blend = 0.2,
			duration = duration,
		},
		{
			pose = function(t)
				return self:_celebratePose(target, t)
			end,
			blend = 0.4,
			duration = math.huge,
		},
	})
end

function AvatarRig:celebrate(at: CFrame)
	self.home = at
	self:_play({
		{
			pose = function(t)
				return self:_celebratePose(at, t)
			end,
			blend = 0.3,
			duration = math.huge,
		},
	})
end

-- Sink to the knees, then fall face down on the pitch and stay there.
function AvatarRig:collapse()
	local facing = self:_uprightHere()
	local start = facing
	local kneel = self:_kneelReaction(facing, start.Position.X, false, 0)
	self:_play({
		{
			pose = function(t)
				local pose = self:_kneelReaction(facing, start.Position.X, false, t)
				pose.root = kneel.root
				return pose
			end,
			blend = 0.6,
			duration = 1.2,
		},
		{ pose = self:_pronePose(facing), blend = 0.7, duration = math.huge },
	})
end

-- Run up from home, strike the ball at `strike`, then react once the ball
-- arrives. `scored` is whether the kick went in.
function AvatarRig:kick(strike: CFrame, scored: boolean)
	local start = self.home
	self:_play({
		{
			pose = function(t)
				return self:_kickPose(start, strike, t / config.runUpTime)
			end,
			blend = 0.1,
			duration = config.runUpTime,
		},
		{
			pose = function()
				return self:_standPose(strike)
			end,
			blend = 0.3,
			duration = config.ballFlightTime,
		},
		{
			pose = function(t)
				return if scored then self:_celebratePose(strike, t) else self:_despairPose(strike, t)
			end,
			blend = 0.3,
			duration = math.huge,
		},
	})
end

-- Dive towards `reach` (world point at the dive height) for column/height,
-- then land, get up and react. `saved` is whether the keeper stopped it.
function AvatarRig:dive(reach: Vector3, column: string, height: string, saved: boolean)
	local home = self.home
	local from = self:_keepPose(home)
	local target = self:_divePose(reach, column, height)
	local arc = if column == "centre" then 0 else 0.8
	local diveTime = config.keeperDiveTime
	local track: { Step } = {
		{
			pose = function(t)
				local u = math.clamp(t / diveTime, 0, 1)
				local pose = lerpPose(from, target, 1 - (1 - u) * (1 - u), math.sqrt(u))
				pose.root += Vector3.yAxis * (arc * math.sin(math.pi * u))
				return pose
			end,
			blend = 0.05,
			duration = diveTime,
		},
	}
	if column == "centre" then
		-- Land on the feet (or rise from the block), then react standing up.
		table.insert(track, { pose = target, blend = 0, duration = 0.35 })
		table.insert(track, {
			pose = function(t)
				return self:_standReaction(home, saved, t)
			end,
			blend = 0.45,
			duration = math.huge,
		})
	else
		local towards = if column == "left" then -1 else 1
		local lieAt = Vector3.new(target.root.Position.X + towards * 0.6, LYING_HEIGHT, home.Position.Z)
		table.insert(track, { pose = self:_lyingPose(lieAt, towards, reach), blend = 0.3, duration = 0.7 })
		table.insert(track, {
			pose = function(t)
				return self:_kneelReaction(home, lieAt.X - towards * 1.2, saved, t)
			end,
			blend = 0.5,
			duration = math.huge,
		})
	end
	self:_play(track)
end

-- Poses ----------------------------------------------------------------------

function AvatarRig:_standPose(at: CFrame): Pose
	local sway = 0.03 * math.sin(self.clock * 1.7)
	local pose: Pose = { root = at * CFrame.new(0, sway, 0), joints = {}, hands = {} }
	for side, s in SIDES do
		pose.hands[side] = at * Vector3.new(s * 1.3, -2.1, -0.15)
		pose.joints[side .. "Elbow"] = angles(15)
	end
	return pose
end

function AvatarRig:_keepPose(home: CFrame): Pose
	local t = self.clock
	local bounce = 0.05 * math.sin(t * math.pi * 2 * 1.6)
	local sway = 0.12 * math.sin(t * 1.4)
	local pose: Pose = {
		root = home * CFrame.new(sway, -0.45 + bounce, 0) * angles(0, 0, -sway * 8),
		joints = { Waist = angles(-14, 0, sway * 10), Neck = angles(12) },
		hands = {},
	}
	for side, s in SIDES do
		pose.joints[side .. "Hip"] = angles(38) * angles(0, 0, s * 7)
		pose.joints[side .. "Knee"] = angles(-72)
		pose.joints[side .. "Ankle"] = angles(32)
		pose.joints[side .. "Elbow"] = angles(45)
		local wave = 0.08 * math.sin(t * 2.3 + s)
		pose.hands[side] = home * Vector3.new(s * 1.45, -0.5 + wave, -1.3)
	end
	return pose
end

function AvatarRig:_divePose(reach: Vector3, column: string, height: string): Pose
	local home = self.home
	local look, right = home.LookVector, home.RightVector
	local pose: Pose = { joints = {}, hands = {} } :: any

	if column == "centre" then
		if height == "high" then
			-- Jump straight up, both hands overhead.
			local lift = math.max(0, reach.Y - (home.Position.Y + DIVE_REACH))
			pose.root = home + Vector3.yAxis * lift
			pose.joints.Neck = angles(18)
			for side in SIDES do
				pose.joints[side .. "Hip"] = angles(25)
				pose.joints[side .. "Knee"] = angles(-50)
				pose.joints[side .. "Elbow"] = angles(10)
			end
			for side, s in SIDES do
				pose.hands[side] = reach + right * (s * HAND_SPREAD) + look * 0.6
			end
		else
			-- Low block: deep crouch, hands down by the ball in front.
			pose.root = home * CFrame.new(0, -1.1, 0)
			pose.joints.Waist = angles(-32)
			pose.joints.Neck = angles(25)
			for side, s in SIDES do
				pose.joints[side .. "Hip"] = angles(75) * angles(0, 0, s * 18)
				pose.joints[side .. "Knee"] = angles(-110)
				pose.joints[side .. "Ankle"] = angles(35)
				pose.joints[side .. "Elbow"] = angles(15)
				pose.hands[side] = Vector3.new(reach.X, 1.0, reach.Z) + look * 1.8 + right * (s * HAND_SPREAD)
			end
		end
		return pose
	end

	-- Side dive: body laid out flat towards the ball, arms at full stretch.
	local towards = if column == "left" then -1 else 1 -- world X direction
	local up = Vector3.new(towards * math.sin(rad(80)), math.cos(rad(80)), 0)
	local back = -look
	local bodyRight = up:Cross(back)
	local pos = reach - up * DIVE_REACH
	pos = Vector3.new(pos.X, math.max(pos.Y, LYING_HEIGHT), pos.Z)
	pose.root = CFrame.fromMatrix(pos, bodyRight, up, back)
	pose.joints.Neck = angles(10, 0, -towards * 10)
	-- The leg on the upper side tucks; the lower leg stays long.
	local upperSide = if bodyRight.Y > 0 then "Right" else "Left"
	for side, s in SIDES do
		if side == upperSide then
			pose.joints[side .. "Hip"] = angles(45)
			pose.joints[side .. "Knee"] = angles(-80)
		else
			pose.joints[side .. "Hip"] = angles(5)
			pose.joints[side .. "Knee"] = angles(-10)
		end
		pose.joints[side .. "Elbow"] = angles(10)
		pose.hands[side] = reach + bodyRight * (s * HAND_SPREAD) + look * 0.6
	end
	return pose
end

-- Lying on the side on the ground after a dive, arms still out towards the ball.
function AvatarRig:_lyingPose(at: Vector3, towards: number, reach: Vector3): Pose
	local look = self.home.LookVector
	local up = Vector3.new(towards, 0.02, 0).Unit
	local back = -look
	local bodyRight = up:Cross(back)
	local pose: Pose = {
		root = CFrame.fromMatrix(at, bodyRight, up, back),
		joints = { Neck = angles(15, 0, -towards * 15) },
		hands = {},
	}
	local upperSide = if bodyRight.Y > 0 then "Right" else "Left"
	local ground = Vector3.new(reach.X + towards * 0.4, 0.6, at.Z)
	for side, s in SIDES do
		pose.joints[side .. "Hip"] = if side == upperSide then angles(35) else angles(5)
		pose.joints[side .. "Knee"] = if side == upperSide then angles(-60) else angles(-15)
		pose.joints[side .. "Elbow"] = angles(20)
		pose.hands[side] = ground + look * (0.6 + 0.4 * s)
	end
	return pose
end

-- Up on the knees where the keeper landed: fist pump after a save, head
-- down and hands on the turf after a goal.
function AvatarRig:_kneelReaction(home: CFrame, x: number, saved: boolean, t: number): Pose
	local base = CFrame.new(x, home.Position.Y - KNEEL_DROP, home.Position.Z) * home.Rotation
	local pose: Pose = { root = base, joints = {}, hands = {} }
	for side, s in SIDES do
		pose.joints[side .. "Hip"] = angles(8) * angles(0, 0, s * 6)
		pose.joints[side .. "Knee"] = angles(-95)
		pose.joints[side .. "Ankle"] = angles(30)
	end
	if saved then
		local pump = 0.35 * math.abs(math.sin(t * 6))
		pose.joints.Neck = angles(20)
		pose.joints.Waist = angles(5)
		pose.joints.RightElbow = angles(40)
		pose.joints.LeftElbow = angles(30)
		pose.hands.Right = base * Vector3.new(1.0, 2.4 + pump, -0.4)
		pose.hands.Left = base * Vector3.new(-1.4, -0.6, -0.6)
	else
		local sigh = 0.05 * math.sin(t * 1.5)
		pose.root = base * CFrame.new(0, sigh, 0)
		pose.joints.Neck = angles(-35)
		pose.joints.Waist = angles(-28)
		for side, s in SIDES do
			pose.joints[side .. "Elbow"] = angles(15)
			pose.hands[side] = base * Vector3.new(s * 0.8, -1.4, -1.5)
		end
	end
	return pose
end

-- Standing reaction for centre dives: fist pump after a save, hands on head
-- after a goal.
function AvatarRig:_standReaction(home: CFrame, saved: boolean, t: number): Pose
	if saved then
		local pose = self:_standPose(home)
		local pump = 0.35 * math.abs(math.sin(t * 6))
		pose.joints.Neck = angles(20)
		pose.joints.RightElbow = angles(40)
		pose.hands.Right = home * Vector3.new(1.0, 2.4 + pump, -0.4)
		return pose
	end
	return self:_despairPose(home, t)
end

function AvatarRig:_huddlePose(home: CFrame, towardX: number?, awayX: number?): Pose
	-- os.clock keeps the whole team swaying in time.
	local sway = math.sin(os.clock() * 1.3)
	local pose = self:_standPose(home * CFrame.Angles(0, 0, math.rad(3) * sway))
	local x, y, z = home.Position.X, home.Position.Y, home.Position.Z
	for _, neighbourX in { towardX, awayX } do
		if neighbourX then
			local dir = if neighbourX > x then 1 else -1
			-- Facing -Z, the body's right is +X.
			local side = if dir > 0 then "Right" else "Left"
			pose.hands[side] = Vector3.new(neighbourX + dir * 0.7, y + 1.3, z + 0.35)
			pose.joints[side .. "Elbow"] = angles(20)
		end
	end
	return pose
end

-- Running from `from` to `to` (u = 0..1) with arms pumping.
function AvatarRig:_runPose(from: CFrame, to: CFrame, u: number): Pose
	local stride = math.sin(self.clock * 14)
	local root = from:Lerp(to, u) + Vector3.yAxis * (0.15 * math.abs(stride))
	local pose: Pose = { root = root, joints = { Waist = angles(-12), Neck = angles(8) }, hands = {} }
	for side, s in SIDES do
		local swing = stride * s
		pose.joints[side .. "Hip"] = angles(45 * swing)
		pose.joints[side .. "Knee"] = angles(-30 - 50 * math.max(0, -swing))
		pose.joints[side .. "Elbow"] = angles(80)
		pose.hands[side] = root * Vector3.new(s * 1.1, -0.9, 1.0 * swing)
	end
	return pose
end

-- Face down on the pitch, arms out past the head.
function AvatarRig:_pronePose(facing: CFrame): Pose
	local forward = facing.LookVector
	local flatForward = Vector3.new(forward.X, 0, forward.Z).Unit
	local pos = Vector3.new(facing.Position.X, 0.6, facing.Position.Z) + flatForward * 1.5
	local right = flatForward:Cross(Vector3.yAxis)
	-- Head points along flatForward, back faces the sky.
	local root = CFrame.fromMatrix(pos, right, flatForward, Vector3.yAxis)
	local pose: Pose = { root = root, joints = { Neck = angles(-20) }, hands = {} }
	for side, s in SIDES do
		pose.joints[side .. "Elbow"] = angles(25)
		pose.joints[side .. "Hip"] = angles(5)
		pose.hands[side] = pos + flatForward * 2.6 + right * (s * 1.0) + Vector3.yAxis * -0.3
	end
	return pose
end

-- Arms up and bouncing on the spot.
function AvatarRig:_celebratePose(at: CFrame, t: number): Pose
	local hop = 0.3 * math.abs(math.sin(t * 7))
	local pose: Pose = {
		root = at * CFrame.new(0, hop, 0),
		joints = { Neck = angles(20), Waist = angles(6) },
		hands = {},
	}
	for side, s in SIDES do
		pose.joints[side .. "Elbow"] = angles(15)
		pose.joints[side .. "Knee"] = angles(-25 * hop / 0.3)
		pose.joints[side .. "Hip"] = angles(12 * hop / 0.3)
		pose.hands[side] = at * Vector3.new(s * 1.4, 3.4 + 0.2 * math.sin(t * 7 + s), -0.3)
	end
	return pose
end

-- Hands on head, leaning back a little, swaying.
function AvatarRig:_despairPose(at: CFrame, t: number): Pose
	local sway = 0.06 * math.sin(t * 1.8)
	local pose: Pose = {
		root = at * angles(0, 0, sway * 20),
		joints = { Neck = angles(-12), Waist = angles(10) },
		hands = {},
	}
	for side, s in SIDES do
		pose.joints[side .. "Elbow"] = angles(120)
		pose.hands[side] = at * Vector3.new(s * 1.6, 2.6, 0.3)
	end
	return pose
end

function AvatarRig:_kickPose(start: CFrame, strike: CFrame, t: number): Pose
	t = math.clamp(t, 0, 1)
	local pose: Pose = { joints = {}, hands = {} } :: any
	local RUN = 0.75 -- share of the time spent running in
	if t < RUN then
		local u = t / RUN
		local stride = math.sin(u * math.pi * 2 * 2.5)
		pose.root = start:Lerp(strike, u) + Vector3.yAxis * (0.12 * math.abs(stride))
		pose.joints.Waist = angles(-8)
		for side, s in SIDES do
			local swing = stride * s
			pose.joints[side .. "Hip"] = angles(32 * swing)
			pose.joints[side .. "Knee"] = angles(-25 - 30 * math.max(0, -swing))
			pose.joints[side .. "Elbow"] = angles(60)
			pose.hands[side] = pose.root * Vector3.new(s * 1.2, -1.5, 0.8 * swing)
		end
	else
		-- Plant the left foot, swing the right leg through the ball.
		local u = (t - RUN) / (1 - RUN)
		local strikeU = math.sin(u * math.pi / 2)
		pose.root = strike
		pose.joints.Waist = angles(8, 0, -5)
		pose.joints.LeftHip = angles(10)
		pose.joints.LeftKnee = angles(-20)
		pose.joints.RightHip = angles(-45 + 120 * strikeU)
		pose.joints.RightKnee = angles(-95 + 85 * strikeU)
		pose.joints.RightAnkle = angles(-20)
		for side, s in SIDES do
			pose.joints[side .. "Elbow"] = angles(25)
			pose.hands[side] = strike * Vector3.new(s * 2.2, -0.6, 0.2)
		end
	end
	return pose
end

-- Evaluates the track at its current time, blending between steps.
function AvatarRig:_pose(): Pose
	local track = self.track
	local t = self.trackTime
	local previous: Pose? = self.trackFrom
	for i, step in track do
		local isLast = i == #track
		if t < step.duration or isLast then
			local pose = evaluate(step, t)
			if previous and step.blend > 0 and t < step.blend then
				pose = lerpPose(previous, pose, smooth(t / step.blend))
			end
			return pose
		end
		previous = evaluate(step, step.duration)
		t -= step.duration
	end
	return self:_standPose(self.home)
end

-- Applying -------------------------------------------------------------------

function AvatarRig:_step(dt: number)
	dt *= self.speed
	self.clock += dt
	self.trackTime += dt
	if self.root and self.root.Parent then
		local pose = self:_pose()
		self.current = pose
		self:_apply(pose)
	end
end

-- Aims a shoulder so its arm points at `target`, given the torso's world CFrame.
function AvatarRig:_aimArm(side: string, upperTorso: CFrame, target: Vector3): CFrame
	local shoulder = self.motors[side .. "Shoulder"]
	local elbow = self.motors[side .. "Elbow"]
	if not shoulder or not elbow then
		return CFrame.identity
	end
	local shoulderC0, shoulderC1 = frames(shoulder)
	local elbowC0 = frames(elbow)
	local joint = upperTorso * shoulderC0
	-- Direction from shoulder to elbow in the upper arm's own space, at rest.
	local restArm = shoulderC1:VectorToObjectSpace(elbowC0.Position - shoulderC1.Position)
	local wanted = joint:VectorToObjectSpace(target - joint.Position)
	if wanted.Magnitude < 1e-3 or restArm.Magnitude < 1e-3 then
		return CFrame.identity
	end
	return between(restArm.Unit, wanted.Unit)
end

function AvatarRig:_apply(pose: Pose)
	local motors = self.motors
	self.root.CFrame = pose.root
	for name, motor in motors do
		motor.Transform = pose.joints[name] or CFrame.identity
	end
	local rootJoint, waist = motors.Root, motors.Waist
	if not (rootJoint and waist) then
		return -- not R15: position only
	end
	local rootC0, rootC1 = frames(rootJoint)
	local waistC0, waistC1 = frames(waist)
	local lowerTorso = pose.root * rootC0 * rootJoint.Transform * rootC1:Inverse()
	local upperTorso = lowerTorso * waistC0 * waist.Transform * waistC1:Inverse()
	for side in SIDES do
		local shoulder = motors[side .. "Shoulder"]
		if shoulder then
			shoulder.Transform = self:_aimArm(side, upperTorso, pose.hands[side])
		end
	end
end

return AvatarRig
