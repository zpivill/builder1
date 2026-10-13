-- Turns the client's preset choice into shooters/keepers, and gives the AI
-- the presets the player didn't pick.

local config = require("../config")

export type Choice = { shooter: number, keeper: number }
export type Lineup = { shooter: config.Shooter, keeper: config.Keeper }

local Lineup = {}

local function validIndex(value: any, list: { any }): boolean
	return type(value) == "number" and value == math.floor(value) and list[value] ~= nil
end

-- `choice` comes from the client, so it is validated and copied before use.
function Lineup.validChoice(choice: any): (Choice?, string?)
	if type(choice) ~= "table" then
		return nil, "invalid choice"
	end
	if not validIndex(choice.shooter, config.shooters) then
		return nil, "invalid shooter"
	end
	if not validIndex(choice.keeper, config.keepers) then
		return nil, "invalid keeper"
	end
	return { shooter = choice.shooter, keeper = choice.keeper }
end

function Lineup.fromChoice(choice: Choice): Lineup
	return { shooter = config.shooters[choice.shooter], keeper = config.keepers[choice.keeper] }
end

-- First preset the player didn't pick (falls back to the same one if only one exists).
local function other(list: { any }, picked: number): number
	for i in list do
		if i ~= picked then
			return i
		end
	end
	return picked
end

function Lineup.aiChoice(player: Choice): Choice
	return { shooter = other(config.shooters, player.shooter), keeper = other(config.keepers, player.keeper) }
end

return Lineup
