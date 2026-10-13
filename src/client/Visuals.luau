-- Local copies of the ball and keeper meshes, plus the fixed camera. Purely visual:
-- the outcome always comes from the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Keeper = require(script.Parent.Keeper)
local ShotPath = require(ReplicatedStorage.Shared.logic.ShotPath)
local config = require(ReplicatedStorage.Shared.config)

local BALL_SIZE = 1.4
local KEEPER_Z = 1
local BALL_SPIN_TURNS = 2

local PLAYER_KIT = Color3.fromRGB(40, 110, 230)
local AI_KIT = Color3.fromRGB(230, 70, 50)

local Visuals = {}

local ball: Model
local keeper: Model
local keeperRig: any

-- Runs onStep(alpha) every frame while a tween eases alpha from 0 to 1.
local function animate(info: TweenInfo, onStep: (alpha: number) -> ()): Tween
	local value = Instance.new("NumberValue")
	value.Changed:Connect(onStep)
	local tween = TweenService:Create(value, info, { Value = 1 })
	tween.Completed:Connect(function()
		value:Destroy()
	end)
	tween:Play()
	return tween
end

-- Moves a model smoothly from its current pivot to `goal`.
local function tweenPivot(model: Model, info: TweenInfo, goal: CFrame): Tween
	local from = model:GetPivot()
	return animate(info, function(alpha)
		model:PivotTo(from:Lerp(goal, alpha))
	end)
end

local function spotCFrame(): CFrame
	return CFrame.new(0, BALL_SIZE / 2, config.penaltyDistance)
end

local function keeperHome(): CFrame
	return CFrame.new(0, 0, KEEPER_Z)
end

-- Point at depth `z` on the straight line from the spot through the goal-plane
-- point (x, y). Keeps misses on the path ShotPath aimed them along, so wide
-- shots pass outside the posts and high shots pass over the bar.
local function alongShotLine(x: number, y: number, z: number): Vector3
	local start = spotCFrame().Position
	local through = Vector3.new(x, y, 0)
	return start + (through - start) * ((start.Z - z) / start.Z)
end

function Visuals.init()
	-- Mesh models loaded by the server (src/server/Assets.luau).
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local folder = Instance.new("Folder")
	folder.Name = "LocalVisuals"
	ball = (assets:WaitForChild("Ball") :: Model):Clone()
	ball.Parent = folder
	keeper = (assets:WaitForChild("Keeper") :: Model):Clone()
	keeper.Parent = folder
	keeperRig = Keeper.new(keeper)
	folder.Parent = workspace
	Visuals.reset("player")

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 50
	camera.CFrame =
		CFrame.lookAt(Vector3.new(0, 7, config.penaltyDistance + 14), Vector3.new(0, config.goalHeight / 2, 0))
end

function Visuals.reset(side: string)
	ball:PivotTo(spotCFrame())
	keeperRig:reset(keeperHome())
	-- The player's own keeper defends AI kicks.
	local kitColor = if side == "ai" then PLAYER_KIT else AI_KIT
	for _, p in keeper:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Kit") then
			p.Color = kitColor
		end
	end
end

-- Animates one resolved kick. Yields until the ball has landed.
function Visuals.playKick(result: any)
	Visuals.reset(result.side)

	local x, y = ShotPath.target(result.shot, result.outcome)
	local z = if result.outcome == "GOAL"
		then -1.5
		elseif result.outcome == "SAVED" then KEEPER_Z + 1
		elseif result.outcome == "MISSED" then -10
		else 0
	local finish = alongShotLine(x, y, z)

	-- Keeper dives to the reported column; hands reach for that spot at the
	-- shot's height (the ball itself when the keeper guessed right).
	local _, aimY = ShotPath.aimPoint(result.shot.column, result.shot.height)
	local reach = Vector3.new(ShotPath.diveX(result.dive), aimY, KEEPER_Z)
	keeperRig:dive(reach, result.dive, result.shot.height, config.keeperDiveTime)

	-- Ball flies along the shot line, spinning forward.
	local start = spotCFrame().Position
	local flight = TweenInfo.new(config.ballFlightTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = animate(flight, function(alpha)
		local spin = CFrame.Angles(-math.pi * 2 * BALL_SPIN_TURNS * alpha, 0, 0)
		ball:PivotTo(CFrame.new(start:Lerp(finish, alpha)) * spin)
	end)
	tween.Completed:Wait()

	if result.outcome == "POST" or result.outcome == "SAVED" then
		-- Rebound back toward the pitch.
		local bounce = CFrame.new(finish.X * 1.2, BALL_SIZE / 2, 8)
		tweenPivot(ball, TweenInfo.new(0.5, Enum.EasingStyle.Quad), bounce)
	end
end

return Visuals
