-- Pre-match screen: pick one shooter and one keeper from the presets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage.Shared.config)

local PANEL_COLOR = Color3.fromRGB(20, 24, 32)
local CARD_COLOR = Color3.fromRGB(38, 44, 58)
local ACCENT = Color3.fromRGB(255, 200, 40)
local FONT = Enum.Font.GothamBold
local BODY_FONT = Enum.Font.Gotham

local PickScreen = {}

local gui: ScreenGui
local startButton: TextButton
local cards: { shooter: { Frame }, keeper: { Frame } } = { shooter = {}, keeper = {} }
local picked: { shooter: number?, keeper: number? } = {}
local onStart: (choice: { shooter: number, keeper: number }) -> ()

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, value: string, size: UDim2, pos: UDim2, textSize: number, font: Enum.Font?)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font or FONT
	l.Text = value
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Size = size
	l.Position = pos
	l.Parent = parent
	return l
end

local function statBar(parent: Instance, name: string, value: number, y: number)
	text(parent, name, UDim2.fromOffset(80, 16), UDim2.fromOffset(12, y), 13, BODY_FONT)
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(92, y + 3)
	back.Size = UDim2.new(1, -140, 0, 10)
	back.BackgroundColor3 = Color3.fromRGB(60, 66, 80)
	back.BorderSizePixel = 0
	corner(back, 5)
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(value / 100, 1)
	fill.BackgroundColor3 = ACCENT
	fill.BorderSizePixel = 0
	corner(fill, 5)
	fill.Parent = back
	text(parent, tostring(value), UDim2.fromOffset(36, 16), UDim2.new(1, -42, 0, y), 13)
end

function PickScreen.refresh()
	for kind, list in cards do
		for i, card in list do
			local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
			local selected = picked[kind] == i
			stroke.Transparency = if selected then 0 else 1
			card.BackgroundColor3 = if selected then Color3.fromRGB(60, 56, 30) else CARD_COLOR
		end
	end
	local ready = picked.shooter ~= nil and picked.keeper ~= nil
	startButton.Active = ready
	startButton.AutoButtonColor = ready
	startButton.BackgroundTransparency = if ready then 0 else 0.6
end

local function card(parent: Instance, kind: "shooter" | "keeper", index: number, preset: any, x: number)
	local c = Instance.new("TextButton")
	c.Name = `{kind}{index}`
	c.Text = ""
	c.AutoButtonColor = false
	c.Position = UDim2.new(x, if x == 0 then 0 else 8, 0, 0)
	c.Size = UDim2.new(0.5, -4, 1, 0)
	c.BackgroundColor3 = CARD_COLOR
	corner(c, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Color = ACCENT
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = c
	c.Parent = parent

	text(c, preset.name, UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 8), 20)
	text(c, preset.description, UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 32), 13, BODY_FONT)
	if kind == "shooter" then
		statBar(c, "Accuracy", preset.accuracy, 56)
		statBar(c, "Strength", preset.strength, 76)
	else
		statBar(c, "Reach", preset.reach, 56)
		statBar(c, "Reaction", preset.reaction, 76)
	end

	c.Activated:Connect(function()
		picked[kind] = index
		PickScreen.refresh()
	end)
	cards[kind][index] = c :: any
end

local function row(parent: Instance, kind: "shooter" | "keeper", title: string, list: { any }, y: number)
	text(parent, title, UDim2.fromOffset(200, 20), UDim2.fromOffset(20, y), 16)
	local holder = Instance.new("Frame")
	holder.Name = if kind == "shooter" then "Shooters" else "Keepers"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(20, y + 24)
	holder.Size = UDim2.new(1, -40, 0, 102)
	holder.Parent = parent
	for i, preset in list do
		card(holder, kind, i, preset, (i - 1) / 2)
	end
end

function PickScreen.init(startHandler: (choice: { shooter: number, keeper: number }) -> ())
	onStart = startHandler

	gui = Instance.new("ScreenGui")
	gui.Name = "PickScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.DisplayOrder = 10

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(560, 380)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.08
	corner(panel, 12)
	panel.Parent = gui
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(560, 380)
	sizeLimit.Parent = panel

	local title = text(panel, "Choose your players", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 12), 26)
	title.TextXAlignment = Enum.TextXAlignment.Center

	row(panel, "shooter", "Your shooter", config.shooters, 54)
	row(panel, "keeper", "Your keeper", config.keepers, 186)

	startButton = Instance.new("TextButton")
	startButton.Name = "Start"
	startButton.AnchorPoint = Vector2.new(0.5, 1)
	startButton.Position = UDim2.new(0.5, 0, 1, -14)
	startButton.Size = UDim2.fromOffset(200, 40)
	startButton.BackgroundColor3 = ACCENT
	startButton.Font = FONT
	startButton.Text = "START MATCH"
	startButton.TextSize = 18
	startButton.TextColor3 = PANEL_COLOR
	corner(startButton, 8)
	startButton.Parent = panel
	startButton.Activated:Connect(function()
		local shooter, keeper = picked.shooter, picked.keeper
		if shooter and keeper then
			-- Stays open until the server confirms the match has started.
			onStart({ shooter = shooter, keeper = keeper })
		end
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	PickScreen.refresh()
end

-- Opens the screen; the last picks stay selected.
function PickScreen.show()
	PickScreen.refresh()
	gui.Enabled = true
end

function PickScreen.hide()
	gui.Enabled = false
end

return PickScreen
