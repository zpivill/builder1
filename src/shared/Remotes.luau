-- Every message between client and server. The server creates these; the
-- client waits for them.
--
-- Ready       client -> server  ()                          client loaded; reply with MatchState
-- Choose      client -> server  shot { column, height, power } from the shooter, or
--                               dive { column, height } from the keeper (validated);
--                               only while phase is "choosing"
-- Rematch     client -> server  ()                          only while phase is "finished"
-- MatchState  server -> client  { phase, you, names, characters, roles, deadline,
--                                 chosen, state, summary, rematch }
--                               phase: "waiting" | "choosing" | "playing" | "finished"
-- KickResult  server -> client  Duel.KickResult             both players; the last kick
--                                                           carries .summary

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "Ready", "Choose", "Rematch", "MatchState", "KickResult" }
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
