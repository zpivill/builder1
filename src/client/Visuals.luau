-- Local-only ball and keeper, plus the fixed camera. Purely visual: the
-- outcome always comes from the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ShotPath = require(ReplicatedStorage.Shared.logic.ShotPath)
local config = require(ReplicatedStorage.Shared.config)

local BALL_SIZE = 1.4
local KEEPER_SIZE = Vector3.new(3, 6, 1.2)
local KEEPER_Z = 1
local PLAYER_KEEPER_COLOR = Color3.fromRGB(40, 110, 230)
local AI_KEEPER_COLOR = Color3.fromRGB(230, 70, 50)

local Visuals = {}

local folder: Folder
local ball: Part
local keeper: Part

local function spotCFrame(): CFrame
	return CFrame.new(0, BALL_SIZE / 2, config.penaltyDistance)
end

local function keeperHome(): CFrame
	return CFrame.new(0, KEEPER_SIZE.Y / 2, KEEPER_Z)
end

function Visuals.init()
	folder = Instance.new("Folder")
	folder.Name = "LocalVisuals"

	ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * BALL_SIZE
	ball.Color = Color3.new(1, 1, 1)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = true
	ball.CanCollide = false
	ball.CFrame = spotCFrame()
	ball.Parent = folder

	keeper = Instance.new("Part")
	keeper.Name = "Keeper"
	keeper.Size = KEEPER_SIZE
	keeper.Color = AI_KEEPER_COLOR
	keeper.Anchored = true
	keeper.CanCollide = false
	keeper.CFrame = keeperHome()
	keeper.Parent = folder

	folder.Parent = workspace

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 50
	camera.CFrame =
		CFrame.lookAt(Vector3.new(0, 7, config.penaltyDistance + 14), Vector3.new(0, config.goalHeight / 2, 0))
end

function Visuals.reset(side: string)
	ball.CFrame = spotCFrame()
	keeper.CFrame = keeperHome()
	-- The player's own keeper defends AI kicks.
	keeper.Color = if side == "ai" then PLAYER_KEEPER_COLOR else AI_KEEPER_COLOR
end

-- Animates one resolved kick. Yields until the ball has landed.
function Visuals.playKick(result: any)
	Visuals.reset(result.side)

	local x, y = ShotPath.target(result.shot, result.outcome)
	local z = if result.outcome == "GOAL"
		then -2
		elseif result.outcome == "SAVED" then KEEPER_Z + 1
		elseif result.outcome == "MISSED" then -10
		else 0

	-- Keeper dives to the reported column, lying sideways toward it.
	local diveX = ShotPath.diveX(result.dive)
	local _, aimY = ShotPath.aimPoint(result.shot.column, result.shot.height)
	local lean = if diveX < 0 then 1 elseif diveX > 0 then -1 else 0
	local keeperGoal = CFrame.new(diveX, math.max(aimY, KEEPER_SIZE.X / 2), KEEPER_Z)
		* CFrame.Angles(0, 0, lean * math.rad(80))
	TweenService:Create(keeper, TweenInfo.new(config.keeperDiveTime, Enum.EasingStyle.Quad), { CFrame = keeperGoal })
		:Play()

	local flight = TweenInfo.new(config.ballFlightTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(ball, flight, { CFrame = CFrame.new(x, y, z) })
	tween:Play()
	tween.Completed:Wait()

	if result.outcome == "POST" or result.outcome == "SAVED" then
		-- Rebound back toward the pitch.
		local bounce = TweenService:Create(
			ball,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad),
			{ CFrame = CFrame.new(x * 1.2, BALL_SIZE / 2, 8) }
		)
		bounce:Play()
	end
end

return Visuals
