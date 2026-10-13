-- Poses the segmented keeper mesh every frame: an idle "ready" stance and a
-- dive where both hands reach for a target. Arms and legs use two-bone IK, so
-- poses work for any dive spot without animation assets.
--
-- Body space: feet at y = 0, facing +Z, keeper's left (L) at +X. Joint
-- positions must match KEEPER_JOINTS in assets/source/build_models.py
-- (Blender (x, y, z) -> Roblox (x, z, -y)).

local RunService = game:GetService("RunService")

local function v(x, y, z)
	return Vector3.new(x, y, z)
end

local PELVIS = v(0, 2.2, 0)
local WAIST = v(0, 2.45, 0)
local NECK = v(0, 4.25, 0)
local SIDES = { L = 1, R = -1 }
local LIMBS = {}
for tag, s in SIDES do
	LIMBS[tag] = {
		shoulder = v(s * 1.0, 4.0, 0),
		elbow = v(s * 1.35, 3.05, 0),
		wrist = v(s * 1.6, 2.15, 0),
		hip = v(s * 0.45, 2.05, 0),
		knee = v(s * 0.5, 1.2, 0),
		ankle = v(s * 0.5, 0.42, 0),
	}
end

-- Which joint transform moves each mesh segment.
local DRIVER = {
	Shorts = "pelvis",
	Torso = "chest",
	Head = "head",
	HeadDark = "head",
}
for tag in SIDES do
	DRIVER["UpperArm" .. tag] = "upper" .. tag
	DRIVER["Forearm" .. tag] = "fore" .. tag
	DRIVER["Glove" .. tag] = "fore" .. tag
	DRIVER["Thigh" .. tag] = "thigh" .. tag
	DRIVER["Shin" .. tag] = "shin" .. tag
end

local IDLE_CROUCH = 0.35
local DIVE_REACH = 3.65 -- pelvis to hands: arms almost straight past the head
local HAND_SPREAD = 0.35
local HANDS_IN_FRONT = 0.6

export type Pose = {
	root: CFrame, -- world CFrame of the pelvis joint
	chest: CFrame, -- rotation about the waist
	head: CFrame, -- rotation about the neck
	hands: { [string]: Vector3 }, -- world wrist targets
	feet: { [string]: Vector3 }, -- world ankle targets
	elbowPole: { [string]: Vector3 }, -- world directions elbows bend towards
	kneePole: { [string]: Vector3 },
}

local Keeper = {}
Keeper.__index = Keeper

-- Rotation taking unit vector u onto unit vector v.
local function between(u: Vector3, w: Vector3): CFrame
	local axis = u:Cross(w)
	local dot = math.clamp(u:Dot(w), -1, 1)
	if axis.Magnitude < 1e-6 then
		if dot > 0 then
			return CFrame.identity
		end
		local perp = u:Cross(Vector3.xAxis)
		if perp.Magnitude < 1e-3 then
			perp = u:Cross(Vector3.yAxis)
		end
		return CFrame.fromAxisAngle(perp.Unit, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

-- Two-bone IK: returns the middle joint and end positions reaching for target.
local function solve(base: Vector3, len1: number, len2: number, target: Vector3, pole: Vector3): (Vector3, Vector3)
	local offset = target - base
	local dist = math.clamp(offset.Magnitude, 0.05, len1 + len2 - 0.001)
	local dir = if offset.Magnitude > 1e-4 then offset.Unit else Vector3.yAxis * -1
	local cosA = math.clamp((len1 * len1 + dist * dist - len2 * len2) / (2 * len1 * dist), -1, 1)
	local bend = pole - dir * pole:Dot(dir)
	if bend.Magnitude < 1e-4 then
		bend = dir:Cross(Vector3.xAxis)
	end
	local mid = base + dir * (len1 * cosA) + bend.Unit * (len1 * math.sqrt(1 - cosA * cosA))
	return mid, base + dir * dist
end

-- Transform for a limb segment whose rest bone runs restA -> restB, now placed
-- from a to b, hanging off a parent transform.
local function limb(parent: CFrame, restA: Vector3, restB: Vector3, a: Vector3, b: Vector3): CFrame
	local parentRot = parent.Rotation
	local restDir = parentRot:VectorToWorldSpace((restB - restA).Unit)
	local rot = between(restDir, (b - a).Unit) * parentRot
	return CFrame.new(a) * rot * CFrame.new(-restA)
end

function Keeper.new(model: Model)
	local self = setmetatable({}, Keeper)
	self.model = model
	self.parts = {}
	self.rest = {}
	-- The model arrives in its rest pose at the origin.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and DRIVER[part.Name] then
			table.insert(self.parts, part)
			self.rest[part] = model:GetPivot():ToObjectSpace(part.CFrame)
		end
	end
	self.home = CFrame.identity
	self.mode = "idle"
	self.clock = 0
	self.connection = RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
	return self
end

function Keeper:reset(home: CFrame)
	self.home = home
	self.mode = "idle"
	self:_apply(self:_idlePose())
end

-- Starts a dive. reach = world point the hands go for; column/height of the
-- shot it is diving at.
function Keeper:dive(reach: Vector3, column: string, height: string, duration: number)
	self.mode = "dive"
	self.diveTime = 0
	self.diveDuration = duration
	self.from = self:_idlePose()
	self.to = self:_divePose(reach, column, height)
	self.arc = if column == "centre" then 0 else 0.8
end

function Keeper:_idlePose(): Pose
	local t = self.clock
	local home = self.home
	local bounce = 0.05 * math.sin(t * math.pi * 2 * 1.6)
	local sway = 0.12 * math.sin(t * 1.4)
	local pose: Pose = {
		root = home * CFrame.new(sway, PELVIS.Y - IDLE_CROUCH + bounce, 0) * CFrame.Angles(0, 0, -sway * 0.3),
		chest = CFrame.Angles(math.rad(14), 0, sway * 0.2),
		head = CFrame.Angles(math.rad(-10), 0, -sway * 0.2),
		hands = {},
		feet = {},
		elbowPole = {},
		kneePole = {},
	}
	for tag, s in SIDES do
		local wave = 0.08 * math.sin(t * 2.3 + s)
		pose.hands[tag] = home * v(s * 1.45, 2.9 + wave, 1.1)
		pose.feet[tag] = home * v(s * 0.62, 0.42, 0.05)
		pose.elbowPole[tag] = home:VectorToWorldSpace(v(s, -0.4, -0.5))
		pose.kneePole[tag] = home:VectorToWorldSpace(v(s * 0.3, 0, 1))
	end
	return pose
end

function Keeper:_divePose(reach: Vector3, column: string, height: string): Pose
	local home = self.home
	local pose: Pose = { hands = {}, feet = {}, elbowPole = {}, kneePole = {} } :: any
	local front = home:VectorToWorldSpace(v(0, 0, HANDS_IN_FRONT))

	if column == "centre" then
		if height == "high" then
			-- Jump straight up, both hands overhead.
			local pelvisY = math.max(PELVIS.Y - IDLE_CROUCH, reach.Y - DIVE_REACH)
			pose.root = CFrame.new(home.Position.X, home.Position.Y + pelvisY, home.Position.Z) * home.Rotation
			pose.chest = CFrame.identity
			pose.head = CFrame.Angles(math.rad(-15), 0, 0)
			for tag, s in SIDES do
				pose.feet[tag] = pose.root * v(s * 0.5, -1.65, -0.15)
				pose.kneePole[tag] = home:VectorToWorldSpace(v(0, 0, 1))
			end
		else
			-- Low block: deep crouch, legs wide, hands down in front.
			pose.root = home * CFrame.new(0, 1.3, 0)
			pose.chest = CFrame.Angles(math.rad(30), 0, 0)
			pose.head = CFrame.Angles(math.rad(-25), 0, 0)
			for tag, s in SIDES do
				pose.feet[tag] = home * v(s * 0.95, 0.42, 0)
				pose.kneePole[tag] = home:VectorToWorldSpace(v(s, 0, 1))
			end
		end
		-- Low block: hands go down by the ball, well out in front of the body.
		local handBase = if height == "low" then v(reach.X, 1.0, reach.Z) + front * 2.2 else reach + front
		for tag, s in SIDES do
			local spread = home:VectorToWorldSpace(v(s * HAND_SPREAD, 0, 0))
			pose.hands[tag] = handBase + spread
			pose.elbowPole[tag] = home:VectorToWorldSpace(v(s, -0.5, -0.3))
		end
		return pose
	end

	-- Side dive: body laid out flat towards the ball, hands at full stretch.
	local towards = if column == "left" then -1 else 1 -- world X direction of the dive
	local roll = -towards * math.rad(80)
	local bodyRot = home.Rotation * CFrame.Angles(0, 0, roll) * CFrame.Angles(math.rad(10), 0, 0)
	local up = bodyRot.UpVector
	local pelvis = reach - up * DIVE_REACH
	pelvis = v(pelvis.X, math.max(pelvis.Y, 0.75), pelvis.Z)
	pose.root = CFrame.new(pelvis) * bodyRot
	pose.chest = CFrame.Angles(0, 0, roll * 0.1)
	pose.head = CFrame.Angles(math.rad(-10), 0, roll * 0.15)

	-- The leg on the upper side tucks; the lower leg stays long.
	local upperTag = if bodyRot.RightVector.Y > 0 then "L" else "R"
	for tag, s in SIDES do
		local spread = up:Cross(bodyRot.LookVector).Unit * (s * HAND_SPREAD)
		pose.hands[tag] = reach + spread + front
		pose.elbowPole[tag] = bodyRot:VectorToWorldSpace(v(s, 0, -1))
		if tag == upperTag then
			pose.feet[tag] = pose.root * v(s * 0.45, -1.25, -0.75)
		else
			pose.feet[tag] = pose.root * v(s * 0.5, -1.75, 0.1)
		end
		pose.kneePole[tag] = bodyRot:VectorToWorldSpace(v(0, 0, 1))
	end
	return pose
end

local function blend(a: Pose, b: Pose, alpha: number, handAlpha: number): Pose
	local out: Pose = {
		root = a.root:Lerp(b.root, alpha),
		chest = a.chest:Lerp(b.chest, alpha),
		head = a.head:Lerp(b.head, alpha),
		hands = {},
		feet = {},
		elbowPole = {},
		kneePole = {},
	}
	for tag in SIDES do
		out.hands[tag] = a.hands[tag]:Lerp(b.hands[tag], handAlpha)
		out.feet[tag] = a.feet[tag]:Lerp(b.feet[tag], alpha)
		out.elbowPole[tag] = a.elbowPole[tag]:Lerp(b.elbowPole[tag], alpha)
		out.kneePole[tag] = a.kneePole[tag]:Lerp(b.kneePole[tag], alpha)
	end
	return out
end

function Keeper:_step(dt: number)
	self.clock += dt
	if self.mode == "idle" then
		self:_apply(self:_idlePose())
		return
	end
	self.diveTime = math.min(self.diveTime + dt, self.diveDuration)
	local t = self.diveTime / self.diveDuration
	local alpha = 1 - (1 - t) * (1 - t) -- ease out
	local pose = blend(self.from, self.to, alpha, math.sqrt(t))
	pose.root = pose.root + Vector3.yAxis * (self.arc * math.sin(math.pi * t))
	self:_apply(pose)
end

function Keeper:_apply(pose: Pose)
	local w = {}
	w.pelvis = pose.root * CFrame.new(-PELVIS)
	w.chest = w.pelvis * CFrame.new(WAIST) * pose.chest * CFrame.new(-WAIST)
	w.head = w.chest * CFrame.new(NECK) * pose.head * CFrame.new(-NECK)

	for tag, j in LIMBS do
		local shoulder = w.chest * j.shoulder
		local elbow, wrist = solve(
			shoulder,
			(j.elbow - j.shoulder).Magnitude,
			(j.wrist - j.elbow).Magnitude,
			pose.hands[tag],
			pose.elbowPole[tag]
		)
		w["upper" .. tag] = limb(w.chest, j.shoulder, j.elbow, shoulder, elbow)
		w["fore" .. tag] = limb(w["upper" .. tag], j.elbow, j.wrist, elbow, wrist)

		local hip = w.pelvis * j.hip
		local knee, ankle =
			solve(hip, (j.knee - j.hip).Magnitude, (j.ankle - j.knee).Magnitude, pose.feet[tag], pose.kneePole[tag])
		w["thigh" .. tag] = limb(w.pelvis, j.hip, j.knee, hip, knee)
		w["shin" .. tag] = limb(w["thigh" .. tag], j.knee, j.ankle, knee, ankle)
	end

	local cframes = table.create(#self.parts)
	for i, part in self.parts do
		cframes[i] = w[DRIVER[part.Name]] * self.rest[part]
	end
	workspace:BulkMoveTo(self.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

return Keeper
