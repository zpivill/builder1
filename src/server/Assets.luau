-- Loads the mesh models (Ball, Goal) once, applies the palette and
-- puts them in ReplicatedStorage.Assets for the server and client to clone.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage.Shared.config)

local WHITE = Color3.fromRGB(245, 245, 245)
local DARK = Color3.fromRGB(35, 38, 45)

-- Colour for each mesh, by name.
local COLOURS = {
	BallWhite = WHITE,
	BallPanels = DARK,
	GoalFrame = WHITE,
	GoalSupports = Color3.fromRGB(150, 155, 165),
	GoalNet = Color3.fromRGB(225, 228, 235),
}

-- Where each model's pivot goes, relative to the mesh origin.
local PIVOTS = {
	Ball = CFrame.new(0, 0.7, 0), -- ball centre, so it can spin in place
	Goal = CFrame.identity, -- goal line centre
}

local LOAD_ATTEMPTS = 3

local Assets = {}

local function load(id: number): Model
	local lastError
	for attempt = 1, LOAD_ATTEMPTS do
		local ok, result = pcall(InsertService.LoadAsset, InsertService, id)
		if ok then
			return result
		end
		lastError = result
		task.wait(attempt)
	end
	error(`could not load asset {id}: {lastError}`)
end

local function prepare(name: string, container: Model): Model
	-- LoadAsset wraps the uploaded model in an extra Model.
	local model = container:FindFirstChildOfClass("Model") or container
	model.Name = name
	model.Parent = nil
	if model ~= container then
		container:Destroy()
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Material = Enum.Material.SmoothPlastic
			part.Color = COLOURS[part.Name] or part.Color
			part.CastShadow = part.Name ~= "GoalNet"
		end
	end
	model.WorldPivot = PIVOTS[name]
	return model
end

-- Loads every model into ReplicatedStorage.Assets. Yields.
function Assets.load(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Assets"
	for name, id in config.assetIds do
		prepare(name, load(id)).Parent = folder
	end
	folder.Parent = ReplicatedStorage
	return folder
end

return Assets
