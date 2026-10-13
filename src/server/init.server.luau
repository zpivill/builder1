-- Owns the match: one player per server vs the AI. Every kick is resolved
-- here; the client only sends preset choices, aim and power.
-- Phases per player: picking -> playing -> finished -> (StartMatch) playing ...

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lineup = require(ReplicatedStorage.Shared.logic.Lineup)
local Pitch = require("@self/Pitch")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Session = require(ReplicatedStorage.Shared.logic.Session)
local config = require(ReplicatedStorage.Shared.config)

-- No avatar: the client uses a fixed camera behind the penalty spot.
Players.CharacterAutoLoads = false

Pitch.build()
local remotes = Remotes.get()

-- Time the client needs to show one kick before the next can start.
local KICK_COOLDOWN = config.ballFlightTime + config.resultHoldTime * 0.5
local START_COOLDOWN = 1

type Phase = "picking" | "playing" | "finished"
type PlayerData = {
	phase: Phase,
	session: Session.Session?,
	lineups: { player: Lineup.Lineup, ai: Lineup.Lineup }?,
	busy: boolean,
	lastStart: number,
}
local players: { [Player]: PlayerData } = {}

local function names(lineup: Lineup.Lineup)
	return { shooter = lineup.shooter.name, keeper = lineup.keeper.name }
end

local function sendState(player: Player, data: PlayerData)
	local lineups = data.lineups
	remotes.MatchState:FireClient(player, {
		phase = data.phase,
		state = if data.session then data.session:getState() else nil,
		lineups = if lineups then { player = names(lineups.player), ai = names(lineups.ai) } else nil,
	})
end

local function sendResult(player: Player, data: PlayerData, result: Session.KickResult)
	if result.state.finished then
		data.phase = "finished"
	end
	remotes.KickResult:FireClient(player, result)
end

local function playAiKick(player: Player, data: PlayerData, session: Session.Session)
	task.wait(config.aiKickDelay)
	if players[player] ~= data or data.session ~= session then
		return -- player left or a new match started
	end
	local result = session:aiKick()
	if result then
		sendResult(player, data, result)
		task.wait(KICK_COOLDOWN)
	end
	data.busy = false
end

remotes.Ready.OnServerEvent:Connect(function(player)
	local data = players[player]
	if data then
		sendState(player, data)
	end
end)

remotes.StartMatch.OnServerEvent:Connect(function(player, choice)
	local data = players[player]
	if not data or data.phase == "playing" or os.clock() - data.lastStart < START_COOLDOWN then
		return
	end
	local playerChoice = Lineup.validChoice(choice)
	if not playerChoice then
		return
	end
	data.lastStart = os.clock()

	local playerLineup = Lineup.fromChoice(playerChoice)
	local aiLineup = Lineup.fromChoice(Lineup.aiChoice(playerChoice))
	data.lineups = { player = playerLineup, ai = aiLineup }
	data.session = Session.new({
		seed = DateTime.now().UnixTimestampMillis % 2147483646 + 1,
		playerShooter = playerLineup.shooter,
		playerKeeper = playerLineup.keeper,
		aiShooter = aiLineup.shooter,
		aiKeeper = aiLineup.keeper,
	})
	data.phase = "playing"
	data.busy = false
	sendState(player, data)
end)

remotes.Kick.OnServerEvent:Connect(function(player, shot)
	local data = players[player]
	local session = data and data.session
	if not data or not session or data.phase ~= "playing" or data.busy then
		return
	end
	local result = session:playerKick(shot)
	if not result then
		return -- wrong turn or invalid shot: ignore
	end
	data.busy = true
	sendResult(player, data, result)
	if result.state.finished then
		data.busy = false
	else
		task.spawn(playAiKick, player, data, session)
	end
end)

local function addPlayer(player: Player)
	players[player] = { phase = "picking", busy = false, lastStart = -math.huge }
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	players[player] = nil
end)
for _, player in Players:GetPlayers() do
	addPlayer(player)
end
