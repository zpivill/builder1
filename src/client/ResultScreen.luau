-- End-of-match panel: winner, score, kick dots, stats and a Play again button.

local Players = game:GetService("Players")

local GOAL_COLOR = Color3.fromRGB(70, 200, 90)
local FAIL_COLOR = Color3.fromRGB(220, 60, 60)
local PANEL_COLOR = Color3.fromRGB(20, 24, 32)
local ACCENT = Color3.fromRGB(255, 200, 40)
local FONT = Enum.Font.GothamBold
local BODY_FONT = Enum.Font.Gotham

local STAT_ROWS = {
	{ "Goals", "goals" },
	{ "Shots saved", "saved" },
	{ "Missed", "missed" },
	{ "Hit the post", "post" },
}

local ResultScreen = {}

local gui: ScreenGui
local content: Frame
local onPlayAgain: () -> ()

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(
	parent: Instance,
	value: string,
	size: UDim2,
	pos: UDim2,
	textSize: number,
	opts: { [string]: any }?
)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.Text = value
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Size = size
	l.Position = pos
	for key, v in opts or {} do
		(l :: any)[key] = v
	end
	l.Parent = parent
	return l
end

local function dots(parent: Instance, label: string, kicks: { string }, y: number)
	text(parent, label, UDim2.fromOffset(50, 18), UDim2.fromOffset(30, y), 14, {
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for i, outcome in kicks do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(16, 16)
		dot.Position = UDim2.fromOffset(84 + (i - 1) * 22, y + 1)
		dot.BackgroundColor3 = if outcome == "GOAL" then GOAL_COLOR else FAIL_COLOR
		corner(dot, 8)
		dot.Parent = parent
	end
end

function ResultScreen.init(playAgainHandler: () -> ())
	onPlayAgain = playAgainHandler

	gui = Instance.new("ScreenGui")
	gui.Name = "ResultScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.DisplayOrder = 10

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 380)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.08
	corner(panel, 12)
	panel.Parent = gui

	content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, 0, 1, -60)
	content.Parent = panel

	local again = Instance.new("TextButton")
	again.Name = "PlayAgain"
	again.AnchorPoint = Vector2.new(0.5, 1)
	again.Position = UDim2.new(0.5, 0, 1, -14)
	again.Size = UDim2.fromOffset(200, 40)
	again.BackgroundColor3 = ACCENT
	again.Font = FONT
	again.Text = "PLAY AGAIN"
	again.TextSize = 18
	again.TextColor3 = PANEL_COLOR
	corner(again, 8)
	again.Parent = panel
	again.Activated:Connect(function()
		gui.Enabled = false
		onPlayAgain()
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function ResultScreen.show(summary: any)
	content:ClearAllChildren()
	local won = summary.winner == "player"

	text(content, if won then "YOU WIN!" else "AI WINS", UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 14), 36, {
		TextColor3 = if won then GOAL_COLOR else FAIL_COLOR,
	})
	text(
		content,
		`YOU {summary.scores.player} - {summary.scores.ai} AI`,
		UDim2.new(1, 0, 0, 30),
		UDim2.fromOffset(0, 58),
		24
	)
	if summary.suddenDeath then
		text(content, "after sudden death", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 86), 14, {
			Font = BODY_FONT,
			TextColor3 = ACCENT,
		})
	end

	dots(content, "YOU", summary.player.kicks, 116)
	dots(content, "AI", summary.ai.kicks, 140)

	text(content, "YOU", UDim2.fromOffset(60, 18), UDim2.new(1, -150, 0, 176), 14)
	text(content, "AI", UDim2.fromOffset(60, 18), UDim2.new(1, -90, 0, 176), 14)
	for i, stat in STAT_ROWS do
		local y = 176 + i * 24
		text(content, stat[1], UDim2.fromOffset(200, 18), UDim2.fromOffset(30, y), 15, {
			Font = BODY_FONT,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		text(content, tostring(summary.player[stat[2]]), UDim2.fromOffset(60, 18), UDim2.new(1, -150, 0, y), 15)
		text(content, tostring(summary.ai[stat[2]]), UDim2.fromOffset(60, 18), UDim2.new(1, -90, 0, y), 15)
	end

	gui.Enabled = true
end

function ResultScreen.hide()
	gui.Enabled = false
end

return ResultScreen
