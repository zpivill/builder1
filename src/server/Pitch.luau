-- Builds the pitch and goal from simple parts. Goal line at z = 0, centred on
-- x = 0; the penalty spot is at +z.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage.Shared.config)

local POST_THICKNESS = 0.6
local NET_DEPTH = 4

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

function Pitch.build(): Model
	local old = workspace:FindFirstChild("Pitch")
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Model")
	-- No avatar means no streaming focus; keep the pitch always streamed in.
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	folder.Name = "Pitch"

	local w, h, t = config.goalWidth, config.goalHeight, POST_THICKNESS
	local white = Color3.new(1, 1, 1)

	part(folder, "Grass", Vector3.new(160, 1, 140), CFrame.new(0, -0.5, 30), Color3.fromRGB(58, 125, 52), {
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

	part(folder, "LeftPost", Vector3.new(t, h, t), CFrame.new(-w / 2 - t / 2, h / 2, 0), white)
	part(folder, "RightPost", Vector3.new(t, h, t), CFrame.new(w / 2 + t / 2, h / 2, 0), white)
	part(folder, "Crossbar", Vector3.new(w + 2 * t, t, t), CFrame.new(0, h + t / 2, 0), white)

	local net = { Transparency = 0.6, CanCollide = false }
	local grey = Color3.fromRGB(220, 220, 220)
	part(folder, "NetBack", Vector3.new(w, h, 0.1), CFrame.new(0, h / 2, -NET_DEPTH), grey, net)
	part(folder, "NetTop", Vector3.new(w, 0.1, NET_DEPTH), CFrame.new(0, h, -NET_DEPTH / 2), grey, net)
	part(folder, "NetLeft", Vector3.new(0.1, h, NET_DEPTH), CFrame.new(-w / 2, h / 2, -NET_DEPTH / 2), grey, net)
	part(folder, "NetRight", Vector3.new(0.1, h, NET_DEPTH), CFrame.new(w / 2, h / 2, -NET_DEPTH / 2), grey, net)

	folder.Parent = workspace
	return folder
end

return Pitch
