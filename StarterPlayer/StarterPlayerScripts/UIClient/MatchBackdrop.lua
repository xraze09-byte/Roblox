-- StarterPlayerScripts/UIClient/MatchBackdrop (ModuleScript)
-- พื้นโต๊ะ + แผ่นรองสนาม + เส้นแบ่งกลาง + แสงบอกตา + ประกายลอย
local TweenService = game:GetService("TweenService")
local UIShared = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UI")
local Theme = require(UIShared:WaitForChild("Theme"))
local Settings = require(UIShared:WaitForChild("Settings"))

local Backdrop = {}
Backdrop.__index = Backdrop

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function fade(a, b)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

function Backdrop.new(parent)
	local self = setmetatable({}, Backdrop)
	local root = new("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 0 }, parent)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(52, 132, 88), Color3.fromRGB(20, 56, 44)) }, root)
	self.Root = root

	local mat = new("Frame", {
		Name = "Mat", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.115),
		Size = UDim2.fromScale(0.66, 0.525), BackgroundColor3 = Color3.fromRGB(255, 245, 215), BackgroundTransparency = 0.85,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(0.06, 0) }, mat)
	new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(255, 240, 200), Transparency = 0.5 }, mat)

	self.Line = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.375),
		Size = UDim2.new(0.64, 0, 0, 4), BackgroundColor3 = Theme.Color.Yellow, BorderSizePixel = 0,
	}, root)
	new("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
	}) }, self.Line)

	self.MyGlow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(1, 0.4),
		BackgroundColor3 = Theme.Color.Yellow, BackgroundTransparency = 1, BorderSizePixel = 0,
	}, root)
	new("UIGradient", { Rotation = 90, Transparency = fade(1, 0.55) }, self.MyGlow)
	self.OppGlow = new("Frame", {
		Size = UDim2.fromScale(1, 0.3), BackgroundColor3 = Theme.Color.Red, BackgroundTransparency = 1, BorderSizePixel = 0,
	}, root)
	new("UIGradient", { Rotation = 90, Transparency = fade(0.6, 1) }, self.OppGlow)

	for _ = 1, 14 do task.spawn(self._sparkle, self) end
	return self
end

function Backdrop:_sparkle()
	local dot = new("Frame", { Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.fromRGB(255, 250, 200), BackgroundTransparency = 1, BorderSizePixel = 0 }, self.Root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
	task.wait(math.random() * 8)
	while dot.Parent do
		if not Settings.Get("Effects") then dot.BackgroundTransparency = 1 task.wait(1) continue end
		local x = math.random()
		dot.Position = UDim2.fromScale(x, 1.02)
		dot.BackgroundTransparency = 0.3 + math.random() * 0.4
		local tw = TweenService:Create(dot, TweenInfo.new(7 + math.random() * 6, Enum.EasingStyle.Linear), {
			Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.1, -0.02), BackgroundTransparency = 1,
		})
		tw:Play()
		tw.Completed:Wait()
	end
end

-- ตาเรา = ขอบล่างเรืองทอง / ตาศัตรู = ขอบบนเรืองแดง
function Backdrop:SetTurn(isMine)
	if self.Turn == isMine then return end
	self.Turn = isMine
	local ti = TweenInfo.new(0.5)
	TweenService:Create(self.MyGlow, ti, { BackgroundTransparency = isMine and 0 or 1 }):Play()
	TweenService:Create(self.OppGlow, ti, { BackgroundTransparency = isMine and 1 or 0 }):Play()
	TweenService:Create(self.Line, ti, { BackgroundColor3 = isMine and Theme.Color.Yellow or Theme.Color.Red }):Play()
end

return Backdrop