-- End-of-match panel: winner, score, kick dots, stats and a Rematch button.

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
local onRematch: () -> ()
local againButton: TextButton
local waitingLabel: TextLabel

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

function ResultScreen.init(rematchHandler: () -> ())
	onRematch = rematchHandler

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
	againButton = again
	again.Name = "Rematch"
	again.AnchorPoint = Vector2.new(0.5, 1)
	again.Position = UDim2.new(0.5, 0, 1, -14)
	again.Size = UDim2.fromOffset(200, 40)
	again.BackgroundColor3 = ACCENT
	again.Font = FONT
	again.Text = "REMATCH"
	again.TextSize = 18
	again.TextColor3 = PANEL_COLOR
	corner(again, 8)
	again.Parent = panel
	again.Activated:Connect(function()
		onRematch()
	end)

	waitingLabel = text(panel, "", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 1, -54), 16, {
		Font = BODY_FONT,
		Visible = false,
	})

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- names: p1/p2 display names; you: this client's slot (nil for spectators).
function ResultScreen.show(summary: any, names: { [string]: string? }, you: string?)
	content:ClearAllChildren()
	local function name(side: string): string
		return if side == you then "You" else (names[side] or "Opponent")
	end
	local winner = summary.winner
	local title = if winner == nil
		then "MATCH OVER"
		elseif winner == you then "YOU WIN!"
		elseif you then "YOU LOSE"
		else `{name(winner)} WINS`
	local won = winner ~= nil and winner == you

	text(content, title, UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 14), 36, {
		TextColor3 = if won then GOAL_COLOR elseif you then FAIL_COLOR else Color3.new(1, 1, 1),
	})
	text(
		content,
		`{name("p1")} {summary.scores.p1} - {summary.scores.p2} {name("p2")}`,
		UDim2.new(1, -20, 0, 30),
		UDim2.fromOffset(10, 58),
		22,
		{ TextScaled = true }
	)
	if summary.suddenDeath then
		text(content, "after sudden death", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 88), 14, {
			Font = BODY_FONT,
			TextColor3 = ACCENT,
		})
	end

	dots(content, name("p1"), summary.p1.kicks, 116)
	dots(content, name("p2"), summary.p2.kicks, 140)

	text(content, name("p1"), UDim2.fromOffset(60, 18), UDim2.new(1, -150, 0, 176), 13, { TextScaled = true })
	text(content, name("p2"), UDim2.fromOffset(60, 18), UDim2.new(1, -90, 0, 176), 13, { TextScaled = true })
	for i, stat in STAT_ROWS do
		local y = 176 + i * 24
		text(content, stat[1], UDim2.fromOffset(200, 18), UDim2.fromOffset(30, y), 15, {
			Font = BODY_FONT,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		text(content, tostring(summary.p1[stat[2]]), UDim2.fromOffset(60, 18), UDim2.new(1, -150, 0, y), 15)
		text(content, tostring(summary.p2[stat[2]]), UDim2.fromOffset(60, 18), UDim2.new(1, -90, 0, y), 15)
	end

	ResultScreen.setWaiting(nil)
	gui.Enabled = true
end

-- Replaces the Rematch button with a message (e.g. waiting for the other
-- player), or brings the button back when text is nil.
function ResultScreen.setWaiting(message: string?)
	againButton.Visible = message == nil
	waitingLabel.Visible = message ~= nil
	waitingLabel.Text = message or ""
end

function ResultScreen.hide()
	gui.Enabled = false
end

return ResultScreen
