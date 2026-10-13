-- Client: pick screen, sends aim/power, animates server results, HUD and
-- result screen. The server decides everything; this only displays it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = require("@self/Hud")
local PickScreen = require("@self/PickScreen")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ResultScreen = require("@self/ResultScreen")
local Visuals = require("@self/Visuals")
local config = require(ReplicatedStorage.Shared.config)

local remotes = Remotes.get()

local RESULT_TEXT = {
	GOAL = "GOAL!",
	SAVED = "SAVED!",
	MISSED = "MISSED!",
	POST = "OFF THE POST!",
}
local NO_TEXT = Color3.new(1, 1, 1)

local function applyState(state)
	Hud.setState(state)
	Hud.setControlsEnabled(not state.finished and state.nextSide == "player")
end

local function showPicker()
	ResultScreen.hide()
	Hud.setVisible(false)
	PickScreen.show()
end

Visuals.init()
Hud.init(function(shot)
	remotes.Kick:FireServer(shot)
end)
PickScreen.init(function(choice)
	remotes.StartMatch:FireServer(choice)
end)
ResultScreen.init(showPicker)

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
		Hud.showResult("", NO_TEXT)
		Visuals.playKick(result)

		local good = (result.side == "player") == (result.outcome == "GOAL")
		local prefix = if result.side == "ai" then "AI: " else ""
		Hud.showResult(prefix .. RESULT_TEXT[result.outcome], if good then Hud.GOAL_COLOR else Hud.FAIL_COLOR)
		Hud.addDot(result.side, result.outcome)
		Hud.setState(result.state)
		task.wait(config.resultHoldTime)

		Hud.showResult("", NO_TEXT)
		if result.summary then
			Hud.setControlsEnabled(false)
			ResultScreen.show(result.summary)
		else
			Visuals.reset(result.state.nextSide)
			if #queue == 0 then
				applyState(result.state)
			end
		end
	end
	playing = false
end

remotes.KickResult.OnClientEvent:Connect(function(result)
	table.insert(queue, result)
	task.spawn(playNext)
end)

remotes.MatchState.OnClientEvent:Connect(function(message)
	if message.phase == "playing" then
		table.clear(queue)
		PickScreen.hide()
		ResultScreen.hide()
		Hud.clearDots()
		Hud.showResult("", NO_TEXT)
		Hud.setLineups(message.lineups)
		Hud.setVisible(true)
		Visuals.reset(message.state.nextSide)
		applyState(message.state)
	else
		showPicker()
	end
end)

remotes.Ready:FireServer()
