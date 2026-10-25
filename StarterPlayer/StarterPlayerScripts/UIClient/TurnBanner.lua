-- StarterPlayerScripts/UIClient/TurnBanner (ModuleScript)
local TweenService = game:GetService("TweenService")
local UI = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local UIKit = require(UI:WaitForChild("UIKit"))
local Settings = require(UI:WaitForChild("Settings"))

local Banner = {}
local strip, title, sub
local token = 0

local function kp(t, v) return NumberSequenceKeypoint.new(t, v) end

function Banner.Init(parent)
	strip = UIKit.new("Frame", {
		Name = "TurnBanner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.375),
		Size = UDim2.fromScale(1, 0), BorderSizePixel = 0, ZIndex = 50, Visible = false,
		ClipsDescendants = true, Parent = parent,
	}, {
		UIKit.new("UIGradient", { Transparency = NumberSequence.new({ kp(0, 1), kp(0.2, 0.15), kp(0.8, 0.15), kp(1, 1) }) }),
	})
	title = UIKit.new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.55),
		Font = Theme.Font, TextScaled = true, ZIndex = 51, Parent = strip,
	}, { UIKit.new("UIStroke", { Thickness = 3, Color = Theme.Color.Outline }) })
	sub = UIKit.new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.22),
		Font = Theme.FontBody, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = 51, Parent = strip,
	})
end

-- isMine = ตาเราหรือไม่ | isStart = เพิ่งเริ่มแมตช์
function Banner.Show(isMine, isStart)
	if not strip then return end
	token += 1
	local my = token
	local sp = Settings.Get("AnimSpeed") or 1

	strip.BackgroundColor3 = isMine and Color3.fromRGB(70, 50, 0) or Color3.fromRGB(70, 10, 20)
	title.TextColor3 = isMine and Theme.Color.Yellow or Theme.Color.Red
	if isStart then
		title.Text = "⚔️ เริ่มแมตช์!"
		sub.Text = isMine and "คุณได้เริ่มก่อน 🔥" or "ศัตรูได้เริ่มก่อน 😈"
	else
		title.Text = isMine and "ตาของคุณ!" or "ตาของศัตรู"
		sub.Text = isMine and "ลงการ์ด • เลือกการ์ดโจมตี • กดจบเทิร์น"
			or "ระหว่างรอ คลิกขวาหรือกดค้างที่การ์ดเพื่อดูข้อมูลได้"
	end

	strip.Visible = true
	strip.Size = UDim2.fromScale(1, 0)
	title.Position = UDim2.fromScale(-0.3, 0.4)
	sub.Position = UDim2.fromScale(1.3, 0.82)
	local slide = TweenInfo.new(0.35 / sp, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(strip, TweenInfo.new(0.25 / sp, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 0.18) }):Play()
	TweenService:Create(title, slide, { Position = UDim2.fromScale(0.5, 0.4) }):Play()
	TweenService:Create(sub, slide, { Position = UDim2.fromScale(0.5, 0.82) }):Play()
	UIKit.sfx(isMine and "Turn" or "Click") -- ใส่ Sound ชื่อ "Turn" ใน SoundService.SFX ได้ (ถ้าไม่มีจะเงียบ)

	task.delay(1.4 / sp, function()
		if token ~= my then return end
		local out = TweenInfo.new(0.25 / sp, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(title, out, { Position = UDim2.fromScale(1.3, 0.4) }):Play()
		TweenService:Create(sub, out, { Position = UDim2.fromScale(-0.3, 0.82) }):Play()
		local t = TweenService:Create(strip, out, { Size = UDim2.fromScale(1, 0) })
		t:Play()
		t.Completed:Wait()
		if token == my then strip.Visible = false end
	end)
end

return Banner