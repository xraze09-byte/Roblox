-- StarterPlayerScripts/UIClient/WorldPrompts.lua
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Juice = require(script.Parent:WaitForChild("Juice"))

local TAG = "FloatSpot"
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WorldPrompts = {}
local spots = {}
local enabled = true
local onAction = function() end
local nearest = nil

local function build(part)
	if spots[part] or not part:IsA("BasePart") then return end
	local action = part:GetAttribute("Action")
	if not action then return end
	local color = part:GetAttribute("Color") or Color3.fromRGB(255, 220, 60)

	-- ต้องอยู่ใน PlayerGui + ตั้ง Adornee ถึงจะกดได้ (ถ้าอยู่ใน workspace จะกดไม่ติด)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Spot_" .. action
	bb.Adornee = part
	bb.Size = UDim2.fromOffset(170, 64)
	bb.StudsOffset = Vector3.new(0, part:GetAttribute("Height") or 3, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Active = true
	bb.Enabled = false
	bb.Parent = playerGui

	local btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.fromScale(0.5, 0.5)
	btn.Size = UDim2.fromScale(1, 0.8)
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = color
	btn.Font = Juice.Font
	btn.TextScaled = true
	btn.TextColor3 = Color3.fromRGB(25, 10, 45)
	btn.Text = part:GetAttribute("Label") or action
	btn.Parent = bb
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Thickness = 3; st.Color = Color3.fromRGB(25, 10, 45); st.Parent = btn

	local key = Instance.new("TextLabel")
	key.AnchorPoint = Vector2.new(0.5, 0.5)
	key.Position = UDim2.new(1, -6, 0, 6)
	key.Size = UDim2.fromOffset(26, 26)
	key.BackgroundColor3 = Color3.new(1, 1, 1)
	key.Font = Juice.Font
	key.TextScaled = true
	key.Text = "E"
	key.Visible = not game:GetService("UserInputService").TouchEnabled
	key.Parent = btn
	Instance.new("UICorner", key).CornerRadius = UDim.new(1, 0)

	Juice.bind(btn)
	Juice.wobble(btn, { Amp = 3, Rot = 4, Speed = 2.5 })
	btn.Activated:Connect(function() if enabled then onAction(action, part) end end)

	spots[part] = { gui = bb, btn = btn, near = false, action = action }
end

local function remove(part)
	local s = spots[part]
	if s then s.gui:Destroy(); spots[part] = nil end
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
		local range = part:GetAttribute("Range") or 14
		local d = root and (part.Position - root.Position).Magnitude or math.huge
		local near = enabled and d <= range
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
	nearest = best
end)

ContextActionService:BindAction("FloatSpotUse", function(_, state)
	if state ~= Enum.UserInputState.Begin or not enabled or not nearest then
		return Enum.ContextActionResult.Pass
	end
	local s = spots[nearest]
	if not s then return Enum.ContextActionResult.Pass end
	Juice.squish(s.btn)
	onAction(s.action, nearest)
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)

function WorldPrompts.Start(handler)
	onAction = handler
	for _, p in CollectionService:GetTagged(TAG) do build(p) end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(build)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
end

function WorldPrompts.SetEnabled(on)
	enabled = on
	if not on then
		for _, s in spots do s.near = false; s.gui.Enabled = false end
		nearest = nil
	end
end

return WorldPrompts