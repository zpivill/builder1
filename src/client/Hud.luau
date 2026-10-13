-- Score HUD and the hidden-choice controls. The shooter gets an aim grid and
-- an oscillating power bar; the keeper gets a dive grid. Both see a countdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local config = require(ReplicatedStorage.Shared.config)

local GOAL_COLOR = Color3.fromRGB(70, 200, 90)
local FAIL_COLOR = Color3.fromRGB(220, 60, 60)
local PANEL_COLOR = Color3.fromRGB(20, 24, 32)
local ACCENT = Color3.fromRGB(255, 200, 40)
local FONT = Enum.Font.GothamBold

-- Grid columns in on-screen order. The shooter looks at the goal, the keeper
-- looks out from it, so the keeper's screen is mirrored.
local SCREEN_COLUMNS = {
	shooter = { "left", "centre", "right" },
	keeper = { "right", "centre", "left" },
}

local Hud = {}

local gui: ScreenGui
local scoreLabel: TextLabel
local statusLabel: TextLabel
local centreLabel: TextLabel
local resultLabel: TextLabel
local dotRows: { [string]: Frame } = {}
local dotTags: { [string]: TextLabel } = {}
local controls: Frame
local titleLabel: TextLabel
local timerLabel: TextLabel
local powerBar: Frame
local powerFill: Frame
local actionButton: TextButton
local cells: { TextButton } = {}

local role: string? = nil -- "shooter" | "keeper" while choosing
local deadline = 0
local zone = { column = "centre", height = "low" }
local power = 0
local elapsed = 0
local onChoose: (choice: any) -> ()

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.Text = text
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.Size = size
	l.Position = pos
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Parent = parent
	return l
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function buildScore()
	local panel = Instance.new("Frame")
	panel.Name = "Score"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 8)
	panel.Size = UDim2.fromOffset(340, 92)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.25
	corner(panel, 10)
	panel.Parent = gui

	scoreLabel = label(panel, "", UDim2.new(1, -20, 0, 36), UDim2.new(0.5, 0, 0, 4), 24)
	scoreLabel.TextScaled = true

	for i, side in { "p1", "p2" } do
		local row = Instance.new("Frame")
		row.Name = side .. "Dots"
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -20, 0, 18)
		row.Position = UDim2.fromOffset(10, 22 + i * 22)
		row.Parent = panel

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = row

		local tag = Instance.new("TextLabel")
		tag.BackgroundTransparency = 1
		tag.Font = FONT
		tag.TextSize = 13
		tag.TextColor3 = Color3.new(1, 1, 1)
		tag.TextXAlignment = Enum.TextXAlignment.Left
		tag.TextTruncate = Enum.TextTruncate.AtEnd
		tag.Size = UDim2.fromOffset(96, 18)
		tag.LayoutOrder = 0
		tag.Parent = row
		dotRows[side] = row
		dotTags[side] = tag
	end

	statusLabel = label(gui, "", UDim2.fromOffset(500, 30), UDim2.new(0.5, 0, 0, 106), 20)
end

local function buildControls()
	controls = Instance.new("Frame")
	controls.Name = "Controls"
	controls.AnchorPoint = Vector2.new(1, 1)
	controls.Position = UDim2.new(1, -12, 1, -12)
	controls.Size = UDim2.fromOffset(340, 180)
	controls.BackgroundColor3 = PANEL_COLOR
	controls.BackgroundTransparency = 0.25
	corner(controls, 10)
	controls.Parent = gui

	titleLabel = label(controls, "", UDim2.fromOffset(260, 22), UDim2.fromOffset(140, 6), 16)
	timerLabel = label(controls, "", UDim2.fromOffset(50, 22), UDim2.new(1, -30, 0, 6), 18)
	timerLabel.TextColor3 = ACCENT

	-- 3 x 2 grid of zones: a mini goal.
	local grid = Instance.new("Frame")
	grid.Name = "Zones"
	grid.Position = UDim2.fromOffset(12, 36)
	grid.Size = UDim2.fromOffset(210, 90)
	grid.BackgroundColor3 = Color3.fromRGB(40, 90, 50)
	grid.BorderSizePixel = 0
	grid.Parent = controls
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.Parent = grid

	for ci = 1, 3 do
		for hi, height in { "high", "low" } do
			local b = Instance.new("TextButton")
			b.Name = `Zone{ci}_{height}`
			b.Text = ""
			b.BackgroundColor3 = Color3.new(1, 1, 1)
			b.BackgroundTransparency = 0.85
			b.BorderSizePixel = 0
			b.Size = UDim2.new(1 / 3, -4, 0.5, -4)
			b.Position = UDim2.new((ci - 1) / 3, 2, (hi - 1) / 2, 2)
			b:SetAttribute("ScreenColumn", ci)
			b:SetAttribute("Height", height)
			b.Parent = grid
			b.Activated:Connect(function()
				zone = { column = SCREEN_COLUMNS[role or "shooter"][ci], height = height }
				Hud.refreshZones()
			end)
			table.insert(cells, b)
		end
	end

	label(controls, "Pick a spot, then lock in (Space)", UDim2.fromOffset(320, 20), UDim2.new(0.5, 0, 0, 134), 13)

	-- Power bar fills upward and keeps oscillating until the kick is locked in.
	powerBar = Instance.new("Frame")
	powerBar.Name = "Power"
	powerBar.Position = UDim2.fromOffset(236, 36)
	powerBar.Size = UDim2.fromOffset(24, 90)
	powerBar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	powerBar.BorderSizePixel = 0
	corner(powerBar, 6)
	powerBar.Parent = controls

	powerFill = Instance.new("Frame")
	powerFill.AnchorPoint = Vector2.new(0, 1)
	powerFill.Position = UDim2.fromScale(0, 1)
	powerFill.Size = UDim2.fromScale(1, 0)
	powerFill.BackgroundColor3 = ACCENT
	powerFill.BorderSizePixel = 0
	corner(powerFill, 6)
	powerFill.Parent = powerBar

	actionButton = Instance.new("TextButton")
	actionButton.Name = "LockIn"
	actionButton.Position = UDim2.fromOffset(270, 36)
	actionButton.Size = UDim2.fromOffset(58, 90)
	actionButton.BackgroundColor3 = ACCENT
	actionButton.Font = FONT
	actionButton.TextSize = 15
	actionButton.TextColor3 = PANEL_COLOR
	corner(actionButton, 8)
	actionButton.Parent = controls
	actionButton.Activated:Connect(function()
		Hud.lockIn()
	end)
end

function Hud.init(chooseHandler: (choice: any) -> ())
	onChoose = chooseHandler

	gui = Instance.new("ScreenGui")
	gui.Name = "ShootoutHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	buildScore()
	buildControls()
	resultLabel = label(gui, "", UDim2.fromOffset(600, 80), UDim2.fromScale(0.5, 0.33), 60)
	centreLabel = label(gui, "", UDim2.fromOffset(600, 40), UDim2.fromScale(0.5, 0.45), 28)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Hud.closeChoice()

	RunService.RenderStepped:Connect(function(dt)
		if not role then
			return
		end
		local left = math.max(0, math.ceil(deadline - workspace:GetServerTimeNow()))
		timerLabel.Text = tostring(left)
		if role == "shooter" then
			elapsed += dt
			-- Triangle wave 0 -> 100 -> 0.
			local phase = (elapsed * config.powerBarCyclesPerSecond) % 1
			power = math.floor((1 - math.abs(phase * 2 - 1)) * 100 + 0.5)
			powerFill.Size = UDim2.fromScale(1, power / 100)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Space then
			Hud.lockIn()
		end
	end)
end

function Hud.refreshZones()
	local columns = SCREEN_COLUMNS[role or "shooter"]
	for _, b in cells do
		local column = columns[b:GetAttribute("ScreenColumn") :: number]
		local selected = column == zone.column and b:GetAttribute("Height") == zone.height
		b.BackgroundColor3 = if selected then ACCENT else Color3.new(1, 1, 1)
		b.BackgroundTransparency = if selected then 0.2 else 0.85
	end
end

-- Opens the controls for this kick. role: "shooter" | "keeper".
function Hud.openChoice(newRole: string, newDeadline: number)
	role, deadline = newRole, newDeadline
	zone = { column = "centre", height = "low" }
	elapsed = 0
	titleLabel.Text = if newRole == "shooter" then "Aim your shot" else "Pick your dive"
	powerBar.Visible = newRole == "shooter"
	actionButton.Text = if newRole == "shooter" then "KICK" else "DIVE"
	controls.Visible = true
	Hud.refreshZones()
end

function Hud.closeChoice()
	role = nil
	controls.Visible = false
end

function Hud.isChoosing(): boolean
	return role ~= nil
end

function Hud.lockIn()
	if not role then
		return
	end
	local choice = { column = zone.column, height = zone.height }
	if role == "shooter" then
		choice.power = power
	end
	Hud.closeChoice()
	onChoose(choice)
end

function Hud.setVisible(on: boolean)
	gui.Enabled = on
end

function Hud.setNames(names: { [string]: string? }, you: string?)
	for side, tag in dotTags do
		tag.Text = if side == you then "You" else (names[side] or "...")
	end
end

function Hud.setScore(state: any, names: { [string]: string? }, you: string?)
	local function name(side: string)
		return if side == you then "You" else (names[side] or "...")
	end
	scoreLabel.Text = `{name("p1")} {state.scores.p1} - {state.scores.p2} {name("p2")}`
end

function Hud.setStatus(text: string)
	statusLabel.Text = text
end

function Hud.setCentre(text: string)
	centreLabel.Text = text
end

function Hud.clearDots()
	for _, row in dotRows do
		for _, child in row:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end
end

function Hud.addDot(side: string, outcome: string)
	local row = dotRows[side]
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(16, 16)
	dot.BackgroundColor3 = if outcome == "GOAL" then GOAL_COLOR else FAIL_COLOR
	dot.LayoutOrder = #row:GetChildren()
	corner(dot, 8)
	dot.Parent = row
end

function Hud.showResult(text: string, color: Color3?)
	resultLabel.Text = text
	resultLabel.TextColor3 = color or Color3.new(1, 1, 1)
end

Hud.GOAL_COLOR = GOAL_COLOR
Hud.FAIL_COLOR = FAIL_COLOR

return Hud
