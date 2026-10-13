-- Score HUD and kick controls (aim grid, oscillating power bar, kick button).

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

local Hud = {}

local gui: ScreenGui
local scoreLabel: TextLabel
local statusLabel: TextLabel
local lineupLabel: TextLabel
local resultLabel: TextLabel
local dotRows: { [string]: Frame } = {}
local controls: Frame
local powerFill: Frame
local aimButtons: { [string]: TextButton } = {}

local enabled = false
local aim = { column = "centre", height = "low" }
local power = 0
local elapsed = 0
local onKick: (shot: any) -> ()

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
	panel.Size = UDim2.fromOffset(300, 92)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.25
	corner(panel, 10)
	panel.Parent = gui

	scoreLabel = label(panel, "YOU 0 - 0 AI", UDim2.new(1, 0, 0, 36), UDim2.new(0.5, 0, 0, 4), 28)

	for i, side in { "player", "ai" } do
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
		tag.TextSize = 14
		tag.TextColor3 = Color3.new(1, 1, 1)
		tag.TextXAlignment = Enum.TextXAlignment.Left
		tag.Text = if side == "player" then "YOU" else "AI"
		tag.Size = UDim2.fromOffset(34, 18)
		tag.LayoutOrder = 0
		tag.Parent = row
		dotRows[side] = row
	end

	statusLabel = label(gui, "", UDim2.fromOffset(400, 30), UDim2.new(0.5, 0, 0, 106), 22)
	lineupLabel = label(gui, "", UDim2.fromOffset(500, 20), UDim2.new(0.5, 0, 0, 134), 15)
end

local function buildControls()
	controls = Instance.new("Frame")
	controls.Name = "Controls"
	controls.AnchorPoint = Vector2.new(1, 1)
	controls.Position = UDim2.new(1, -12, 1, -12)
	controls.Size = UDim2.fromOffset(340, 150)
	controls.BackgroundColor3 = PANEL_COLOR
	controls.BackgroundTransparency = 0.25
	corner(controls, 10)
	controls.Parent = gui

	-- Aim grid: a mini goal with 3 columns x 2 heights.
	local grid = Instance.new("Frame")
	grid.Name = "Aim"
	grid.Position = UDim2.fromOffset(12, 12)
	grid.Size = UDim2.fromOffset(210, 90)
	grid.BackgroundColor3 = Color3.fromRGB(40, 90, 50)
	grid.BorderSizePixel = 0
	grid.Parent = controls
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.Parent = grid

	for ci, column in { "left", "centre", "right" } do
		for hi, height in { "high", "low" } do
			local b = Instance.new("TextButton")
			b.Name = column .. "_" .. height
			b.Text = ""
			b.AutoButtonColor = true
			b.BackgroundColor3 = Color3.new(1, 1, 1)
			b.BackgroundTransparency = 0.85
			b.BorderSizePixel = 0
			b.Size = UDim2.new(1 / 3, -4, 0.5, -4)
			b.Position = UDim2.new((ci - 1) / 3, 2, (hi - 1) / 2, 2)
			b.Parent = grid
			b.Activated:Connect(function()
				aim = { column = column, height = height }
				Hud.refreshAim()
			end)
			aimButtons[b.Name] = b
		end
	end

	label(controls, "Pick a spot, then KICK (Space)", UDim2.fromOffset(320, 20), UDim2.new(0.5, 0, 0, 110), 14)

	-- Power bar fills upward and keeps oscillating until kicked.
	local bar = Instance.new("Frame")
	bar.Name = "Power"
	bar.Position = UDim2.fromOffset(236, 12)
	bar.Size = UDim2.fromOffset(24, 90)
	bar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	bar.BorderSizePixel = 0
	corner(bar, 6)
	bar.Parent = controls

	powerFill = Instance.new("Frame")
	powerFill.AnchorPoint = Vector2.new(0, 1)
	powerFill.Position = UDim2.fromScale(0, 1)
	powerFill.Size = UDim2.fromScale(1, 0)
	powerFill.BackgroundColor3 = ACCENT
	powerFill.BorderSizePixel = 0
	corner(powerFill, 6)
	powerFill.Parent = bar

	local kick = Instance.new("TextButton")
	kick.Name = "Kick"
	kick.Position = UDim2.fromOffset(270, 12)
	kick.Size = UDim2.fromOffset(58, 90)
	kick.BackgroundColor3 = ACCENT
	kick.Font = FONT
	kick.Text = "KICK"
	kick.TextSize = 16
	kick.TextColor3 = PANEL_COLOR
	corner(kick, 8)
	kick.Parent = controls
	kick.Activated:Connect(function()
		Hud.kick()
	end)
end

function Hud.init(kickHandler: (shot: any) -> ())
	onKick = kickHandler

	gui = Instance.new("ScreenGui")
	gui.Name = "ShootoutHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	buildScore()
	buildControls()
	resultLabel = label(gui, "", UDim2.fromOffset(600, 80), UDim2.fromScale(0.5, 0.35), 64)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Hud.refreshAim()
	Hud.setControlsEnabled(false)

	RunService.RenderStepped:Connect(function(dt)
		if not enabled then
			return
		end
		elapsed += dt
		-- Triangle wave 0 -> 100 -> 0.
		local phase = (elapsed * config.powerBarCyclesPerSecond) % 1
		power = math.floor((1 - math.abs(phase * 2 - 1)) * 100 + 0.5)
		powerFill.Size = UDim2.fromScale(1, power / 100)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Space then
			Hud.kick()
		end
	end)
end

function Hud.refreshAim()
	for name, b in aimButtons do
		local selected = name == aim.column .. "_" .. aim.height
		b.BackgroundColor3 = if selected then ACCENT else Color3.new(1, 1, 1)
		b.BackgroundTransparency = if selected then 0.2 else 0.85
	end
end

function Hud.kick()
	if not enabled then
		return
	end
	Hud.setControlsEnabled(false)
	onKick({ column = aim.column, height = aim.height, power = power })
end

function Hud.setControlsEnabled(on: boolean)
	enabled = on
	elapsed = 0
	controls.Visible = on
end

function Hud.setState(state: any)
	scoreLabel.Text = `YOU {state.scores.player} - {state.scores.ai} AI`
	if state.finished then
		statusLabel.Text = ""
	else
		local who = if state.nextSide == "player" then "Your kick" else "AI is shooting..."
		local stage = if state.suddenDeath then "Sudden death" else `Round {state.round} of {config.rounds}`
		statusLabel.Text = `{stage}  |  {who}`
	end
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

function Hud.setVisible(on: boolean)
	gui.Enabled = on
end

function Hud.setLineups(lineups: any)
	local p, a = lineups.player, lineups.ai
	lineupLabel.Text = `{p.shooter} + {p.keeper}  vs  {a.shooter} + {a.keeper}`
end

function Hud.showResult(text: string, color: Color3)
	resultLabel.Text = text
	resultLabel.TextColor3 = color
end

Hud.GOAL_COLOR = GOAL_COLOR
Hud.FAIL_COLOR = FAIL_COLOR
Hud.ACCENT = ACCENT

return Hud
