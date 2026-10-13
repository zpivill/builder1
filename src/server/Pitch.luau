-- Builds the pitch (grass, mowing stripes, full markings) from simple parts and
-- places the goal mesh model. Goal line at z = 0, centred on x = 0; the
-- penalty spot is at +z and the pitch runs to Stage.PITCH_LENGTH.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stage = require(ReplicatedStorage.Shared.Stage)
local config = require(ReplicatedStorage.Shared.config)

local WHITE = Color3.fromRGB(245, 245, 245)
local GRASS = Color3.fromRGB(58, 125, 52)
local GRASS_LIGHT = Color3.fromRGB(70, 140, 60)
local LINE_WIDTH = 0.4
local LINE_Y = 0.03
local STRIPE_COUNT = 20

-- Real-pitch markings in studs (see Stage for the scale).
local PENALTY_BOX = { halfWidth = 66, depth = 54 }
local SIX_YARD_BOX = { halfWidth = 30, depth = 18 }
local CIRCLE_RADIUS = 30
local CORNER_RADIUS = 3

local Pitch = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	props: { [string]: any }?
)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props or {} do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end
Pitch.part = part

-- A painted line on the grass between two (x, z) points.
local function line(parent: Instance, x1: number, z1: number, x2: number, z2: number)
	local a, b = Vector3.new(x1, LINE_Y, z1), Vector3.new(x2, LINE_Y, z2)
	local length = (b - a).Magnitude
	part(parent, "Line", Vector3.new(LINE_WIDTH, 0.05, length + LINE_WIDTH), CFrame.lookAt((a + b) / 2, b), WHITE, {
		CanCollide = false,
		CastShadow = false,
	})
end

-- A painted arc around (cx, cz), from angle a0 to a1 (radians, 0 = +z).
local function arc(parent: Instance, cx: number, cz: number, radius: number, a0: number, a1: number, segments: number)
	for i = 0, segments - 1 do
		local t0 = a0 + (a1 - a0) * i / segments
		local t1 = a0 + (a1 - a0) * (i + 1) / segments
		line(
			parent,
			cx + radius * math.sin(t0),
			cz + radius * math.cos(t0),
			cx + radius * math.sin(t1),
			cz + radius * math.cos(t1)
		)
	end
end

local function spot(parent: Instance, x: number, z: number, size: number)
	part(
		parent,
		"Spot",
		Vector3.new(0.05, size, size),
		CFrame.new(x, LINE_Y, z) * CFrame.Angles(0, 0, math.rad(90)),
		WHITE,
		{ Shape = Enum.PartType.Cylinder, CanCollide = false, CastShadow = false }
	)
end

-- Penalty box, six-yard box, spot and arc at one end. `dir` is +1 for the near
-- end (goal line z = 0) and -1 for the far end.
local function endMarkings(parent: Instance, goalZ: number, dir: number)
	local pb, sb = PENALTY_BOX, SIX_YARD_BOX
	for _, box in { pb, sb } do
		local front = goalZ + dir * box.depth
		line(parent, -box.halfWidth, goalZ, -box.halfWidth, front)
		line(parent, box.halfWidth, goalZ, box.halfWidth, front)
		line(parent, -box.halfWidth, front, box.halfWidth, front)
	end
	local spotZ = goalZ + dir * config.penaltyDistance
	spot(parent, 0, spotZ, 1)
	-- The arc is the part of the circle round the spot outside the box.
	local edge = math.acos((pb.depth - config.penaltyDistance) / CIRCLE_RADIUS)
	if dir > 0 then
		arc(parent, 0, spotZ, CIRCLE_RADIUS, -edge, edge, 12)
	else
		arc(parent, 0, spotZ, CIRCLE_RADIUS, math.pi - edge, math.pi + edge, 12)
	end
end

local function markings(parent: Instance)
	local w, len, mid = Stage.PITCH_HALF_WIDTH, Stage.PITCH_LENGTH, Stage.HALFWAY_Z
	line(parent, -w, 0, w, 0) -- goal lines
	line(parent, -w, len, w, len)
	line(parent, -w, 0, -w, len) -- touchlines
	line(parent, w, 0, w, len)
	line(parent, -w, mid, w, mid) -- halfway line
	arc(parent, 0, mid, CIRCLE_RADIUS, 0, math.pi * 2, 40)
	spot(parent, 0, mid, 1)
	endMarkings(parent, 0, 1)
	endMarkings(parent, len, -1)
	-- Corner arcs: a quarter circle into the pitch from each corner.
	for _, corner in { { -w, 0, 0 }, { w, 0, -math.pi / 2 }, { -w, len, math.pi / 2 }, { w, len, -math.pi } } do
		arc(parent, corner[1], corner[2], CORNER_RADIUS, corner[3], corner[3] + math.pi / 2, 4)
	end
end

-- Alternating light/dark bands across the pitch, like a mown lawn.
local function stripes(parent: Instance)
	local w, len = Stage.PITCH_HALF_WIDTH + 6, Stage.PITCH_LENGTH
	local band = len / STRIPE_COUNT
	for i = 0, STRIPE_COUNT - 1, 2 do
		part(
			parent,
			"Stripe",
			Vector3.new(w * 2, 0.02, band),
			CFrame.new(0, 0.01, band * (i + 0.5)),
			GRASS_LIGHT,
			{ Material = Enum.Material.Grass, CanCollide = false, CastShadow = false }
		)
	end
end

-- `assets` is ReplicatedStorage.Assets from Assets.load().
function Pitch.build(assets: Folder): Model
	local old = workspace:FindFirstChild("Pitch")
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Model")
	-- No avatar means no streaming focus; keep the pitch always streamed in.
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	folder.Name = "Pitch"

	part(folder, "Grass", Vector3.new(1000, 1, 1000), CFrame.new(0, -0.5, Stage.HALFWAY_Z), GRASS, {
		Material = Enum.Material.Grass,
	})
	stripes(folder)
	local lines = Instance.new("Model")
	lines.Name = "Markings"
	lines.Parent = folder
	markings(lines)

	local goal = (assets:WaitForChild("Goal") :: Model):Clone()
	goal:PivotTo(CFrame.identity)
	goal.Parent = folder

	-- The place's default Baseplate and SpawnLocation would show through the
	-- pitch and sit in the goal mouth. Hide them for this session only.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local leftover = workspace:FindFirstChild(name)
		if leftover and leftover:IsA("BasePart") then
			leftover.Transparency = 1
			leftover.CanCollide = false
			leftover.CastShadow = false
			if leftover:IsA("SpawnLocation") then
				local decal = leftover:FindFirstChildOfClass("Decal")
				if decal then
					decal.Transparency = 1
				end
			end
		end
	end

	folder.Parent = workspace
	return folder
end

return Pitch
