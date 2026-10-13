-- Minimal test runner for pure-logic modules. Run with: lune run tests/run
local fs = require("@lune/fs")
local process = require("@lune/process")

local passed, failed = 0, 0

local function makeCtx(prefix: string)
	return {
		test = function(name: string, fn: () -> ())
			local ok, err = pcall(fn)
			if ok then
				passed += 1
			else
				failed += 1
				print(`FAIL {prefix} > {name}\n    {err}`)
			end
		end,
		expect = function(actual: any, expected: any)
			if actual ~= expected then
				error(`expected {tostring(expected)}, got {tostring(actual)}`, 2)
			end
		end,
	}
end

for _, file in fs.readDir("tests") do
	local name = string.match(file, "^(.+)%.spec%.luau$")
	if name then
		local spec = require(`./{name}.spec`) :: any
		spec(makeCtx(name))
	end
end

print(`{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
