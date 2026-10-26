-- StarterPlayerScripts/UIClient/WorldPrompts.lua
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Juice = require(script.Parent:WaitForChild("Juice"))

local TAG = "FloatSpot"
local INK = Color3.fromRGB(25, 10, 45)
local COOLDOWN = 0.4
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WorldPrompts = {}
local spots = {}
local enabled = true
local started = false
local onAction = function() end
local nearest = nil
local lastUse = 0

-- ห้ามรอ (yield) ใน callback ของ ContextActionService → แยกเธรดเสมอ
local function use(s, part)
	if not enabled or os.clock() - lastUse < COOLDOWN then return end
	lastUse = os.clock()
	Juice.squish(s.btn)
	task.spawn(onAction, s.action, part)
end

local function build(part)
	if spots[part] or not part:IsA("BasePart") then return end
	local action = part:GetAttribute("Action")
	if typeof(action) ~= "string" then return end
	local color = part:GetAttribute("Color")
	if typeof(color) ~= "Color3" then color = Color3.fromRGB(255, 220, 60) end
	local range = tonumber(part:GetAttribute("Range")) or 14

	-- อยู่ใน PlayerGui + ตั้ง Adornee ถึงจะกดได้
	local bb = Instance.new("BillboardGui")
	bb.Name = "Spot_" .. action
	bb.Adornee = part
	bb.Size = UDim2.fromOffset(180, 66)
	bb.StudsOffset = Vector3.new(0, tonumber(part:GetAttribute("Height")) or 3, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = range + 8
	bb.ResetOnSpawn = false
	bb.Active = true
	bb.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	bb.Enabled = false
	bb.Parent = playerGui

	local btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.fromScale(0.5, 0.5)
	btn.Size = UDim2.fromScale(0.94, 0.78)
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = color
	btn.Font = Juice.Font
	btn.TextScaled = true
	btn.TextColor3 = INK
	btn.Text = tostring(part:GetAttribute("Label") or action)
	btn.Parent = bb
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Thickness = 3; st.Color = INK; st.Parent = btn
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = btn

	-- ป้ายปุ่ม E: ขึ้นเฉพาะจุดที่ใกล้ที่สุด และเฉพาะเครื่องที่มีคีย์บอร์ด
	local key = Instance.new("TextLabel")
	key.AnchorPoint = Vector2.new(0.5, 0.5)
	key.Position = UDim2.new(1, 4, 0, -2)
	key.Size = UDim2.fromOffset(28, 28)
	key.BackgroundColor3 = Color3.new(1, 1, 1)
	key.Font = Juice.Font
	key.TextScaled = true
	key.TextColor3 = INK
	key.Text = "E"
	key.Visible = false
	key.ZIndex = 2
	key.Parent = btn
	Instance.new("UICorner", key).CornerRadius = UDim.new(1, 0)
	local ks = Instance.new("UIStroke")
	ks.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ks.Thickness = 2; ks.Color = INK; ks.Parent = key

	Juice.bind(btn)
	Juice.wobble(btn, { Amp = 3, Rot = 4, Speed = 2.5 })

	local s = { gui = bb, btn = btn, key = key, near = false, action = action, range = range }
	btn.Activated:Connect(function() use(s, part) end)
	spots[part] = s
end

local function remove(part)
	local s = spots[part]
	if not s then return end
	spots[part] = nil
	if nearest == part then nearest = nil end
	s.gui:Destroy()
end

local function setNearest(best)
	if best == nearest then return end
	local old = nearest and spots[nearest]
	if old then old.key.Visible = false end
	nearest = best
	local s = best and spots[best]
	if s then s.key.Visible = UserInputService.KeyboardEnabled end
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.15 then return end
	acc = 0
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	local best, bestD = nil, nil
	for part, s in spots do
		local d = (root and part.Parent) and (part.Position - root.Position).Magnitude or math.huge
		local near = enabled and d <= s.range
		if near ~= s.near then
			s.near = near
			if near then
				s.gui.Enabled = true
				Juice.popIn(s.btn)
			else
				Juice.popOut(s.btn, function() if not s.near then s.gui.Enabled = false end end)
			end
		end
		if near and (not bestD or d < bestD) then best, bestD = part, d end
	end
	setNearest(best)
end)

ContextActionService:BindAction("FloatSpotUse", function(_, state)
	if state ~= Enum.UserInputState.Begin or not enabled or not nearest then
		return Enum.ContextActionResult.Pass
	end
	local s = spots[nearest]
	if not s then return Enum.ContextActionResult.Pass end
	use(s, nearest)
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)

function WorldPrompts.Start(handler)
	onAction = handler or onAction
	if started then return end
	started = true
	for _, p in CollectionService:GetTagged(TAG) do build(p) end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(build)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
end

function WorldPrompts.SetEnabled(on)
	enabled = on
	if not on then
		for _, s in spots do s.near = false; s.gui.Enabled = false end
		setNearest(nil)
	end
end

return WorldPrompts