-- Cinematic cameras while the players choose: slow drifting shots that cut
-- and blend between each other, like a battle game's move-select camera.
-- start() begins the loop; stop() hands the camera back.

local RunService = game:GetService("RunService")

local Stage = require(game:GetService("ReplicatedStorage").Shared.Stage)
local config = require(game:GetService("ReplicatedStorage").Shared.config)

local SHOT_TIME = 2.6
local BLEND_TIME = 0.7
local BIND_NAME = "ShootoutDirector"

export type Scene = { shooter: Vector3, keeper: Vector3 }
type Shot = (scene: Scene, t: number) -> (CFrame, number) -- camera, field of view

local function look(from: Vector3, at: Vector3): CFrame
	return CFrame.lookAt(from, at)
end

-- t runs 0 -> 1 over the shot.
local SHOTS: { Shot } = {
	-- Low across the goal mouth, sliding along the line.
	function(scene, t)
		local x = 15 - 5 * t
		return look(Vector3.new(x, 1.6, 5), scene.keeper + Vector3.new(0, 0.5, 0)), 50
	end,
	-- Slow orbit in front of the shooter.
	function(scene, t)
		local a = math.rad(-40 + 70 * t)
		local p = scene.shooter
		return look(p + Vector3.new(math.sin(a) * 6, 1.5, -math.cos(a) * 6), p + Vector3.new(0, 0.8, 0)), 45
	end,
	-- Slow orbit in front of the keeper.
	function(scene, t)
		local a = math.rad(40 - 70 * t)
		local p = scene.keeper
		return look(p + Vector3.new(math.sin(a) * 8, 2.5, math.cos(a) * 8), p + Vector3.new(0, 0.5, 0)), 45
	end,
	-- Low behind the ball, creeping towards the goal.
	function(_, t)
		local z = config.penaltyDistance + 7 - 2 * t
		return look(Vector3.new(2.4, 1.6, z), Vector3.new(0, 3, 0)), 50
	end,
	-- Wide from high in the corner of the stadium, panning.
	function(_, t)
		return look(Vector3.new(110, 55, 120), Vector3.new(-20 + 40 * t, 0, 25)), 60
	end,
	-- From the crowd at the side.
	function(_, t)
		return look(Vector3.new(142 - 3 * t, 13, 30 + 6 * t), Vector3.new(0, 2, 20)), 40
	end,
	-- Along the teammates on the halfway line.
	function(_, t)
		local x = -20 + 40 * t
		return look(Vector3.new(x, 4, Stage.HALFWAY_Z - 12), Vector3.new(x * 0.6, 3, Stage.HALFWAY_Z)), 50
	end,
}

local CameraDirector = {}

local active = false
local scene: Scene
local order: { number } = {}
local index = 0
local shotStart = 0
local previous: CFrame? = nil

local function shuffle()
	local last = order[#order]
	order = {}
	for i = 1, #SHOTS do
		table.insert(order, i)
	end
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end
	-- Don't show the same shot twice in a row across shuffles.
	if order[1] == last then
		order[1], order[#order] = order[#order], order[1]
	end
end

local function update()
	local camera = workspace.CurrentCamera
	local now = os.clock()
	if now - shotStart >= SHOT_TIME then
		previous = camera.CFrame
		shotStart = now
		index += 1
		if index > #order then
			shuffle()
			index = 1
		end
	end
	local elapsed = now - shotStart
	local cf, fov = SHOTS[order[index]](scene, elapsed / SHOT_TIME)
	if previous and elapsed < BLEND_TIME then
		local a = elapsed / BLEND_TIME
		cf = previous:Lerp(cf, a * a * (3 - 2 * a))
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cf
	camera.FieldOfView = camera.FieldOfView + (fov - camera.FieldOfView) * 0.1
end

-- Starts cycling shots around the shooter and keeper positions.
function CameraDirector.start(newScene: Scene)
	scene = newScene
	if active then
		return
	end
	active = true
	shuffle()
	index = 1
	shotStart = os.clock()
	previous = workspace.CurrentCamera.CFrame
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, update)
end

function CameraDirector.stop()
	if not active then
		return
	end
	active = false
	RunService:UnbindFromRenderStep(BIND_NAME)
	workspace.CurrentCamera.FieldOfView = 50
end

return CameraDirector
