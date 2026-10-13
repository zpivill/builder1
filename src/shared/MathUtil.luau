--!strict
-- Pure logic only: no Roblox APIs, so it can be tested with Lune.
local MathUtil = {}

function MathUtil.clamp(value: number, min: number, max: number): number
	if value < min then
		return min
	elseif value > max then
		return max
	end
	return value
end

return MathUtil
