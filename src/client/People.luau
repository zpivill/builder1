-- Animates the scenery avatars the server loads into workspace.People:
-- teammates huddle arm-in-arm (full AvatarRig), and the crowd cheers with a
-- cheap bounce and arm wave (60 of them, so no IK). After a goal the crowd
-- goes wild for a few seconds.

local RunService = game:GetService("RunService")

local AvatarRig = require(script.Parent.AvatarRig)

local EXCITED_TIME = 3.5

local People = {}

type Fan = { model: Model, root: BasePart, home: CFrame, phase: number, joints: { [string]: any } }

local fans: { [Model]: Fan } = {}
local rigs: { [Model]: any } = {}
local excitedUntil = 0

local function joints(model: Model): { [string]: any }
	local found = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			found[d.Name] = d
		end
	end
	return found
end

local function track(model: Instance)
	if not model:IsA("Model") or fans[model] or rigs[model] then
		return
	end
	local role = model:GetAttribute("Role")
	local home = model:GetAttribute("Home")
	local root = model:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root or typeof(home) ~= "CFrame" then
		return
	end
	if role == "teammate" then
		local rig = AvatarRig.new(model)
		rig:huddle(home, model:GetAttribute("TowardCentreX"), model:GetAttribute("AwayX"))
		rigs[model] = rig
	elseif role == "fan" then
		fans[model] = {
			model = model,
			root = root,
			home = home,
			phase = (model:GetAttribute("Phase") :: number?) or 0,
			joints = joints(model),
		}
	end
	model.Destroying:Connect(function()
		fans[model] = nil
		if rigs[model] then
			rigs[model]:destroy()
			rigs[model] = nil
		end
	end)
end

-- Crowd goes wild (after a goal), for `duration` seconds.
function People.cheer(duration: number?)
	excitedUntil = math.max(excitedUntil, os.clock() + (duration or EXCITED_TIME))
end

-- A team sprints to `meet` and celebrates around it (end of the match).
function People.rush(side: string, meet: Vector3, duration: number)
	local i = 0
	for model, rig in rigs do
		if model:GetAttribute("Side") == side then
			i += 1
			local angle = i * (math.pi * 2 / 5)
			local spot = meet + Vector3.new(math.cos(angle) * 3, 0, math.sin(angle) * 3)
			local home = rig.home :: CFrame
			local at = Vector3.new(spot.X, home.Position.Y, spot.Z)
			rig:runTo(CFrame.lookAt(at, Vector3.new(meet.X, at.Y, meet.Z)), duration)
		end
	end
end

-- Puts teammates back in their lines (for a rematch).
function People.regroup()
	for model, rig in rigs do
		local home = model:GetAttribute("Home")
		if typeof(home) == "CFrame" then
			rig:huddle(home, model:GetAttribute("TowardCentreX"), model:GetAttribute("AwayX"))
		end
	end
end

function People.init()
	local folder = workspace:WaitForChild("People")
	folder.DescendantAdded:Connect(function(d)
		if d:IsA("Model") and d.Parent and d.Parent.Parent == folder then
			task.spawn(track, d)
		end
	end)
	for _, group in folder:GetChildren() do
		for _, model in group:GetChildren() do
			task.spawn(track, model)
		end
	end

	-- PreSimulation runs after the Animator, so these transforms stick.
	RunService.PreSimulation:Connect(function()
		local t = os.clock()
		local excited = t < excitedUntil
		local speed = if excited then 9 else 4
		local hop = if excited then 0.7 else 0.2
		for _, fan in fans do
			local wave = math.sin(t * speed + fan.phase)
			fan.root.CFrame = fan.home + Vector3.yAxis * (hop * math.abs(wave))
			local raise = math.rad(if excited then 165 else 120 + 30 * wave)
			local left, right = fan.joints.LeftShoulder, fan.joints.RightShoulder
			if right then
				right.Transform = CFrame.Angles(0, 0, raise + math.rad(10) * wave)
			end
			if left then
				left.Transform = CFrame.Angles(0, 0, -raise + math.rad(10) * wave)
			end
		end
	end)
end

return People
