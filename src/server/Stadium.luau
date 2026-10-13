-- A low-effort stadium around the pitch: stepped stands on all four sides
-- with a back wall and roof edge, advertising boards along the lines, and
-- four floodlight towers. Plain blocks in muted colours with one accent.
-- build() returns seat spots for the crowd.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pitch = require(script.Parent.Pitch)
local Stage = require(ReplicatedStorage.Shared.Stage)

local SEAT = Color3.fromRGB(62, 72, 92)
local SEAT_ALT = Color3.fromRGB(78, 90, 112)
local CONCRETE = Color3.fromRGB(150, 152, 158)
local ROOF = Color3.fromRGB(95, 100, 110)
local ACCENT = Color3.fromRGB(255, 200, 40)
local BOARD = Color3.fromRGB(30, 36, 48)
local AD_TEXT = { "PENALTY CUP", "BUILDER1", "SHOOTOUT", "GOAL!" }

local MARGIN = 24 -- grass between the lines and the first row
local TIERS = 8
local TIER_DEPTH = 4
local TIER_RISE = 2.4
local SEAT_SPACING = 5

local Stadium = {}

local part = Pitch.part

-- One stand. `origin` is the front-centre at ground level, `inward` points
-- at the pitch, `length` runs along the front. Returns seat CFrames.
local function stand(parent: Instance, origin: Vector3, inward: Vector3, length: number): { CFrame }
	local model = Instance.new("Model")
	model.Name = "Stand"
	model.Parent = parent
	local back = -inward
	local frame = CFrame.lookAt(origin, origin + inward) -- -Z = towards the pitch
	local seats = {}

	for i = 0, TIERS - 1 do
		local height = (i + 1) * TIER_RISE
		local centre = origin + back * (i * TIER_DEPTH + TIER_DEPTH / 2) + Vector3.yAxis * (height / 2)
		part(
			model,
			"Tier",
			Vector3.new(length, height, TIER_DEPTH),
			CFrame.lookAt(centre, centre + inward),
			if i % 2 == 0 then SEAT else SEAT_ALT,
			{ Material = Enum.Material.Concrete }
		)
		-- Seat spots along the top of this tier, facing the pitch.
		if i > 0 then
			for along = -length / 2 + SEAT_SPACING, length / 2 - SEAT_SPACING, SEAT_SPACING do
				local p = frame * Vector3.new(along, 0, i * TIER_DEPTH + TIER_DEPTH / 2)
				local seatPos = Vector3.new(p.X, height, p.Z)
				table.insert(seats, CFrame.lookAt(seatPos, seatPos + inward))
			end
		end
	end

	local top = TIERS * TIER_RISE
	local depth = TIERS * TIER_DEPTH
	local wallPos = origin + back * (depth + 1) + Vector3.yAxis * ((top + 8) / 2)
	part(model, "BackWall", Vector3.new(length, top + 8, 2), CFrame.lookAt(wallPos, wallPos + inward), CONCRETE, {
		Material = Enum.Material.Concrete,
	})
	-- Roof slab over the back half, with an accent strip on its front edge.
	local roofPos = origin + back * (depth * 0.55) + Vector3.yAxis * (top + 9)
	local roofFrame = CFrame.lookAt(roofPos, roofPos + inward) * CFrame.Angles(math.rad(-6), 0, 0)
	part(model, "Roof", Vector3.new(length, 1, depth * 0.95), roofFrame, ROOF, { Material = Enum.Material.Metal })
	part(
		model,
		"RoofEdge",
		Vector3.new(length, 1.2, 0.6),
		roofFrame * CFrame.new(0, -0.2, -depth * 0.475),
		ACCENT,
		{ Material = Enum.Material.SmoothPlastic }
	)
	return seats
end

-- A row of advertising boards facing the pitch.
local function boards(parent: Instance, from: Vector3, to: Vector3, inward: Vector3, offset: number): number
	local length = (to - from).Magnitude
	local count = math.max(1, math.floor(length / 24))
	local step = (to - from) / count
	for i = 0, count - 1 do
		local pos = from + step * (i + 0.5) + Vector3.yAxis * 1.25
		local board = part(
			parent,
			"Board",
			Vector3.new(step.Magnitude - 0.4, 2.5, 0.4),
			CFrame.lookAt(pos, pos + inward),
			BOARD,
			{ CanCollide = false }
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.PixelsPerStud = 20
		gui.Parent = board
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = if (i + offset) % 2 == 0 then ACCENT else Color3.new(1, 1, 1)
		text.Text = AD_TEXT[(i + offset) % #AD_TEXT + 1]
		text.Parent = gui
	end
	return count
end

-- A tall pole with a glowing lamp bank facing the pitch.
local function floodlight(parent: Instance, base: Vector3, target: Vector3)
	local height = 70
	part(parent, "Pole", Vector3.new(2, height, 2), CFrame.new(base + Vector3.yAxis * height / 2), CONCRETE, {
		Material = Enum.Material.Metal,
	})
	local headPos = base + Vector3.yAxis * (height + 4)
	local head =
		part(parent, "Lamps", Vector3.new(16, 8, 1.5), CFrame.lookAt(headPos, target), Color3.new(1, 1, 0.94), {
			Material = Enum.Material.Neon,
		})
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Range = 60
	light.Angle = 80
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 248, 235)
	light.Parent = head
end

-- Builds the stadium under workspace.Stadium. Returns seat CFrames.
function Stadium.build(): { CFrame }
	local old = workspace:FindFirstChild("Stadium")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "Stadium"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local w, len = Stage.PITCH_HALF_WIDTH, Stage.PITCH_LENGTH
	local sideX = w + MARGIN
	local endGap = MARGIN + 4 -- room for the goal net
	local sideLength = len + endGap * 2
	local endLength = sideX * 2

	local seats = {}
	local function add(list)
		for _, seat in list do
			table.insert(seats, seat)
		end
	end
	add(stand(folder, Vector3.new(sideX, 0, len / 2), -Vector3.xAxis, sideLength))
	add(stand(folder, Vector3.new(-sideX, 0, len / 2), Vector3.xAxis, sideLength))
	add(stand(folder, Vector3.new(0, 0, -endGap), Vector3.zAxis, endLength))
	add(stand(folder, Vector3.new(0, 0, len + endGap), -Vector3.zAxis, endLength))

	-- Advertising boards just outside the lines.
	local boardOffset = 0
	boardOffset += boards(folder, Vector3.new(w + 6, 0, 0), Vector3.new(w + 6, 0, len), -Vector3.xAxis, boardOffset)
	boardOffset += boards(folder, Vector3.new(-w - 6, 0, 0), Vector3.new(-w - 6, 0, len), Vector3.xAxis, boardOffset)
	boardOffset += boards(folder, Vector3.new(-w, 0, -10), Vector3.new(w, 0, -10), Vector3.zAxis, boardOffset)
	boards(folder, Vector3.new(-w, 0, len + 10), Vector3.new(w, 0, len + 10), -Vector3.zAxis, boardOffset)

	-- Floodlights at the four corners, aimed at the middle of the pitch.
	local centre = Vector3.new(0, 0, len / 2)
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local base = Vector3.new(corner[1] * (sideX + 40), 0, if corner[2] < 0 then -endGap - 30 else len + endGap + 30)
		floodlight(folder, base, centre)
	end

	folder.Parent = workspace
	return seats
end

return Stadium
