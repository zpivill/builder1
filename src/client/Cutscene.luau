-- The ending: after the deciding kick (already played in slow motion), the
-- screen flashes and shakes, the crowd erupts, the winner sprints to meet
-- their teammates rushing in from the halfway line, and the loser sinks to
-- the ground. Three camera shots follow it, then the result screen shows.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Stage = require(game:GetService("ReplicatedStorage").Shared.Stage)

local RUN_TIME = 3.4
local SHOT_TIMES = { 3.2, 2.6, 2.4 } -- follow the winner, the celebration, the loser
local SHAKE_TIME = 0.9
local SHAKE_SIZE = 0.6
local BIND_NAME = "ShootoutCutscene"

local Cutscene = {}

-- Briefly whites out the screen.
local function flash()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Flash"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local tween = TweenService:Create(frame, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
	tween.Completed:Connect(function()
		gui:Destroy()
	end)
	tween:Play()
end

local function rootOf(character: Model?): BasePart?
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Plays the ending. Yields until it finishes.
-- rigs: AvatarRig for the winner and loser (either may be nil).
-- people: the People module, to rush the winner's team and cheer.
function Cutscene.play(winnerSide: string, winner: Model?, loser: Model?, winnerRig: any, loserRig: any, people: any)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	flash()
	people.cheer(12)

	-- The winner and their team meet halfway between them.
	local winnerRoot = rootOf(winner)
	local from = if winnerRoot then winnerRoot.Position else Stage.BALL_SPOT
	local meet = Vector3.new(0, 0, (from.Z + Stage.HALFWAY_Z) / 2)
	if winnerRig then
		local y = winnerRig.standY
		winnerRig:runTo(CFrame.lookAt(Vector3.new(meet.X, y, meet.Z - 1), Vector3.new(meet.X, y, meet.Z)), RUN_TIME)
	end
	people.rush(winnerSide, meet, RUN_TIME)
	if loserRig then
		loserRig:collapse()
	end

	-- Time is summed from frame steps (not the wall clock) so the camera stays
	-- in step with the avatar animations even when the frame rate drops.
	local t = 0
	local total = SHOT_TIMES[1] + SHOT_TIMES[2] + SHOT_TIMES[3]
	local lastCamera = camera.CFrame
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 2, function(dt)
		t += dt
		local cf
		if t < SHOT_TIMES[1] then
			-- Track alongside the winner as they run.
			local p = if winnerRoot then winnerRoot.Position else meet
			cf = CFrame.lookAt(p + Vector3.new(9, 4, -4), p + Vector3.new(0, 1, 2))
		elseif t < SHOT_TIMES[1] + SHOT_TIMES[2] then
			-- Slow sweep around the celebration.
			local a = (t - SHOT_TIMES[1]) * 0.5
			cf = CFrame.lookAt(meet + Vector3.new(math.sin(a) * 24, 10, -math.cos(a) * 24), meet + Vector3.yAxis * 2)
		else
			-- Push in on the loser lying on the pitch.
			local u = (t - SHOT_TIMES[1] - SHOT_TIMES[2]) / SHOT_TIMES[3]
			local loserRoot = rootOf(loser)
			local p = if loserRoot then loserRoot.Position else Stage.BALL_SPOT
			cf = CFrame.lookAt(p + Vector3.new(5 - 2 * u, 3.5 - u, 5 - 2 * u), p)
		end
		-- Shake hard at the start, fading out.
		if t < SHAKE_TIME then
			local size = SHAKE_SIZE * (1 - t / SHAKE_TIME)
			cf *= CFrame.new(math.random() * size - size / 2, math.random() * size - size / 2, 0) * CFrame.Angles(
				0,
				0,
				math.rad(math.random() * 4 - 2) * (1 - t / SHAKE_TIME)
			)
		end
		camera.CFrame = cf
		lastCamera = cf
	end)

	repeat
		task.wait()
	until t >= total
	RunService:UnbindFromRenderStep(BIND_NAME)
	camera.CFrame = lastCamera
end

return Cutscene
