-- StarterPlayerScripts/UIClient/CombatFX (ModuleScript)
-- ตัวเลขลอย / สั่น / กะพริบ
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UI = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Settings = require(UI:WaitForChild("Settings"))

local FX = {}
local STYLE = {
	Damage = { Color = Theme.Color.Red, Suffix = "", Y = 0 },
	Heal   = { Color = Theme.Color.Green, Suffix = " ❤️", Y = 0 },
	Atk    = { Color = Color3.fromRGB(255, 140, 40), Suffix = " ⚔️", Y = 0.3 },
	Shield = { Color = Theme.Color.Blue, Suffix = " 🛡️", Y = 0.3 },
	Points = { Color = Theme.Color.Yellow, Suffix = " 💰", Y = 0 },
}
local shaking = {}

-- วางตัวเลขใน ScreenGui เดียวกับเป้า เพื่อให้ตำแหน่งตรงเสมอ
local function centerIn(obj)
	local sg = obj:FindFirstAncestorWhichIsA("ScreenGui")
	if not sg then return nil end
	return sg, obj.AbsolutePosition + obj.AbsoluteSize / 2 - sg.AbsolutePosition
end

function FX.Number(target, amount, kind)
	if not (target and amount and amount ~= 0 and Settings.Get("DamageNumbers")) then return end
	local sg, p = centerIn(target)
	if not sg then return end
	local st = STYLE[kind] or (amount < 0 and STYLE.Damage or STYLE.Heal)
	local sp = Settings.Get("AnimSpeed") or 1
	local size = math.floor(math.clamp(sg.AbsoluteSize.Y / 14, 26, 64) * (1 + math.min(math.abs(amount), 10) * 0.04))
	p += Vector2.new(math.random(-12, 12), target.AbsoluteSize.Y * st.Y)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(p.X, p.Y)
	label.Size = UDim2.fromOffset(size * 5, size)
	label.Font = Theme.Font
	label.TextSize = size
	label.TextColor3 = st.Color
	label.Text = (amount > 0 and "+" or "") .. amount .. st.Suffix
	label.ZIndex = 200
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Theme.Color.Outline
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	label.Parent = sg

	TweenService:Create(scale, TweenInfo.new(0.18 / sp, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local rise = TweenInfo.new(0.8 / sp, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35 / sp)
	TweenService:Create(label, rise, { Position = UDim2.fromOffset(p.X, p.Y - size * 1.8), TextTransparency = 1 }):Play()
	local t = TweenService:Create(stroke, rise, { Transparency = 1 })
	t:Play()
	t.Completed:Once(function() label:Destroy() end)
end

function FX.Flash(target, color)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color or Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	f.ZIndex = 20
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.1, 0)
	c.Parent = f
	f.Parent = target
	local t = TweenService:Create(f, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
	t:Play()
	t.Completed:Once(function() f:Destroy() end)
end

function FX.Shake(target, power)
	if shaking[target] then return end
	shaking[target] = true
	local origin, t0, conn = target.Position, os.clock(), nil
	power = power or 6
	conn = RunService.RenderStepped:Connect(function()
		local e = os.clock() - t0
		if e > 0.3 or not target.Parent then
			conn:Disconnect()
			target.Position = origin
			shaking[target] = nil
			return
		end
		local k = power * (1 - e / 0.3)
		target.Position = origin + UDim2.fromOffset((math.random() * 2 - 1) * k, (math.random() * 2 - 1) * k)
	end)
end

-- ใช้กับตัวเลขที่เปลี่ยน: kind = "HP" | "Shield" | "Points"
function FX.Track(target, old, new, kind)
	if typeof(old) ~= "number" or typeof(new) ~= "number" or old == new or not target then return end
	local d = new - old
	if kind == "Points" then
		if d > 0 then FX.Number(target, d, "Points") end -- ตอนจ่ายพอยต์ไม่ต้องโชว์
		return
	end
	FX.Number(target, d, kind == "Shield" and "Shield" or nil)
	if d < 0 then
		FX.Shake(target, math.clamp(-d * 2, 4, 14))
		FX.Flash(target, kind == "Shield" and Theme.Color.Blue or Theme.Color.Red)
	end
end

return FX