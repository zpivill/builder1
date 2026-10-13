-- Owns the match: one player per server vs the AI. Every kick is resolved
-- here; the client only sends aim and power.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

type PlayerData = { session: Session.Session, busy: boolean }
local players: { [Player]: PlayerData } = {}

local function newSession(): Session.Session
	return Session.new({ seed = DateTime.now().UnixTimestampMillis % 2147483646 + 1 })
end

local function playAiKick(player: Player, data: PlayerData)
	task.wait(config.aiKickDelay)
	if players[player] ~= data then
		return -- player left
	end
	local result = data.session:aiKick()
	if result then
		remotes.KickResult:FireClient(player, result)
		task.wait(KICK_COOLDOWN)
	end
	data.busy = false
end

remotes.Ready.OnServerEvent:Connect(function(player)
	local data = players[player]
	if data then
		remotes.MatchState:FireClient(player, data.session:getState())
	end
end)

remotes.Kick.OnServerEvent:Connect(function(player, shot)
	local data = players[player]
	if not data or data.busy then
		return
	end
	local result = data.session:playerKick(shot)
	if not result then
		return -- wrong turn or invalid shot: ignore
	end
	data.busy = true
	remotes.KickResult:FireClient(player, result)
	if result.state.finished then
		data.busy = false
	else
		task.spawn(playAiKick, player, data)
	end
end)

Players.PlayerAdded:Connect(function(player)
	players[player] = { session = newSession(), busy = false }
end)

Players.PlayerRemoving:Connect(function(player)
	players[player] = nil
end)

for _, player in Players:GetPlayers() do
	players[player] = { session = newSession(), busy = false }
end
