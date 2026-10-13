-- Seedable Park-Miller RNG so shot results are repeatable in tests.
-- Products stay below 2^53, so plain number math is exact.

local MODULUS = 2147483647
local MULTIPLIER = 48271

export type Rng = {
	next: (self: Rng) -> number,
	int: (self: Rng, min: number, max: number) -> number,
	_state: number,
}

local Rng = {}
Rng.__index = Rng

function Rng.new(seed: number): Rng
	local state = math.floor(math.abs(seed)) % MODULUS
	if state == 0 then
		state = 1
	end
	return (setmetatable({ _state = state }, Rng) :: any) :: Rng
end

-- Returns a number in [0, 1).
function Rng.next(self: Rng): number
	self._state = (self._state * MULTIPLIER) % MODULUS
	return (self._state - 1) / (MODULUS - 1)
end

-- Returns an integer in [min, max].
function Rng.int(self: Rng, min: number, max: number): number
	return min + math.floor(self:next() * (max - min + 1))
end

return Rng
