-- The ball, both players' avatars (posed by AvatarRig) and the camera. Purely
-- visual: outcomes always come from the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AvatarRig = require(script.Parent.AvatarRig)
local ShotPath = require(ReplicatedStorage.Shared.logic.ShotPath)
local Stage = require(ReplicatedStorage.Shared.Stage)
local config = require(ReplicatedStorage.Shared.config)

local BALL_SPIN_TURNS = 2

local Visuals = {}

local ball: Model
local rigs: { [Model]: any } = {}

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

-- Point at depth `z` on the straight line from the spot through the goal-plane
-- point (x, y). Keeps misses on the path ShotPath aimed them along, so wide
-- shots pass outside the posts and high shots pass over the bar.
local function alongShotLine(x: number, y: number, z: number): Vector3
	local start = Stage.BALL_SPOT
	local through = Vector3.new(x, y, 0)
	return start + (through - start) * ((start.Z - z) / start.Z)
end

local function rigFor(character: Model?): any
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return nil
	end
	local rig = rigs[character]
	if not rig then
		rig = AvatarRig.new(character)
		rigs[character] = rig
	end
	return rig
end

function Visuals.init()
	-- Mesh models loaded by the server (src/server/Assets.luau).
	local assets = ReplicatedStorage:WaitForChild("Assets")
	ball = (assets:WaitForChild("Ball") :: Model):Clone()
	ball.Parent = workspace
	ball:PivotTo(CFrame.new(Stage.BALL_SPOT))

	workspace.CurrentCamera.FieldOfView = 50
	Visuals.setCamera("shooter")
end

-- Shooter view from behind the ball, keeper view from behind the goal.
function Visuals.setCamera(view: string)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	if view == "keeper" then
		-- Inside the goal just above and behind the keeper's head (under the
		-- net roof), looking out at the shooter.
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 7.2, -1.2), Vector3.new(0, 3, config.penaltyDistance))
	else
		-- High and to the right so the shooter's own avatar doesn't block the goal.
		camera.CFrame =
			CFrame.lookAt(Vector3.new(4, 11, config.penaltyDistance + 18), Vector3.new(0, config.goalHeight / 2 - 1, 0))
	end
end

-- Places and poses every avatar for the current kick. `characters` maps
-- p1/p2 to models; `roles` says who shoots and who keeps (nil while waiting).
function Visuals.setScene(characters: { [string]: Model? }, roles: { shooter: string, keeper: string }?)
	local alive = {}
	for i, side in { "p1", "p2" } do
		local character = characters[side]
		local rig = rigFor(character)
		if rig then
			alive[character :: Model] = true
			if roles and side == roles.keeper then
				rig:keep(Stage.keeperHome(character :: Model))
			elseif roles and side == roles.shooter then
				rig:stand(Stage.shooterHome(character :: Model))
			else
				rig:stand(Stage.waitingSpot(character :: Model, i))
			end
		end
	end
	for character, rig in rigs do
		if not alive[character] then
			rig:destroy()
			rigs[character] = nil
		end
	end
	ball:PivotTo(CFrame.new(Stage.BALL_SPOT))
end

-- Animates one resolved kick: run-up, strike, keeper dive and ball flight.
-- Yields until the ball has landed.
function Visuals.playKick(result: any, shooterCharacter: Model?, keeperCharacter: Model?)
	ball:PivotTo(CFrame.new(Stage.BALL_SPOT))
	local shooterRig = rigFor(shooterCharacter)
	local keeperRig = rigFor(keeperCharacter)

	if shooterRig then
		shooterRig:kick(Stage.shooterStrike(shooterCharacter :: Model))
	end
	task.wait(config.runUpTime)

	local x, y = ShotPath.target(result.shot, result.outcome)
	local z = if result.outcome == "GOAL"
		then -1.5
		elseif result.outcome == "SAVED" then Stage.KEEPER_Z + 1
		elseif result.outcome == "MISSED" then -10
		else 0
	local finish = alongShotLine(x, y, z)

	-- The keeper dives to the zone they chose; their hands go for that spot.
	if keeperRig then
		local _, diveY = ShotPath.aimPoint(result.dive.column, result.dive.height)
		local reach = Vector3.new(ShotPath.diveX(result.dive.column), diveY, Stage.KEEPER_Z)
		keeperRig:dive(reach, result.dive.column, result.dive.height)
	end

	-- Ball flies along the shot line, spinning forward.
	local start = Stage.BALL_SPOT
	local flight = TweenInfo.new(config.ballFlightTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = animate(flight, function(alpha)
		local spin = CFrame.Angles(-math.pi * 2 * BALL_SPIN_TURNS * alpha, 0, 0)
		ball:PivotTo(CFrame.new(start:Lerp(finish, alpha)) * spin)
	end)
	tween.Completed:Wait()

	if result.outcome == "POST" or result.outcome == "SAVED" then
		-- Rebound back toward the pitch.
		local bounce = CFrame.new(finish.X * 1.2, Stage.BALL_RADIUS, 8)
		tweenPivot(ball, TweenInfo.new(0.5, Enum.EasingStyle.Quad), bounce)
	end
end

return Visuals
