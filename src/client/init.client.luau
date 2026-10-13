-- Client: sends the player's aim/power, animates server results, updates HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = require("@self/Hud")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Visuals = require("@self/Visuals")
local config = require(ReplicatedStorage.Shared.config)

local remotes = Remotes.get()

local RESULT_TEXT = {
	GOAL = "GOAL!",
	SAVED = "SAVED!",
	MISSED = "MISSED!",
	POST = "OFF THE POST!",
}

local function applyState(state)
	Hud.setState(state)
	if state.finished then
		Hud.setControlsEnabled(false)
		local won = state.winner == "player"
		Hud.showResult(if won then "YOU WIN!" else "AI WINS", if won then Hud.GOAL_COLOR else Hud.FAIL_COLOR)
	else
		Hud.setControlsEnabled(state.nextSide == "player")
	end
end

Visuals.init()
Hud.init(function(shot)
	remotes.Kick:FireServer(shot)
end)

-- Results are queued so each kick finishes animating before the next starts.
local queue = {}
local playing = false

local function playNext()
	if playing then
		return
	end
	playing = true
	while #queue > 0 do
		local result = table.remove(queue, 1)
		Hud.setControlsEnabled(false)
		Hud.showResult("", Color3.new(1, 1, 1))
		Visuals.playKick(result)

		local good = (result.side == "player") == (result.outcome == "GOAL")
		local prefix = if result.side == "ai" then "AI: " else ""
		Hud.showResult(prefix .. RESULT_TEXT[result.outcome], if good then Hud.GOAL_COLOR else Hud.FAIL_COLOR)
		Hud.addDot(result.side, result.outcome)
		Hud.setState(result.state)
		task.wait(config.resultHoldTime)

		if not result.state.finished then
			Hud.showResult("", Color3.new(1, 1, 1))
			Visuals.reset(result.state.nextSide)
		end
		if #queue == 0 then
			applyState(result.state)
		end
	end
	playing = false
end

remotes.KickResult.OnClientEvent:Connect(function(result)
	table.insert(queue, result)
	task.spawn(playNext)
end)

remotes.MatchState.OnClientEvent:Connect(function(state)
	Hud.clearDots()
	applyState(state)
end)

remotes.Ready:FireServer()
