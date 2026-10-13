-- Every message between client and server. The server creates these; the
-- client waits for them.
--
-- Ready       client -> server  ()                         client loaded, send state
-- Kick        client -> server  { column, height, power }  player's shot (validated)
-- MatchState  server -> client  Match.State                full state on start/ready
-- KickResult  server -> client  Session.KickResult         every kick, player and AI

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "Ready", "Kick", "MatchState", "KickResult" }
local FOLDER_NAME = "Remotes"

local Remotes = {}

function Remotes.get(): { [string]: RemoteEvent }
	local folder
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			for _, name in NAMES do
				local event = Instance.new("RemoteEvent")
				event.Name = name
				event.Parent = folder
			end
			folder.Parent = ReplicatedStorage
		end
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	end

	local events = {}
	for _, name in NAMES do
		events[name] = folder:WaitForChild(name) :: RemoteEvent
	end
	return events
end

return Remotes
