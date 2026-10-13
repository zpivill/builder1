-- Poses a player's R15 avatar from code (no animation assets): a keeper ready
-- stance and dives, a shooter run-up and kick, and a relaxed stand. Arms aim
-- at world points so the keeper's gloves go for the dive spot.
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

export type Pose = {
	root: CFrame, -- HumanoidRootPart world CFrame
	joints: { [string]: CFrame }, -- Motor6D name -> Transform
	hands: { [string]: Vector3 }, -- Left/Right -> world point the arm aims at
}

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

local function lerpPose(a: Pose, b: Pose, alpha: number, handAlpha: number): Pose
	local out: Pose = { root = a.root:Lerp(b.root, alpha), joints = {}, hands = {} }
	for name, cf in a.joints do
		out.joints[name] = cf:Lerp(b.joints[name] or CFrame.identity, alpha)
	end
	for name, cf in b.joints do
		if not out.joints[name] then
			out.joints[name] = CFrame.new():Lerp(cf, alpha)
		end
	end
	for side in SIDES do
		out.hands[side] = a.hands[side]:Lerp(b.hands[side], handAlpha)
	end
	return out
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
	self.mode = "stand"
	self.clock = 0
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

-- Modes -----------------------------------------------------------------

function AvatarRig:stand(home: CFrame)
	self.home, self.mode = home, "stand"
end

function AvatarRig:keep(home: CFrame)
	self.home, self.mode = home, "keep"
end

-- Dive towards `reach` (world point at the shot height) for a shot at column/height.
function AvatarRig:dive(reach: Vector3, column: string, height: string)
	self.from = self:_pose()
	self.to = self:_divePose(reach, column, height)
	self.arc = if column == "centre" then 0 else 0.8
	self.mode, self.timer, self.duration = "dive", 0, config.keeperDiveTime
end

-- Run up from home and strike the ball at `strike`.
function AvatarRig:kick(strike: CFrame)
	self.start, self.strike = self.home, strike
	self.mode, self.timer, self.duration = "kick", 0, config.runUpTime
end

-- Poses ------------------------------------------------------------------

function AvatarRig:_standPose(): Pose
	local sway = 0.03 * math.sin(self.clock * 1.7)
	local pose: Pose = { root = self.home * CFrame.new(0, sway, 0), joints = {}, hands = {} }
	for side, s in SIDES do
		pose.hands[side] = self.home * Vector3.new(s * 1.3, -2.1, -0.15)
		pose.joints[side .. "Elbow"] = angles(15)
	end
	return pose
end

function AvatarRig:_keepPose(): Pose
	local t = self.clock
	local bounce = 0.05 * math.sin(t * math.pi * 2 * 1.6)
	local sway = 0.12 * math.sin(t * 1.4)
	local pose: Pose = {
		root = self.home * CFrame.new(sway, -0.45 + bounce, 0) * angles(0, 0, -sway * 8),
		joints = { Waist = angles(-14, 0, sway * 10), Neck = angles(12) },
		hands = {},
	}
	for side, s in SIDES do
		pose.joints[side .. "Hip"] = angles(38) * angles(0, 0, s * 7)
		pose.joints[side .. "Knee"] = angles(-72)
		pose.joints[side .. "Ankle"] = angles(32)
		pose.joints[side .. "Elbow"] = angles(45)
		local wave = 0.08 * math.sin(t * 2.3 + s)
		pose.hands[side] = self.home * Vector3.new(s * 1.45, -0.5 + wave, -1.3)
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
	pos = Vector3.new(pos.X, math.max(pos.Y, 1.0), pos.Z)
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

function AvatarRig:_kickPose(t: number): Pose
	local start, strike = self.start, self.strike
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

function AvatarRig:_pose(): Pose
	if self.mode == "keep" then
		return self:_keepPose()
	elseif self.mode == "dive" then
		local t = self.timer / self.duration
		local alpha = 1 - (1 - t) * (1 - t) -- ease out
		local pose = lerpPose(self.from, self.to, alpha, math.sqrt(t))
		pose.root = pose.root + Vector3.yAxis * (self.arc * math.sin(math.pi * t))
		return pose
	elseif self.mode == "kick" then
		return self:_kickPose(self.timer / self.duration)
	end
	return self:_standPose()
end

-- Applying ---------------------------------------------------------------

function AvatarRig:_step(dt: number)
	self.clock += dt
	if self.mode == "dive" or self.mode == "kick" then
		self.timer = math.min(self.timer + dt, self.duration)
	end
	if self.root and self.root.Parent then
		self:_apply(self:_pose())
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
