-- Loads the extra avatars: each player's teammates (from their friends list,
-- topped up with random users) standing arm-in-arm on the halfway line, and a
-- crowd of random users in the stands. Every avatar is a different user and
-- looks different (identical default-looking avatars are skipped).
-- Loading happens in the background; models appear as they load. Clients
-- animate them (src/client/People.luau) using the attributes set here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stage = require(ReplicatedStorage.Shared.Stage)

local TEAM_SIZE = 5
local CROWD_SIZE = 60
local TEAMMATE_SPACING = 2.6
local TEAM_GAP = 3 -- from the centre spot to each team's first teammate
local RANDOM_TRIES = 6
local RANDOM_ID_MIN = 100000000
local RANDOM_ID_MAX = 4000000000
local CROWD_MAX_Z = Stage.HALFWAY_Z -- keep the crowd near the goal end

local People = {}

local folder: Folder
local usedIds: { [number]: boolean } = {}
local usedLooks: { [string]: boolean } = {}
local teams: { [string]: { userId: number?, models: { Model } } } = {}
local rng = Random.new()

local function container(name: string): Folder
	local f = folder:FindFirstChild(name) :: Folder?
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = folder
	end
	return f :: Folder
end

-- Anchored, non-colliding, no name tags: these avatars are only scenery.
local function prepare(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true
	end
end

-- What an avatar visibly looks like: clothing and hair/hat. Many accounts
-- share the same default outfit with small hidden differences (body part or
-- face ids), so only the parts you notice at a glance are compared.
local function look(model: Model): string
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local d = humanoid and humanoid:FindFirstChildOfClass("HumanoidDescription")
	if not d then
		return model.Name
	end
	return table.concat({ d.Shirt, d.Pants, d.GraphicTShirt, d.HairAccessory, d.HatAccessory }, "|")
end

-- The user's avatar, or nil if it fails to load or looks like one already used.
local function fromUserId(userId: number): Model?
	local ok, model = pcall(Players.CreateHumanoidModelFromUserId, Players, userId)
	if not ok or not model then
		return nil
	end
	local key = look(model)
	if usedLooks[key] then
		model:Destroy()
		return nil
	end
	usedLooks[key] = true
	return model
end

-- A plain figure in random colours, used when no real avatar loads.
local function fallback(): Model?
	local description = Instance.new("HumanoidDescription")
	local colour = Color3.fromHSV(rng:NextNumber(), rng:NextNumber(0.4, 0.8), rng:NextNumber(0.5, 0.9))
	local skin = Color3.fromHSV(rng:NextNumber(0.05, 0.1), rng:NextNumber(0.2, 0.6), rng:NextNumber(0.4, 0.95))
	description.HeadColor = skin
	description.LeftArmColor, description.RightArmColor = skin, skin
	description.TorsoColor = colour
	description.LeftLegColor, description.RightLegColor = colour:Lerp(Color3.new(), 0.5), colour:Lerp(Color3.new(), 0.5)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	return if ok then model else nil
end

-- A random real user's avatar not used anywhere else yet.
local function randomAvatar(): Model?
	for _ = 1, RANDOM_TRIES do
		local id = rng:NextInteger(RANDOM_ID_MIN, RANDOM_ID_MAX)
		if not usedIds[id] then
			usedIds[id] = true
			local model = fromUserId(id)
			if model then
				return model
			end
		end
	end
	return fallback()
end

-- Up to `count` friend user ids of a player that are not used yet.
local function friendIds(userId: number, count: number): { number }
	local ids = {}
	local ok, pages = pcall(Players.GetFriendsAsync, Players, userId)
	if not ok then
		return ids
	end
	while #ids < count do
		for _, friend in pages:GetCurrentPage() do
			if #ids >= count then
				break
			end
			if not usedIds[friend.Id] then
				table.insert(ids, friend.Id)
			end
		end
		if pages.IsFinished or #ids >= count then
			break
		end
		if not pcall(pages.AdvanceToNextPageAsync, pages) then
			break
		end
	end
	return ids
end

-- Where teammate `index` (1 = nearest the centre) of `side` stands on the
-- halfway line, facing the goal being used.
local function teammateHome(side: string, index: number, model: Model): CFrame
	local dir = if side == "p1" then -1 else 1
	local x = dir * (TEAM_GAP + (index - 1) * TEAMMATE_SPACING)
	local p = Vector3.new(x, Stage.rootHeight(model), Stage.HALFWAY_Z)
	return CFrame.lookAt(p, p - Vector3.zAxis)
end

local function placeTeammate(side: string, index: number, model: Model)
	local home = teammateHome(side, index, model)
	model:SetAttribute("Role", "teammate")
	model:SetAttribute("Side", side)
	model:SetAttribute("Home", home)
	-- Neighbours' x positions, for arms over shoulders (nil at the ends).
	local dir = if side == "p1" then -1 else 1
	model:SetAttribute("TowardCentreX", if index > 1 then home.Position.X - dir * TEAMMATE_SPACING else nil)
	model:SetAttribute("AwayX", if index < TEAM_SIZE then home.Position.X + dir * TEAMMATE_SPACING else nil)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.CFrame = home
	end
end

-- Builds (or keeps) the teammates for one side. `player` is nil for the
-- Studio bot, which has no friends to draw on.
function People.setTeam(side: string, player: Player?)
	local userId = if player then player.UserId else nil
	local existing = teams[side]
	if existing and existing.userId == userId then
		return
	end
	if existing then
		for _, model in existing.models do
			model:Destroy()
		end
	end
	local team = { userId = userId, models = {} }
	teams[side] = team
	local parent = container("Team_" .. side)

	task.spawn(function()
		if userId then
			usedIds[userId] = true
		end
		local ids = if userId then friendIds(userId, TEAM_SIZE) else {}
		for _, id in ids do
			usedIds[id] = true
		end
		for index = 1, TEAM_SIZE do
			if teams[side] ~= team then
				return -- replaced while loading
			end
			local model = if ids[index] then fromUserId(ids[index]) else nil
			model = model or randomAvatar()
			if model then
				model.Name = `Teammate_{side}_{index}`
				prepare(model)
				placeTeammate(side, index, model)
				model.Parent = parent
				table.insert(team.models, model)
			end
		end
	end)
end

-- Fills `count` random seats with random cheering fans, loading a few at a time.
local function buildCrowd(seats: { CFrame })
	local near = {}
	for _, seat in seats do
		if seat.Position.Z < CROWD_MAX_Z then
			table.insert(near, seat)
		end
	end
	local parent = container("Crowd")
	local batch = 8
	for start = 1, CROWD_SIZE, batch do
		local pending = 0
		for i = start, math.min(start + batch - 1, CROWD_SIZE) do
			if #near == 0 then
				return
			end
			local seat = table.remove(near, rng:NextInteger(1, #near))
			pending += 1
			task.spawn(function()
				local model = randomAvatar()
				if model then
					model.Name = `Fan_{i}`
					prepare(model)
					local home = seat + Vector3.yAxis * Stage.rootHeight(model)
					model:SetAttribute("Role", "fan")
					model:SetAttribute("Home", home)
					model:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
					local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						root.CFrame = home
					end
					model.Parent = parent
				end
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait(0.1)
		end
	end
end

-- Call once at startup with the stadium's seat spots.
function People.init(seats: { CFrame })
	folder = Instance.new("Folder")
	folder.Name = "People"
	folder.Parent = workspace
	task.spawn(buildCrowd, seats)
end

return People
