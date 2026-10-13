-- Owns the 2-player match. Two players per server: p1 and p2 take turns as
-- shooter and keeper. Each kick both submit hidden choices; the server
-- resolves the kick and tells both clients. Clients only send choices.
-- Phases: waiting -> choosing -> playing -> choosing ... -> finished -> (rematch)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require("@self/Assets")
local Duel = require(ReplicatedStorage.Shared.logic.Duel)
local Pitch = require("@self/Pitch")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stage = require(ReplicatedStorage.Shared.Stage)
local config = require(ReplicatedStorage.Shared.config)

Pitch.build(Assets.load())
local remotes = Remotes.get()

-- Time the clients need to show a kick before the next one starts.
local KICK_SHOW_TIME = config.runUpTime + config.ballFlightTime + config.resultHoldTime + 0.3
local BOT_JOIN_DELAY = 2
local CHOOSE_COOLDOWN = 0.2

type Side = "p1" | "p2"
type Slot = {
	player: Player?, -- nil for the Studio test bot
	name: string,
	character: Model?,
	rematch: boolean,
	lastChoose: number,
}

local SIDES: { Side } = { "p1", "p2" }
local slots: { [Side]: Slot } = {}
local duel: Duel.Duel? = nil
local phase = "waiting"
local deadline = 0
local kickToken = 0 -- bumps each kick so stale timers do nothing
local opponentLeft = false -- the finished match ended because a player left

local function sideOf(player: Player): Side?
	for _, side in SIDES do
		local slot = slots[side]
		if slot and slot.player == player then
			return side
		end
	end
	return nil
end

local function bothFilled(): boolean
	return slots.p1 ~= nil and slots.p2 ~= nil
end

-- Avatars stand still; the game places them and clients pose them.
local function freeze(character: Model)
	-- Both clients pose both avatars, so keep them fully streamed in.
	character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
		humanoid.JumpPower = 0
	end
	if root then
		root.Anchored = true
	end
end

local function placeCharacters()
	local shooter, keeper
	if duel and phase ~= "waiting" then
		shooter, keeper = duel:roles()
	end
	for i, side in SIDES do
		local slot = slots[side]
		local character = slot and slot.character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character and root then
			if side == shooter then
				root.CFrame = Stage.shooterHome(character)
			elseif side == keeper then
				root.CFrame = Stage.keeperHome(character)
			else
				root.CFrame = Stage.waitingSpot(character, i)
			end
		end
	end
end

local function stateFor(player: Player)
	local names, characters, chosen, rematch = {}, {}, {}, {}
	for _, side in SIDES do
		local slot = slots[side]
		names[side] = if slot then slot.name else nil
		characters[side] = if slot then slot.character else nil
		chosen[side] = if duel and phase == "choosing" then duel:hasChosen(side) else false
		rematch[side] = if slot then slot.rematch else false
	end
	local roles
	if duel then
		local shooter, keeper = duel:roles()
		roles = { shooter = shooter, keeper = keeper }
	end
	return {
		phase = phase,
		you = sideOf(player),
		names = names,
		characters = characters,
		roles = roles,
		deadline = deadline,
		chosen = chosen,
		state = if duel then duel:getState() else nil,
		summary = if duel and phase == "finished" then duel:summary() else nil,
		rematch = rematch,
	}
end

local function broadcast()
	for _, player in Players:GetPlayers() do
		remotes.MatchState:FireClient(player, stateFor(player))
	end
end

local resolveKick

local function botChoose()
	local current = duel
	if not current then
		return
	end
	local shooter = current:roles()
	local botSide: Side? = nil
	for _, side in SIDES do
		if slots[side] and slots[side].player == nil then
			botSide = side
		end
	end
	if not botSide then
		return
	end
	task.delay(1 + math.random() * 2, function()
		if duel ~= current or phase ~= "choosing" then
			return
		end
		local column = ({ "left", "centre", "right" })[math.random(1, 3)]
		local height = if math.random() < 0.5 then "high" else "low"
		local choice = if botSide == shooter
			then { column = column, height = height, power = math.random(40, 90) }
			else { column = column, height = height }
		current:choose(botSide :: Side, choice)
		broadcast()
		if current:isReady() then
			resolveKick()
		end
	end)
end

local function beginKick()
	kickToken += 1
	local token = kickToken
	phase = "choosing"
	deadline = workspace:GetServerTimeNow() + config.choiceTime
	placeCharacters()
	broadcast()
	botChoose()
	task.delay(config.choiceTime, function()
		if token == kickToken and phase == "choosing" then
			resolveKick()
		end
	end)
end

function resolveKick()
	local current = duel
	if not current or phase ~= "choosing" then
		return
	end
	kickToken += 1
	phase = "playing"
	local result = current:resolve()
	remotes.KickResult:FireAllClients(result)
	broadcast()
	task.delay(KICK_SHOW_TIME, function()
		if duel ~= current or phase ~= "playing" then
			return
		end
		if result.state.finished then
			phase = "finished"
			broadcast()
		else
			beginKick()
		end
	end)
end

local function startMatch()
	duel = Duel.new(DateTime.now().UnixTimestampMillis % 2147483646 + 1)
	opponentLeft = false
	for _, side in SIDES do
		slots[side].rematch = slots[side].player == nil -- the bot always agrees
	end
	beginKick()
end

-- Starts a match when both slots are filled and nobody is mid-match. After a
-- normal finish both players must ask for a rematch instead.
local function tryStart()
	if bothFilled() and (phase == "waiting" or (phase == "finished" and opponentLeft)) then
		startMatch()
	else
		broadcast()
	end
end

local function spawnBot(side: Side)
	local description = Instance.new("HumanoidDescription")
	local ok, bot = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	local character = if ok then bot else nil
	if character then
		character.Name = "TestBot"
		character.Parent = workspace
		freeze(character)
	end
	slots[side] = { player = nil, name = "Test Bot", character = character, rematch = true, lastChoose = 0 }
end

local function removeBot()
	for _, side in SIDES do
		local slot = slots[side]
		if slot and slot.player == nil then
			if slot.character then
				slot.character:Destroy()
			end
			slots[side] = nil
		end
	end
end

-- In Studio, a lone player gets a bot opponent so the game can be tested.
local function maybeAddBot()
	if not (config.studioBot and RunService:IsStudio()) then
		return
	end
	task.delay(BOT_JOIN_DELAY, function()
		if bothFilled() or not (phase == "waiting" or opponentLeft) then
			return
		end
		for _, side in SIDES do
			if not slots[side] then
				spawnBot(side)
				break
			end
		end
		tryStart()
	end)
end

local function onCharacter(player: Player, character: Model)
	local side = sideOf(player)
	if side then
		slots[side].character = character
	end
	freeze(character)
	placeCharacters()
	broadcast()
end

local function addPlayer(player: Player)
	-- A real player replaces the Studio bot if it is not mid-match.
	if phase == "waiting" or opponentLeft then
		removeBot()
	end
	for _, side in SIDES do
		if not slots[side] then
			slots[side] = {
				player = player,
				name = player.DisplayName,
				character = player.Character,
				rematch = false,
				lastChoose = 0,
			}
			break
		end
	end
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
	tryStart()
	if not bothFilled() then
		maybeAddBot()
	end
end

local function removePlayer(player: Player)
	local side = sideOf(player)
	if not side then
		return
	end
	slots[side] = nil
	if duel and (phase == "choosing" or phase == "playing") then
		-- Leaving mid-match forfeits; the other player sees the result screen.
		kickToken += 1
		duel:forfeit(side)
		phase = "finished"
	end
	if phase == "finished" then
		opponentLeft = true
	end
	if not slots.p1 and not slots.p2 then
		duel = nil
		phase = "waiting"
		opponentLeft = false
	end
	broadcast()
	maybeAddBot()
end

remotes.Ready.OnServerEvent:Connect(function(player)
	remotes.MatchState:FireClient(player, stateFor(player))
end)

remotes.Choose.OnServerEvent:Connect(function(player, choice)
	local side = sideOf(player)
	local current = duel
	if not side or not current or phase ~= "choosing" then
		return
	end
	local slot = slots[side]
	if os.clock() - slot.lastChoose < CHOOSE_COOLDOWN then
		return
	end
	slot.lastChoose = os.clock()
	if not current:choose(side, choice) then
		return -- invalid choice: ignore
	end
	broadcast()
	if current:isReady() then
		resolveKick()
	end
end)

remotes.Rematch.OnServerEvent:Connect(function(player)
	local side = sideOf(player)
	if not side or phase ~= "finished" or not bothFilled() then
		return
	end
	slots[side].rematch = true
	if slots.p1.rematch and slots.p2.rematch then
		startMatch()
	else
		broadcast()
	end
end)

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)
for _, player in Players:GetPlayers() do
	addPlayer(player)
end
