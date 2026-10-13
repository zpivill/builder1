-- Uploads one asset to Roblox via Open Cloud.
-- Usage: lune run scripts/upload <file> <name> --user <id> | --group <id>
-- The API key is read from the ROBLOX_API_KEY env var and is never printed or logged.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local API = "https://apis.roblox.com/assets/v1/"

local KEY = process.env.ROBLOX_API_KEY
if not KEY or KEY == "" then
	print("ROBLOX_API_KEY is missing")
	process.exit(1)
end

-- Strip the key from any text before it is shown, in case a response echoes it.
local function redact(text: string): string
	local escaped = string.gsub(KEY, "%p", "%%%0")
	return (string.gsub(text, escaped, "[REDACTED]"))
end

local function fail(msg: string)
	print(redact(msg))
	process.exit(1)
end

local TYPES = {
	png = { "Decal", "image/png" },
	jpg = { "Decal", "image/jpeg" },
	jpeg = { "Decal", "image/jpeg" },
	bmp = { "Decal", "image/bmp" },
	tga = { "Decal", "image/tga" },
	rbxm = { "Model", "model/x-rbxm" },
	fbx = { "Model", "model/fbx" },
}

local args = process.args
local path, name, flag, id = args[1], args[2], args[3], args[4]
if not (path and name and (flag == "--user" or flag == "--group") and tonumber(id)) then
	fail("Usage: lune run scripts/upload <file> <name> --user <id> | --group <id>")
end

local ext = string.lower(string.match(path, "%.(%w+)$") or "")
local kind = TYPES[ext]
if not kind then
	fail("Unsupported file type: ." .. ext)
end
if not fs.isFile(path) then
	fail("File not found: " .. path)
end

local creator = if flag == "--user" then { userId = id } else { groupId = id }
local requestJson = serde.encode("json", {
	assetType = kind[1],
	displayName = name,
	description = "Uploaded by builder1 scripts/upload.luau",
	creationContext = { creator = creator },
})

local boundary = "----builder1" .. tostring(math.random(1e9))
local fileName = string.match(path, "[^/\\]+$")
local body = table.concat({
	"--" .. boundary,
	'Content-Disposition: form-data; name="request"',
	"Content-Type: application/json",
	"",
	requestJson,
	"--" .. boundary,
	'Content-Disposition: form-data; name="fileContent"; filename="' .. fileName .. '"',
	"Content-Type: " .. kind[2],
	"",
	fs.readFile(path),
	"--" .. boundary .. "--",
	"",
}, "\r\n")

local res = net.request({
	url = API .. "assets",
	method = "POST",
	headers = {
		["x-api-key"] = KEY,
		["content-type"] = "multipart/form-data; boundary=" .. boundary,
	},
	body = body,
})
if not res.ok then
	fail(`Upload failed ({res.statusCode}): {res.body}`)
end

-- The upload is asynchronous; poll the operation until it finishes.
local op = serde.decode("json", res.body)
for _ = 1, 30 do
	if op.done then
		break
	end
	task.wait(2)
	local poll = net.request({
		url = API .. op.path,
		headers = { ["x-api-key"] = KEY },
	})
	if not poll.ok then
		fail(`Polling failed ({poll.statusCode}): {poll.body}`)
	end
	op = serde.decode("json", poll.body)
end

if not op.done then
	fail("Timed out waiting for the upload to finish: " .. tostring(op.path))
end
if op.error then
	fail("Upload error: " .. serde.encode("json", op.error))
end
print(`Uploaded {kind[1]} "{name}": rbxassetid://{op.response.assetId}`)
