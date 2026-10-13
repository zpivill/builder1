-- Builds the pitch from simple parts and places the goal mesh model. Goal line
-- at z = 0, centred on x = 0; the penalty spot is at +z.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage.Shared.config)

local WHITE = Color3.fromRGB(245, 245, 245)

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

	local white = WHITE

	part(folder, "Grass", Vector3.new(800, 1, 800), CFrame.new(0, -0.5, 30), Color3.fromRGB(58, 125, 52), {
		Material = Enum.Material.Grass,
	})
	part(folder, "GoalLine", Vector3.new(80, 0.05, 0.4), CFrame.new(0, 0.02, 0), white)
	part(folder, "BoxLine", Vector3.new(60, 0.05, 0.4), CFrame.new(0, 0.02, 24), white)
	part(
		folder,
		"PenaltySpot",
		Vector3.new(0.05, 1, 1),
		CFrame.new(0, 0.02, config.penaltyDistance) * CFrame.Angles(0, 0, math.rad(90)),
		white,
		{
			Shape = Enum.PartType.Cylinder,
		}
	)

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
