-- Client: shows the waiting room, opens the shooter/keeper controls each kick,
-- plays back every resolved kick for both players, and the result screen.
-- The server decides everything; this only sends choices and displays.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraDirector = require("@self/CameraDirector")
local Cutscene = require("@self/Cutscene")
local Hud = require("@self/Hud")
local People = require("@self/People")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ResultScreen = require("@self/ResultScreen")
local Visuals = require("@self/Visuals")
local Stage = require(ReplicatedStorage.Shared.Stage)
local config = require(ReplicatedStorage.Shared.config)

local remotes = Remotes.get()

local RESULT_TEXT = {
	GOAL = "GOAL!",
	SAVED = "SAVED!",
	MISSED = "MISSED!",
	POST = "OFF THE POST!",
}

local current: any = { phase = "waiting", names = {}, characters = {}, chosen = {}, rematch = {} }
local shownDeadline = 0 -- deadline of the kick whose controls were last set up
local queue = {}
local playing = false
local SLOW_MOTION = 2.5 -- the deciding kick plays this many times slower

local function other(side: string): string
	return if side == "p1" then "p2" else "p1"
end

local function nameOf(side: string): string
	return current.names[side] or "Opponent"
end

local function myRole(): string?
	local roles, you = current.roles, current.you
	if not roles or not you then
		return nil
	end
	return if you == roles.shooter then "shooter" elseif you == roles.keeper then "keeper" else nil
end

local function updateScore()
	local state = current.state or { scores = { p1 = 0, p2 = 0 } }
	Hud.setNames(current.names, current.you)
	Hud.setScore(state, current.names, current.you)
end

-- Text under the score: stage, your role, and who has locked in.
local function updateStatus()
	local state, you = current.state, current.you
	if not state then
		return
	end
	local stage = if state.suddenDeath then "Sudden death" else `Round {state.round} of {config.rounds}`
	local role = myRole()
	local roleText = if role == "shooter"
		then "You're shooting"
		elseif role == "keeper" then "You're in goal"
		else "Watching"
	Hud.setStatus(`{stage}  |  {roleText}`)

	local centre = ""
	if current.phase == "choosing" and you then
		if current.chosen[you] then
			centre = `Locked in - waiting for {nameOf(other(you))}`
		elseif current.chosen[other(you)] then
			centre = `{nameOf(other(you))} has locked in`
		end
	end
	Hud.setCentre(centre)
end

-- Where the shooter and keeper stand this kick, for the cinematic cameras.
local function sceneFor(roles: any): CameraDirector.Scene
	local shooter = roles and current.characters[roles.shooter]
	local keeper = roles and current.characters[roles.keeper]
	return {
		shooter = if shooter
			then Stage.shooterHome(shooter).Position
			else Stage.BALL_SPOT + Vector3.new(-1.6, 2.3, 4.5),
		keeper = if keeper then Stage.keeperHome(keeper).Position else Vector3.new(0, 3, Stage.KEEPER_Z),
	}
end

local function showFinished()
	CameraDirector.stop()
	Hud.closeChoice()
	Hud.setStatus("")
	Hud.setCentre("")
	Hud.showResult("")
	if not current.summary then
		return
	end
	ResultScreen.show(current.summary, current.names, current.you)
	local you = current.you
	if you and not current.names[other(you)] then
		ResultScreen.setWaiting("Your opponent left - waiting for a new player...")
	elseif you and current.rematch[you] then
		ResultScreen.setWaiting(`Waiting for {nameOf(other(you))} to accept...`)
	end
end

-- Applies the latest MatchState. While a kick is animating, the scene is left
-- alone and this runs again once the animation ends.
local function applyState()
	updateScore()
	if playing then
		return
	end
	local phase = current.phase
	if phase == "waiting" then
		ResultScreen.hide()
		Hud.closeChoice()
		Hud.clearDots()
		Hud.showResult("")
		Hud.setStatus("")
		Hud.setCentre("Waiting for an opponent...")
		Visuals.setScene(current.characters, nil)
		CameraDirector.stop()
		Visuals.setCamera("shooter")
	elseif phase == "choosing" then
		if current.deadline ~= shownDeadline then
			-- A new kick: reset the scene and open this player's controls.
			shownDeadline = current.deadline
			ResultScreen.hide()
			Hud.showResult("")
			local state = current.state
			if state and state.taken.p1 + state.taken.p2 == 0 then
				-- A new match: clear the dots and put the teams back in line.
				Hud.clearDots()
				People.regroup()
			end
			Visuals.setScene(current.characters, current.roles)
			local role = myRole()
			-- Cinematic shots while both players choose.
			CameraDirector.start(sceneFor(current.roles))
			if role and not current.chosen[current.you] then
				Hud.openChoice(role, current.deadline)
			end
		end
		updateStatus()
	elseif phase == "finished" then
		showFinished()
	end
end

-- The dramatic ending after the deciding kick, then back to the HUD.
local function playEnding(winnerSide: string)
	local loserSide = other(winnerSide)
	local winner = current.characters[winnerSide]
	local loser = current.characters[loserSide]
	Hud.setVisible(false)
	Cutscene.play(winnerSide, winner, loser, Visuals.rigFor(winner), Visuals.rigFor(loser), People)
	Hud.setVisible(true)
	Hud.showResult("")
end

local function playNext()
	if playing then
		return
	end
	playing = true
	while #queue > 0 do
		local result = table.remove(queue, 1)
		Hud.closeChoice()
		Hud.setCentre("")
		Hud.showResult("")
		-- Back to the player's own view for the kick itself.
		CameraDirector.stop()
		Visuals.setCamera(if current.you == result.keeper then "keeper" else "shooter")
		local deciding = result.summary ~= nil
		Visuals.playKick(
			result,
			current.characters[result.side],
			current.characters[result.keeper],
			if deciding then SLOW_MOTION else 1
		)

		-- Green when the result is good for you (your goal, or your save).
		local you = current.you
		local scored = result.outcome == "GOAL"
		local good = if you == result.side then scored elseif you == result.keeper then not scored else scored
		Hud.showResult(RESULT_TEXT[result.outcome], if good then Hud.GOAL_COLOR else Hud.FAIL_COLOR)
		if scored then
			People.cheer()
		end
		Hud.addDot(result.side, result.outcome)
		Hud.setScore(result.state, current.names, current.you)
		if result.summary and result.summary.winner then
			task.wait(1)
			playEnding(result.summary.winner)
		else
			task.wait(config.resultHoldTime)
		end
	end
	playing = false
	applyState()
end

Visuals.init()
task.spawn(People.init)
Hud.init(function(choice)
	remotes.Choose:FireServer(choice)
end)
ResultScreen.init(function()
	remotes.Rematch:FireServer()
	local you = current.you
	ResultScreen.setWaiting(if you then `Waiting for {nameOf(other(you))} to accept...` else nil)
end)

remotes.KickResult.OnClientEvent:Connect(function(result)
	table.insert(queue, result)
	task.spawn(playNext)
end)

remotes.MatchState.OnClientEvent:Connect(function(message)
	current = message
	current.names = current.names or {}
	current.characters = current.characters or {}
	current.chosen = current.chosen or {}
	current.rematch = current.rematch or {}
	applyState()
end)

remotes.Ready:FireServer()
